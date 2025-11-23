local Concord = require "concord"
local EntityUtils = require "src.utils.entity_utils"

local ProjectileShardSystem = Concord.system({
    pool = {"projectile_shard", "lifetime", "transform"}
})



function ProjectileShardSystem:update(dt)

    
    for _, e in ipairs(self.pool) do
        local lifetime = e.lifetime
        
        if lifetime then
            lifetime.elapsed = lifetime.elapsed + dt
            
            -- Remove shard when lifetime expires
            if lifetime.elapsed >= lifetime.duration then
                EntityUtils.cleanup_physics_entity(e)
            end
        end
    end
end

return ProjectileShardSystem
