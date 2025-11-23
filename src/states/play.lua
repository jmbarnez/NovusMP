local Gamestate        = require "hump.gamestate"
local baton            = require "baton"
local Camera           = require "hump.camera"
local Concord          = require "concord"
local Config           = require "src.config"
local Background       = require "src.rendering.background"
local HUD              = require "src.ui.hud.hud"
local SaveManager      = require "src.managers.save_manager"
local CollisionHandlers = require "src.utils.collision_handlers"

require "src.ecs.components"

local InputSystem      = require "src.ecs.systems.core.input"
local MinimapSystem    = require "src.ecs.systems.visual.minimap"
local PhysicsSystem    = require "src.ecs.systems.core.physics"
local RenderSystem     = require "src.ecs.systems.core.render"
local ShipSystem       = require "src.ecs.spawners.ship"
local Asteroids        = require "src.ecs.spawners.asteroid"
local WeaponSystem     = require "src.ecs.systems.gameplay.weapon"
local ProjectileSystem = require "src.ecs.systems.gameplay.projectile"
local AsteroidChunkSystem = require "src.ecs.systems.visual.asteroid_chunk"
local ProjectileShardSystem = require "src.ecs.systems.visual.projectile_shard"
local ItemPickupSystem = require "src.ecs.systems.gameplay.item_pickup"

local PlayState        = {}




local function createLocalPlayer(world)
    local player = Concord.entity(world)
    player:give("wallet", 1000)
    player:give("skills")
    player:give("level")
    player:give("input")
    player:give("pilot")
    return player
end

local function linkPlayerToShip(player, ship)
    if not (player and ship and ship.input) then
        return
    end
    player:give("controlling", ship)
    player.input = ship.input
end

local function registerSpawnHandlers(self)
    self.world:on("collision", function(entityA, entityB, contact)
        local a = entityA
        local b = entityB

        local projectile, target

        -- Check for projectile hitting asteroid or asteroid_chunk
        if a and a.projectile and b and (b.asteroid or b.asteroid_chunk) then
            projectile = a
            target = b
        elseif b and b.projectile and a and (a.asteroid or a.asteroid_chunk) then
            projectile = b
            target = a
        else
            return
        end

        -- Use collision handler utility
        CollisionHandlers.handle_projectile_asteroid(projectile, target, self.world)
    end)
end

function PlayState:enter(prev, param)


    local loadParams
    if type(param) == "table" then
        loadParams = param
    end

    local snapshot
    if loadParams and loadParams.mode == "load" then
        local slot = loadParams.slot or 1
        local loaded, err = SaveManager.load(slot)
        if loaded then
            snapshot = loaded
        elseif err then
            print("PlayState: failed to load save slot " .. tostring(slot) .. ": " .. tostring(err))
        end
    end

    self.world = Concord.world()
    self.world.background = Background.new()


    -- Camera
    self.world.camera = Camera.new()
    self.world.camera:zoomTo(Config.CAMERA_DEFAULT_ZOOM)

    -- Physics (always present; role decides authority)
    self.world.physics_world = love.physics.newWorld(0, 0, true)

    -- Local controls
    self.world.controls = baton.new({
        controls = {
            move_left  = { "key:a", "key:left" },
            move_right = { "key:d", "key:right" },
            move_up    = { "key:w", "key:up" },
            move_down  = { "key:s", "key:down" },
            fire       = { "mouse:1", "key:space" }
        }
    })

    -- Systems
    self.world:addSystems(
        InputSystem,
        PhysicsSystem,
        WeaponSystem,
        ProjectileSystem,
        AsteroidChunkSystem,
        ProjectileShardSystem,
        RenderSystem,
        MinimapSystem,
        ItemPickupSystem
    )



    -- Player meta-entity (local user, not the ship itself)
    self.player = createLocalPlayer(self.world)

    local spawn_x = 0
    local spawn_y = 0
    local ship_type = "drone"
    local sector_x
    local sector_y

    if snapshot and snapshot.player and snapshot.player.ship then
        local s = snapshot.player.ship
        if s.transform then
            if s.transform.x then spawn_x = s.transform.x end
            if s.transform.y then spawn_y = s.transform.y end
        end
        if s.sector then
            sector_x = s.sector.x
            sector_y = s.sector.y
        end
        if s.ship_type then
            ship_type = s.ship_type
        end
    end

    local ship = ShipSystem.spawn(self.world, ship_type, spawn_x, spawn_y, true)

    if sector_x and ship.sector then
        ship.sector.x = sector_x
        ship.sector.y = sector_y
    end

    linkPlayerToShip(self.player, ship)

    if snapshot then
        SaveManager.apply_snapshot(self.world, self.player, ship, snapshot)
    end

    registerSpawnHandlers(self)

    -- Asteroid field around origin; seed comes from NewGame
    if Config.UNIVERSE_SEED then
        Asteroids.spawnField(self.world, 0, 0, Config.UNIVERSE_SEED, 40)
    end
end

function PlayState:update(dt)
    if self.world.background then
        self.world.background:update(dt)
    end

    self.world:emit("update", dt)
end

function PlayState:draw()
    love.graphics.setBackgroundColor(0.03, 0.05, 0.16)
    self.world:emit("draw")

    love.graphics.origin()
    HUD.draw(self.world, self.player)
end

function PlayState:keypressed(key)
    if key == "f5" then
        SaveManager.save(1, self.world, self.player)
    elseif key == "f9" then
        if SaveManager.has_save(1) then
            Gamestate.switch(PlayState, { mode = "load", slot = 1 })
        else
            -- No save file
        end
    end
end


return PlayState
