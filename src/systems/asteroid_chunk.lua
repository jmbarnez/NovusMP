local Concord = require "concord"

local AsteroidChunkSystem = Concord.system({
    pool = {"asteroid_chunk", "lifetime", "physics", "transform"}
})

function AsteroidChunkSystem:init()
    self.role = "SINGLE"
end

function AsteroidChunkSystem:setRole(role)
    self.role = role
end

function AsteroidChunkSystem:update(dt)
    -- Only run on server/single player
    if self.role == "CLIENT" then return end
    
    for _, e in ipairs(self.pool) do
        local lifetime = e.lifetime
        
        if lifetime then
            lifetime.elapsed = lifetime.elapsed + dt
            
            -- Remove chunk when lifetime expires
            if lifetime.elapsed >= lifetime.duration then
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

return AsteroidChunkSystem
