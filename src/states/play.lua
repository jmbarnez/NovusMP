local Gamestate        = require "hump.gamestate"
local baton            = require "baton"
local Camera           = require "hump.camera"
local Concord          = require "concord"
local Config           = require "src.config"
local Background       = require "src.rendering.background"
local HUD              = require "src.ui.hud.hud"
local SaveManager      = require "src.managers.save_manager"

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

local PlayState        = {}

local function setSystemRoles(world)
    local role_str = "SINGLE"

    local sys_phys = world:getSystem(PhysicsSystem)
    if sys_phys and sys_phys.setRole then
        sys_phys:setRole(role_str)
    end

    local sys_input = world:getSystem(InputSystem)
    if sys_input and sys_input.setRole then
        sys_input:setRole(role_str)
    end

    local sys_weapon = world:getSystem(WeaponSystem)
    if sys_weapon and sys_weapon.setRole then
        sys_weapon:setRole(role_str)
    end

    local sys_proj = world:getSystem(ProjectileSystem)
    if sys_proj and sys_proj.setRole then
        sys_proj:setRole(role_str)
    end

    local sys_chunk = world:getSystem(AsteroidChunkSystem)
    if sys_chunk and sys_chunk.setRole then
        sys_chunk:setRole(role_str)
    end

    local sys_shard = world:getSystem(ProjectileShardSystem)
    if sys_shard and sys_shard.setRole then
        sys_shard:setRole(role_str)
    end
end


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

        local projectile
        local target

        if a and a.projectile and b and b.asteroid then
            projectile = a
            target = b
        elseif b and b.projectile and a and a.asteroid then
            projectile = b
            target = a
        else
            return
        end

        if not (projectile and projectile.projectile and target and target.hp) then
            return
        end

        local projComp = projectile.projectile
        local hp = target.hp

        if projComp.lifetime and projComp.lifetime <= 0 then
            return
        end

        local damage = projComp.damage or 0
        if damage <= 0 then
            projComp.lifetime = 0
            return
        end

        local current = hp.current or hp.max or 0
        current = current - damage
        if current < 0 then
            current = 0
        end
        hp.current = current

        if love and love.timer and love.timer.getTime then
            hp.last_hit_time = love.timer.getTime()
        end

        -- Queue projectile shards for spawning (deferred to avoid physics callback issues)
        if projectile.transform and projectile.render and projectile.sector then
            local pt = projectile.transform
            local pr = projectile.render
            local ps = projectile.sector
            
            -- Store spawn data in world table for deferred spawning
            if not self.world.pending_shards then
                self.world.pending_shards = {}
            end
            
            table.insert(self.world.pending_shards, {
                x = pt.x,
                y = pt.y,
                sector_x = ps.x,
                sector_y = ps.y,
                color = pr.color or {1, 1, 1, 1}
            })
        end

        projComp.lifetime = 0
    end)
end

function PlayState:enter(prev, param)
    self.role = "SINGLE"

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
        MinimapSystem
    )

    setSystemRoles(self.world)

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
    
    -- Spawn queued projectile shards after physics step
    if self.world.pending_shards and #self.world.pending_shards > 0 then
        for _, shard_data in ipairs(self.world.pending_shards) do
            local num_shards = 4 + math.random(0, 2)
            local shard_size = 2 + math.random() * 2
            
            for i = 1, num_shards do
                local angle = (math.pi * 2 / num_shards) * i + (math.random() - 0.5) * 1.0
                local spawn_x = shard_data.x + math.cos(angle) * 3
                local spawn_y = shard_data.y + math.sin(angle) * 3
                
                local shard = Concord.entity(self.world)
                shard:give("transform", spawn_x, spawn_y, math.random() * math.pi * 2)
                shard:give("sector", shard_data.sector_x, shard_data.sector_y)
                shard:give("render", {
                    render_type = "projectile_shard",
                    color = shard_data.color,
                    radius = shard_size
                })
                shard:give("projectile_shard")
                shard:give("lifetime", 0.3 + math.random() * 0.4)
                
                -- Create physics for shards
                local shard_body = love.physics.newBody(self.world.physics_world, spawn_x, spawn_y, "dynamic")
                shard_body:setLinearDamping(0.5)
                shard_body:setGravityScale(0)
                
                local shard_shape = love.physics.newCircleShape(shard_size * 0.3)
                local shard_fixture = love.physics.newFixture(shard_body, shard_shape, 0.1)
                shard_fixture:setSensor(true)
                shard_fixture:setUserData(shard)
                
                shard:give("physics", shard_body, shard_shape, shard_fixture)
                
                local speed = 80 + math.random() * 60
                shard_body:setLinearVelocity(
                    math.cos(angle) * speed,
                    math.sin(angle) * speed
                )
                shard_body:setAngularVelocity((math.random() - 0.5) * 8)
            end
        end
        
        -- Clear the queue
        self.world.pending_shards = {}
    end
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
