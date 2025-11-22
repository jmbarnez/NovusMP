local Concord = require "concord"

local ChunkSystem = Concord.system({
    pool = {"chunk", "lifetime", "physics", "transform"}
})

function ChunkSystem:init()
    self.role = "SINGLE"
end

function ChunkSystem:setRole(role)
    self.role = role
end

function ChunkSystem:update(dt)
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

return ChunkSystem
