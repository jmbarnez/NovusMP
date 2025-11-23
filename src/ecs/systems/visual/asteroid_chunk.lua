local Concord = require "concord"
local EntityUtils = require "src.utils.entity_utils"

local AsteroidChunkSystem = Concord.system({
    pool = {"asteroid_chunk", "lifetime", "physics", "transform"}
})



function AsteroidChunkSystem:update(dt)

    
    for _, e in ipairs(self.pool) do
        local lifetime = e.lifetime
        
        if lifetime then
            lifetime.elapsed = lifetime.elapsed + dt
            
            -- Remove chunk when lifetime expires
            if lifetime.elapsed >= lifetime.duration then
                EntityUtils.cleanup_physics_entity(e)
            end
        end
    end
end

return AsteroidChunkSystem
