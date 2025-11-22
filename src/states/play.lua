local Gamestate  = require "hump.gamestate"
local baton      = require "baton"
local Camera     = require "hump.camera"
local Concord    = require "concord"
local Config     = require "src.config"
local Background = require "src.background"
local Chat       = require "src.ui.chat"
local HUD        = require "src.ui.hud"

require "src.components"

local InputSystem   = require "src.systems.input"
local PhysicsSystem = require "src.systems.physics"
local Network       = require "src.systems.network"
local RenderSystem  = require "src.systems.render"
local ShipSystem    = require "src.systems.ship"

local PlayState     = {}

function PlayState:enter(prev, role)
    self.role = role or "SINGLE"
    self.world = Concord.world()
    self.world.background = Background.new()

    Chat.enable()
    Chat.system("Entered game as " .. self.role)

    -- Camera setup
    self.world.camera = Camera.new()
    self.world.camera:zoomTo(Config.CAMERA_DEFAULT_ZOOM)

    -- Physics World (Only used by Host, but initialized always for safety)
    self.world.physics_world = love.physics.newWorld(0, 0, true)

    -- Controls (Local Hardware)
    self.world.controls = baton.new({
        controls = {
            left = { "key:left", "key:a" },
            right = { "key:right", "key:d" },
            thrust = { "key:up", "key:w" }
        }
    })

    -- Add Systems
    self.world:addSystems(
        InputSystem,
        PhysicsSystem,
        Network.Sync,
        Network.IO,
        RenderSystem
    )

    -- Configure Roles for Systems
    self.world:getSystem(Network.IO):setRole(self.role)
    self.world:getSystem(PhysicsSystem):setRole(self.role)
    self.world:getSystem(InputSystem):setRole(self.role)

    if Chat.isEnabled() then
        Chat.setSendHandler(function(message)
            local net = self.world:getSystem(Network.IO)
            if net and net.sendChat then
                net:sendChat(message)
            else
                Chat.addMessage("You: " .. message, "text")
            end
        end)
    end

    -- === SPAWNING LOGIC ===

    -- Create Local Player (Persistent Data)
    self.player = Concord.entity(self.world)
    self.player:give("wallet", 1000) -- Starting credits
    self.player:give("skills")
    self.player:give("input")
    self.player:give("pilot") -- Mark as local player (InputSystem reads baton for this)

    if self.role == "HOST" or self.role == "SINGLE" then
        -- Host spawns their own ship immediately
        Config.MY_NETWORK_ID = "HOST_PLAYER"
        local ship = ShipSystem.spawn(self.world, "drone", Config.MY_NETWORK_ID, 0, 0, true)
        
        -- Link Player -> Ship
        self.player:give("controlling", ship)
        -- Link Input (so Baton -> Player -> Ship works AND Network -> Ship -> Packet works)
        self.player.input = ship.input

        -- Listen for client joins to spawn their ships
        self.world:on("spawn_player", function(id, peer)
            local s = ShipSystem.spawn(self.world, "drone", id, 100, 0, false)
            
            -- Create Remote Player Entity (Logic Controller)
            local p = Concord.entity(self.world)
            p:give("controlling", s)
            p:give("input")
            
            -- Link inputs so Network Update (on Ship) -> Physics (via Player) works
            p.input = s.input
        end)
    elseif self.role == "CLIENT" then
        -- Clients spawn NOTHING initially.
        -- They wait for "WELCOME" to set ID, and "SNAP" to create the entity.
    end

    self.world:on("collision", function(entityA, entityB, contact)
        print("Bonk!", entityA, entityB)
    end)

    self.world:on("client_ship_spawned", function(ship, is_me)
        if is_me then
            Chat.system("Your ship has been delivered.")
            self.player:give("controlling", ship)
            self.player.input = ship.input
        end
    end)
end

function PlayState:update(dt)
    if self.world.background then self.world.background:update(dt) end

    if self.role == "CLIENT" then
        local net = self.world:getSystem(Network.IO)
        if net and net:getConnectionState() == "failed" then
            Gamestate.switch(require "src.states.menu")
            return
        end
    end

    self.world:emit("update", dt)
end

function PlayState:draw()
    love.graphics.setBackgroundColor(0, 0, 0)
    self.world:emit("draw")

    -- HUD
    love.graphics.origin()
    HUD.draw(self.world)
end

-- Promote an existing single-player session into a hosted session so others can join.
function PlayState:enableHosting()
    if self.role == "HOST" then return true end
    if not Config.NETWORK_AVAILABLE then
        print("Hosting unavailable: ENet library not present.")
        return false
    end

    self.role = "HOST"

    -- Update all role-aware systems so they behave as a host from now on.
    local networkSystem = self.world:getSystem(Network.IO)
    if networkSystem then networkSystem:setRole("HOST") end

    local physicsSystem = self.world:getSystem(PhysicsSystem)
    if physicsSystem then physicsSystem:setRole("HOST") end

    local inputSystem = self.world:getSystem(InputSystem)
    if inputSystem then inputSystem:setRole("HOST") end

    Chat.system("Mode changed to HOST. Other players can now connect.")
    print("Hosting enabled: other players can now connect.")
    return true
end

function PlayState:keypressed(key)
    if key == "h" and self.role == "SINGLE" then
        self:enableHosting()
    end
end

function PlayState:leave()
    Chat.disable()
end

return PlayState
