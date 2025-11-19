local Concord = require "concord"
local Config = require "src.config"

local InputSystem = Concord.system({
    pool = {"input", "physics", "transform"}
})

function InputSystem:update(dt)
    local world = self:getWorld()
    if world.controls then world.controls:update(dt) end

    for _, e in ipairs(self.pool) do
        local phys = e.physics
        local trans = e.transform
        
        if phys.body then
            local body = phys.body
            local angle = body:getAngle()
            
            local rotation_input = 0
            if world.controls then
                local right = world.controls:get("right") or 0
                local left = world.controls:get("left") or 0
                rotation_input = right - left
            end
            
            if rotation_input ~= 0 then
                angle = angle + rotation_input * Config.ROTATION_SPEED * dt
                body:setAngle(angle)
            end

            if world.controls and world.controls:down("thrust") then
                local fx = math.cos(angle) * Config.THRUST
                local fy = math.sin(angle) * Config.THRUST
                body:applyForce(fx, fy)
            end

            local vx, vy = body:getLinearVelocity()
            local speed = math.sqrt(vx * vx + vy * vy)
            if speed > Config.MAX_SPEED then
                local scale = Config.MAX_SPEED / speed
                body:setLinearVelocity(vx * scale, vy * scale)
            end

            trans.r = body:getAngle()
        end
    end
end

return InputSystem