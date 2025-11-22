local Concord = require "concord"

local ProjectileShardSystem = Concord.system({
    pool = {"projectile_shard", "lifetime", "transform"}
})

function ProjectileShardSystem:init()
    self.role = "SINGLE"
end

function ProjectileShardSystem:setRole(role)
    self.role = role
end

function ProjectileShardSystem:update(dt)
    -- Only run on server/single player
    if self.role == "CLIENT" then return end
    
    for _, e in ipairs(self.pool) do
        local lifetime = e.lifetime
        
        if lifetime then
            lifetime.elapsed = lifetime.elapsed + dt
            
            -- Remove shard when lifetime expires
            if lifetime.elapsed >= lifetime.duration then
                -- Clean up physics if present
                local p = e.physics
                if p then
                    if p.fixture then
                        p.fixture:setUserData(nil)
                    end
                    if p.body then
                        p.body:destroy()
                    end
                end
                e:destroy()
            end
        end
    end
end

return ProjectileShardSystem
