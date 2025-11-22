local Concord = require "concord"

local ProjectileSystem = Concord.system({
    pool = { "projectile" }
})

function ProjectileSystem:init()
    self.role = "SINGLE"
end

function ProjectileSystem:setRole(role)
    self.role = role
end

function ProjectileSystem:update(dt)
    local world = self:getWorld()

    for _, e in ipairs(self.pool) do
        local projectile = e.projectile
        projectile.lifetime = (projectile.lifetime or 0) - dt

        if projectile.lifetime <= 0 then
            if e.physics and e.physics.body then
                local body = e.physics.body
                local fixture = e.physics.fixture
                if fixture then
                    fixture:setUserData(nil)
                end
                body:destroy()
            end

            e:destroy()
        end
    end
end

return ProjectileSystem
