local Concord = require "concord"
local EntityUtils = require "src.utils.entity_utils"
local VFXSpawners = require "src.utils.vfx_spawners"

local ProjectileSystem = Concord.system({
    pool = { "projectile" }
})



function ProjectileSystem:update(dt)
    local world = self:getWorld()

    for _, e in ipairs(self.pool) do
        local projectile = e.projectile
        projectile.lifetime = (projectile.lifetime or 0) - dt

        if projectile.lifetime <= 0 then
            -- Spawn shards at projectile location before destroying
            if e.transform and e.render and e.sector then
                local color = e.render.color or {1, 1, 1, 1}
                VFXSpawners.spawn_projectile_shards(
                    world,
                    e.transform.x,
                    e.transform.y,
                    e.sector.x,
                    e.sector.y,
                    color
                )
            end
            
            EntityUtils.cleanup_physics_entity(e)
        end
    end
end

return ProjectileSystem
