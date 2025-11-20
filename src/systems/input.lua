local Concord = require "concord"

-- This system now has two distinct responsibilities:
-- 1. CLIENT/LOCAL: Read hardware inputs (Baton) and store them in the Input Component.
-- 2. HOST: Read the Input Component and apply forces to the Physics Body.

local InputSystem = Concord.system({
    -- Entities that have input and are controlling a vehicle
    controllers = {"input", "controlling"}
})

function InputSystem:init()
    self.role = "SINGLE" -- Default
end

function InputSystem:setRole(role)
    self.role = role
end

function InputSystem:update(dt)
    local world = self:getWorld()
    
    -- 1. GATHER INPUT (Local Player Only)
    -- If we have a controls object (baton), we update the components of our local player
    if world.controls then
        world.controls:update(dt)
        
        -- Find the entity that represents the local player
        -- In Host/Single mode, this is the player entity.
        -- In Client mode, this is the "Ghost" entity we send inputs for.
        for _, e in ipairs(self.controllers) do
            if e:has("pilot") then -- Assuming 'pilot' tag marks the local user's avatar
                local input = e.input
                
                -- Calculate Turn State (-1, 0, 1)
                local right = world.controls:get("right") or 0
                local left = world.controls:get("left") or 0
                input.turn = right - left
                
                -- Calculate Thrust State (boolean)
                input.thrust = world.controls:down("thrust")
            end
        end
    end

    -- 2. APPLY PHYSICS (Host / Single Player Only)
    -- Clients do NOT run this part. They only send inputs.
    if self.role == "HOST" or self.role == "SINGLE" then
        for _, e in ipairs(self.controllers) do
            local input = e.input
            local ship = e.controlling.entity

            if ship and ship.physics and ship.vehicle and ship.transform and ship.physics.body then
                local body = ship.physics.body
                local stats = ship.vehicle
                local trans = ship.transform

                -- A. Handle Rotation
                if input.turn ~= 0 then
                    local current_angle = body:getAngle()
                    current_angle = current_angle + input.turn * stats.turn_speed * dt
                    body:setAngle(current_angle)
                end

                -- B. Handle Thrust
                if input.thrust then
                    local angle = body:getAngle()
                    local fx = math.cos(angle) * stats.thrust
                    local fy = math.sin(angle) * stats.thrust
                    body:applyForce(fx, fy)
                end

                -- C. Cap Speed
                local vx, vy = body:getLinearVelocity()
                local speed = math.sqrt(vx * vx + vy * vy)
                if speed > stats.max_speed then
                    local scale = stats.max_speed / speed
                    body:setLinearVelocity(vx * scale, vy * scale)
                end

                -- D. Sync Transform
                trans.r = body:getAngle()
            end
        end
    end
end

return InputSystem