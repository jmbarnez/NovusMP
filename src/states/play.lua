local Gamestate = require "hump.gamestate"
local baton     = require "baton"
local Camera    = require "hump.camera"
local Concord   = require "concord"
local Config    = require "src.config"
local Background = require "src.background"

require "src.components"

local InputSystem   = require "src.systems.input"
local PhysicsSystem = require "src.systems.physics"
local Network       = require "src.systems.network"
local RenderSystem  = require "src.systems.render"

local PlayState = {}

-- Helper to create a ship entity (Server side only)
local function spawnShip(world, id, x, y, is_host_player)
    local body = love.physics.newBody(world.physics_world, x, y, "dynamic")
    body:setLinearDamping(Config.LINEAR_DAMPING)
    
    local shape = love.physics.newCircleShape(10)
    local fixture = love.physics.newFixture(body, shape, 1)
    fixture:setRestitution(0.2)

    local ship = Concord.entity(world)
    ship:give("transform", x, y, 0)
    ship:give("sector", 0, 0) 
    ship:give("physics", body, shape, fixture)
    ship:give("vehicle", Config.THRUST, Config.ROTATION_SPEED, Config.MAX_SPEED)
    ship:give("network_identity", id)
    ship:give("render", is_host_player and {0.2, 1, 0.2} or {1, 0.2, 0.2})
    
    -- Give it an Input component so the server can apply controls to it
    ship:give("input") 
    
    -- Link controller
    local pilot = Concord.entity(world)
    pilot:give("controlling", ship)
    pilot:give("input") -- Pilot holds the input state
    ship.pilot = pilot -- Backlink for convenience if needed
    
    -- Map for network system
    world:getSystem(Network.IO).entity_map[id] = ship
    
    return ship, pilot
end

function PlayState:enter(prev, role)
    self.role = role or "SINGLE"
    self.world = Concord.world()
    self.world.background = Background.new()
    
    -- Camera setup
    self.world.camera = Camera.new()
    self.world.camera:zoomTo(Config.CAMERA_DEFAULT_ZOOM)

    -- Physics World (Only used by Host, but initialized always for safety)
    self.world.physics_world = love.physics.newWorld(0, 0, true)

    -- Controls (Local Hardware)
    self.world.controls = baton.new({
        controls = {
            left = {"key:left", "key:a"},
            right = {"key:right", "key:d"},
            thrust = {"key:up", "key:w"}
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

    -- === SPAWNING LOGIC ===
    
    if self.role == "HOST" or self.role == "SINGLE" then
        -- Host spawns their own ship immediately
        Config.MY_NETWORK_ID = "HOST_PLAYER"
        local ship, pilot = spawnShip(self.world, Config.MY_NETWORK_ID, 0, 0, true)
        pilot:give("pilot") -- Mark as local player (InputSystem reads baton for this)
        
        -- Listen for client joins to spawn their ships
        self.world:on("spawn_player", function(id, peer)
            local s, p = spawnShip(self.world, id, 100, 0, false)
            -- We don't give 'pilot' tag because we don't control it locally with baton
            -- But we do have 'input' component which NetworkIO will update via packets
            -- Link the Pilot entity to the Ship input so physics applies
            p.input = s.input 
        end)
        
    elseif self.role == "CLIENT" then
        -- Clients spawn NOTHING initially. 
        -- They wait for "WELCOME" to set ID, and "SNAP" to create the entity.
    end
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
    love.graphics.setBackgroundColor(0,0,0)
    self.world:emit("draw")
    
    -- HUD
    love.graphics.origin()
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Mode: " .. self.role, 10, 70)
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

    print("Hosting enabled: other players can now connect.")
    return true
end

function PlayState:keypressed(key)
    if key == "h" and self.role == "SINGLE" then
        self:enableHosting()
    end
end

return PlayState