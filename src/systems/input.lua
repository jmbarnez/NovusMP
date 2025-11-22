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
        for _, e in ipairs(self.controllers) do
            if e:has("pilot") then -- Assuming 'pilot' tag marks the local user's avatar
                local input = e.input

                local move_left  = world.controls:down("move_left") and 1 or 0
                local move_right = world.controls:down("move_right") and 1 or 0
                local move_up    = world.controls:down("move_up") and 1 or 0
                local move_down  = world.controls:down("move_down") and 1 or 0

                local move_x = move_right - move_left
                local move_y = move_down - move_up

                input.move_x = move_x
                input.move_y = move_y

                input.thrust = move_up == 1
                input.turn = 0
                input.fire = world.controls:down("fire")

                local ship = e.controlling and e.controlling.entity or nil
                if ship and ship.transform and ship.physics and ship.physics.body then
                    local sx, sy = ship.transform.x, ship.transform.y

                    local mx, my = love.mouse.getPosition()
                    local wx, wy = mx, my
                    if world.camera and world.camera.worldCoords then
                        wx, wy = world.camera:worldCoords(mx, my)
                    end

                    local dx = wx - sx
                    local dy = wy - sy
                    if dx ~= 0 or dy ~= 0 then
                        local desired
                        if math.atan2 then
                            desired = math.atan2(dy, dx)
                        else
                            desired = math.atan(dy, dx)
                        end
                        input.target_angle = desired
                    end
                end
            end
        end
    end

    -- 2. APPLY PHYSICS (Host / Single Player / Client Prediction)
    -- Clients NOW run this for their own 'pilot' entity
    if self.role == "HOST" or self.role == "SINGLE" or self.role == "CLIENT" then
        for _, e in ipairs(self.controllers) do
            -- If Client, ONLY apply to self (pilot)
            if self.role == "CLIENT" and not e:has("pilot") then
                goto continue_input
            end

            local input = e.input
            local ship = e.controlling.entity

            if ship and ship.physics and ship.vehicle and ship.transform and ship.physics.body then
                local body = ship.physics.body
                local stats = ship.vehicle
                local trans = ship.transform

                local current_angle = body:getAngle()

                -- A. Handle Rotation
                if input.target_angle then
                    local desired = input.target_angle
                    local diff = desired - current_angle
                    while diff < -math.pi do diff = diff + math.pi * 2 end
                    while diff >  math.pi do diff = diff - math.pi * 2 end

                    local max_step = stats.turn_speed * dt
                    if diff > max_step then
                        diff = max_step
                    elseif diff < -max_step then
                        diff = -max_step
                    end

                    current_angle = current_angle + diff
                    body:setAngle(current_angle)
                elseif input.turn ~= 0 then
                    current_angle = current_angle + input.turn * stats.turn_speed * dt
                    body:setAngle(current_angle)
                end

                -- B. Handle Thrust / Movement
                local fx, fy = 0, 0
                if input.move_x and input.move_y and (input.move_x ~= 0 or input.move_y ~= 0) then
                    local len = math.sqrt(input.move_x * input.move_x + input.move_y * input.move_y)
                    if len > 0 then
                        local nx = input.move_x / len
                        local ny = input.move_y / len
                        fx = nx * stats.thrust
                        fy = ny * stats.thrust
                    end
                elseif input.thrust then
                    local angle = body:getAngle()
                    fx = math.cos(angle) * stats.thrust
                    fy = math.sin(angle) * stats.thrust
                end

                if fx ~= 0 or fy ~= 0 then
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
            
            ::continue_input::
        end
    end
end

return InputSystem