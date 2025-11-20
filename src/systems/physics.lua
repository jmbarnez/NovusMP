local Concord = require "concord"
local Config = require "src.config"

local PhysicsSystem = Concord.system({
    -- We only manage entities that have physics AND a sector component
    -- (If an entity doesn't have a sector, it can't exist in the infinite world)
    pool = {"physics", "transform", "sector"}
})

function PhysicsSystem:update(dt)
    local world = self:getWorld()
    if not world.physics_world then return end
    
    -- 1. Step the Physics Simulation
    world.physics_world:update(dt)

    -- 2. Handle Sector Wrapping
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

            -- Check East Boundary
            if x > half_size then
                x = x - Config.SECTOR_SIZE
                s.x = s.x + 1
                sector_changed = true
            -- Check West Boundary
            elseif x < -half_size then
                x = x + Config.SECTOR_SIZE
                s.x = s.x - 1
                sector_changed = true
            end

            -- Check South Boundary
            if y > half_size then
                y = y - Config.SECTOR_SIZE
                s.y = s.y + 1
                sector_changed = true
            -- Check North Boundary
            elseif y < -half_size then
                y = y + Config.SECTOR_SIZE
                s.y = s.y - 1
                sector_changed = true
            end

            -- If we wrapped, update the Physics Body to the new local coordinate
            if sector_changed then
                body:setPosition(x, y)
            end

            -- Sync Visual Transform
            t.x, t.y = x, y
            t.r = r
        end
    end
end

return PhysicsSystem