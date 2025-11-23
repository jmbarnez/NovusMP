local Concord = require "concord"
local Config = require "src.config"
local VFXSpawners = require "src.utils.vfx_spawners"
local EntityUtils = require "src.utils.entity_utils"
local ItemSpawners = require "src.ecs.spawners.item"

local PhysicsSystem = Concord.system({
    pool = {"physics", "transform", "sector"}
})

function PhysicsSystem:init()
    self.callbacks_registered = false
    self.accumulator = 0
    self.fixed_dt = 1 / 60
end

function PhysicsSystem:handleBeginContact(fixtureA, fixtureB, contact)


    local world = self:getWorld()
    if not world then return end

    local entityA = fixtureA and fixtureA:getUserData() or nil
    local entityB = fixtureB and fixtureB:getUserData() or nil

    if not entityA or not entityB then return end

    if (entityA.projectile and entityA.projectile.owner == entityB)
        or (entityB.projectile and entityB.projectile.owner == entityA) then
        return
    end

    world:emit("collision", entityA, entityB, contact)
end

function PhysicsSystem:handlePreSolve(fixtureA, fixtureB, contact)
    local entityA = fixtureA and fixtureA:getUserData() or nil
    local entityB = fixtureB and fixtureB:getUserData() or nil

    if not entityA or not entityB then return end

    if (entityA.projectile and entityA.projectile.owner == entityB)
        or (entityB.projectile and entityB.projectile.owner == entityA) then
        contact:setEnabled(false)
    end
end

function PhysicsSystem:update(dt)


    local world = self:getWorld()
    if not world.physics_world then return end

    if not self.callbacks_registered then
        world.physics_world:setCallbacks(
            function(fixtureA, fixtureB, contact)
                self:handleBeginContact(fixtureA, fixtureB, contact)
            end,
            nil,
            function(fixtureA, fixtureB, contact)
                self:handlePreSolve(fixtureA, fixtureB, contact)
            end
        )
        self.callbacks_registered = true
    end
    
    -- 1. Step Simulation (fixed timestep for determinism)
    self.accumulator = self.accumulator + dt
    while self.accumulator >= self.fixed_dt do
        world.physics_world:update(self.fixed_dt)
        self.accumulator = self.accumulator - self.fixed_dt
    end

    -- 2. Handle Wrapping
    local half_size = Config.SECTOR_SIZE / 2

    for _, e in ipairs(self.pool) do
        local p = e.physics
        local t = e.transform
        local s = e.sector
        local body = p.body

        local hp = e.hp
        if hp and hp.current and hp.current <= 0 then
            -- Spawn chunks before destroying asteroid
            if e.asteroid and e.render then
                VFXSpawners.spawn_asteroid_chunks(world, e)
                -- Spawn stone item
                ItemSpawners.spawn_stone(world, t.x, t.y, s.x, s.y)
            elseif e.asteroid_chunk then
                -- Chunks just drop items, no more chunks
                ItemSpawners.spawn_stone(world, t.x, t.y, s.x, s.y)
            end
            
            -- Now destroy the entity
            EntityUtils.cleanup_physics_entity(e)
            goto continue_entity
        end

        if body then

            local x, y = body:getPosition()

            local r = body:getAngle()
            local sector_changed = false

            if x > half_size then
                x = x - Config.SECTOR_SIZE
                s.x = s.x + 1
                sector_changed = true
            elseif x < -half_size then
                x = x + Config.SECTOR_SIZE
                s.x = s.x - 1
                sector_changed = true
            end

            if y > half_size then
                y = y - Config.SECTOR_SIZE
                s.y = s.y + 1
                sector_changed = true
            elseif y < -half_size then
                y = y + Config.SECTOR_SIZE
                s.y = s.y - 1
                sector_changed = true
            end

            if sector_changed then
                body:setPosition(x, y)
            end

            -- Sync visual transform to physics body
            t.x, t.y = x, y
            t.r = r
        end

        ::continue_entity::
    end
end

return PhysicsSystem
