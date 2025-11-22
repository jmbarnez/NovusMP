local Concord = require "concord"
local Config = require "src.config"

local PhysicsSystem = Concord.system({
    pool = {"physics", "transform", "sector"}
})

function PhysicsSystem:init()
    self.role = "SINGLE"
end

function PhysicsSystem:setRole(role)
    self.role = role
end

function PhysicsSystem:update(dt)
    -- CRITICAL: Physics runs on HOST, SINGLE, or for the LOCAL PILOT on CLIENT
    -- If we are CLIENT, we still want to step the world so our predicted ship moves.
    -- Remote entities (ghosts) should NOT have physics bodies, so they won't be affected.
    if self.role == "CLIENT" and not self:getWorld().physics_world then return end

    local world = self:getWorld()
    if not world.physics_world then return end
    
    -- 1. Step Simulation
    world.physics_world:update(dt)

    -- 2. Handle Wrapping
    local half_size = Config.SECTOR_SIZE / 2

    for _, e in ipairs(self.pool) do
        local p = e.physics
        local t = e.transform
        local s = e.sector
        local body = p.body

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
    end
end

return PhysicsSystem