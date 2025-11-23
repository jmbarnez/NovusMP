-- Entity management utility functions

local EntityUtils = {}

-- Safely cleanup an entity with physics components
-- Handles fixture userdata, body destruction, and entity destruction
function EntityUtils.cleanup_physics_entity(entity)
    if not entity then return end
    
    local physics = entity.physics
    if physics then
        if physics.fixture then
            physics.fixture:setUserData(nil)
        end
        if physics.body then
            physics.body:destroy()
        end
    end
    
    entity:destroy()
end

-- Apply damage to an entity and update last hit time
function EntityUtils.apply_damage(entity, damage)
    if not entity or not entity.hp then return end
    
    local hp = entity.hp
    local current = hp.current or hp.max or 0
    
    current = current - damage
    if current < 0 then
        current = 0
    end
    
    hp.current = current
    
    -- Update last hit time
    if love and love.timer and love.timer.getTime then
        hp.last_hit_time = love.timer.getTime()
    end
end

return EntityUtils
