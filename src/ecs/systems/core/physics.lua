local Concord = require "concord"
local Config = require "src.config"

local PhysicsSystem = Concord.system({
    pool = {"physics", "transform", "sector"}
})

function PhysicsSystem:init()
    self.role = "SINGLE"
    self.callbacks_registered = false
    self.accumulator = 0
    self.fixed_dt = 1 / 60
end

function PhysicsSystem:setRole(role)
    self.role = role
end

function PhysicsSystem:handleBeginContact(fixtureA, fixtureB, contact)
    if self.role == "CLIENT" then return end

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
    -- CRITICAL: Physics runs on HOST, SINGLE, or for the LOCAL PILOT on CLIENT
    -- If we are CLIENT, we still want to step the world so our predicted ship moves.
    -- Remote entities (ghosts) should NOT have physics bodies, so they won't be affected.
    if self.role == "CLIENT" and not self:getWorld().physics_world then return end

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
                local r = e.render
                local parent_radius = r.radius or 10
                local parent_color = r.color or {0.6, 0.6, 0.6, 1}
                
                -- Spawn 3-5 chunks with mass conservation
                local num_chunks = 3 + math.random(0, 2)
                
                -- Calculate max chunk radius to conserve mass
                -- In 2D: total area of chunks ≤ parent area
                -- Area = π*r², so for N equal chunks: N * π*rchunk² ≤ π*rparent²
                -- Therefore: rchunk ≤ rparent / sqrt(N)
                local max_chunk_radius = parent_radius / math.sqrt(num_chunks)
                
                for i = 1, num_chunks do
                    -- Random size with variance but respecting mass conservation
                    local chunk_radius = max_chunk_radius * (0.6 + math.random() * 0.4)
                    
                    -- Random angle for radial distribution
                    local angle = (math.pi * 2 / num_chunks) * i + (math.random() - 0.5) * 0.5
                    
                    -- Spawn position slightly offset from asteroid center
                    local spawn_x = t.x + math.cos(angle) * parent_radius * 0.5
                    local spawn_y = t.y + math.sin(angle) * parent_radius * 0.5
                    
                    -- Create chunk entity (no lifetime - chunks persist)
                    local chunk = Concord.entity(world)
                    chunk:give("transform", spawn_x, spawn_y, math.random() * math.pi * 2)
                    chunk:give("sector", s.x, s.y)
                    chunk:give("render", {
                        render_type = "asteroid_chunk",
                        color = parent_color,
                        radius = chunk_radius
                    })
                    chunk:give("asteroid_chunk")
                    
                    -- Create physics body for chunk
                    local chunk_body = love.physics.newBody(world.physics_world, spawn_x, spawn_y, "dynamic")
                    chunk_body:setLinearDamping(1.0)
                    chunk_body:setAngularDamping(1.0)
                    
                    local chunk_shape = love.physics.newCircleShape(chunk_radius * 0.8)
                    local chunk_fixture = love.physics.newFixture(chunk_body, chunk_shape, 0.5)
                    chunk_fixture:setRestitution(0.2)
                    chunk_fixture:setUserData(chunk)
                    
                    chunk:give("physics", chunk_body, chunk_shape, chunk_fixture)
                    
                    -- Apply outward velocity
                    local speed = 50 + math.random() * 100
                    chunk_body:setLinearVelocity(
                        math.cos(angle) * speed,
                        math.sin(angle) * speed
                    )
                    chunk_body:setAngularVelocity((math.random() - 0.5) * 4)
                end
            end
            
            -- Now destroy the asteroid
            if p.fixture then
                p.fixture:setUserData(nil)
            end
            if body then
                body:destroy()
            end
            e:destroy()
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
