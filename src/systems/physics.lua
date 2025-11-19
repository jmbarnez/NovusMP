local Concord = require "concord"
local Config = require "src.config"

local PhysicsSystem = Concord.system({
    pool = {"physics", "transform"}
})

function PhysicsSystem:update(dt)
    local world = self:getWorld()
    if not world.physics_world then return end
    
    world.physics_world:update(dt)

    for _, e in ipairs(self.pool) do
        local p = e.physics
        local t = e.transform
        local body = p.body

        if body then
            local x, y = body:getPosition()
            local r = body:getAngle()

            local radius = p.shape and p.shape:getRadius() or 0
            local min_x = radius
            local min_y = radius
            local max_x = Config.WORLD_WIDTH - radius
            local max_y = Config.WORLD_HEIGHT - radius

            local clamped_x = math.max(min_x, math.min(max_x, x))
            local clamped_y = math.max(min_y, math.min(max_y, y))

            if clamped_x ~= x or clamped_y ~= y then
                body:setPosition(clamped_x, clamped_y)
                body:setLinearVelocity(0, 0)
            end
            x, y = body:getPosition()

            t.x, t.y = x, y
            t.r = r
        end
    end
end

return PhysicsSystem