-- Collision handling utilities
local EntityUtils = require "src.utils.entity_utils"

local CollisionHandlers = {}

-- Handle collision between a projectile and an asteroid
function CollisionHandlers.handle_projectile_asteroid(projectile, target, world)
    if not (projectile and projectile.projectile and target and target.hp) then
        return
    end
    
    local projComp = projectile.projectile
    
    -- Ignore if projectile is already expired
    if projComp.lifetime and projComp.lifetime <= 0 then
        return
    end
    
    local damage = projComp.damage or 0
    if damage <= 0 then
        projComp.lifetime = 0
        return
    end
    
    -- Apply damage to target
    EntityUtils.apply_damage(target, damage)
    
    -- Mark projectile as expired (shards will spawn in projectile system)
    projComp.lifetime = 0
end

return CollisionHandlers
