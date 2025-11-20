local Concord = require "concord"
-- We no longer strictly need Config here if stats are on the vehicle component
-- local Config = require "src.config" 

local InputSystem = Concord.system({
    -- We look for entities that have Input and are Controlling something
    pool = {"input", "controlling"}
})

function InputSystem:update(dt)
    local world = self:getWorld()

    -- 1. Update the global input controller (Baton)
    if world.controls then 
        world.controls:update(dt) 
    end

    -- 2. Process all Pilots
    for _, pilot in ipairs(self.pool) do
        -- Get the ship entity from the link
        local ship = pilot.controlling.entity

        -- Validate the ship exists and is driveable
        if ship and ship.physics and ship.vehicle and ship.transform then
            local phys = ship.physics
            local trans = ship.transform
            local stats = ship.vehicle
            
            if phys.body then
                local body = phys.body
                local current_angle = body:getAngle()
                
                -- A. Handle Rotation
                local rotation_input = 0
                if world.controls then
                    local right = world.controls:get("right") or 0
                    local left = world.controls:get("left") or 0
                    rotation_input = right - left
                end
                
                if rotation_input ~= 0 then
                    current_angle = current_angle + rotation_input * stats.turn_speed * dt
                    body:setAngle(current_angle)
                end

                -- B. Handle Thrust
                if world.controls and world.controls:down("thrust") then
                    local fx = math.cos(current_angle) * stats.thrust
                    local fy = math.sin(current_angle) * stats.thrust
                    body:applyForce(fx, fy)
                end

                -- C. Cap Maximum Speed (using vehicle stats)
                local vx, vy = body:getLinearVelocity()
                local speed = math.sqrt(vx * vx + vy * vy)

                if speed > stats.max_speed then
                    local scale = stats.max_speed / speed
                    body:setLinearVelocity(vx * scale, vy * scale)
                end

                -- D. Sync Physics rotation back to Transform
                trans.r = body:getAngle()
            end
        end
    end
end

return InputSystem