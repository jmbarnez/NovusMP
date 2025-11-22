local Concord = require "concord"
local Config  = require "src.config"

-- Handles client-side interpolation towards server snapshots.
local NetworkSyncSystem = Concord.system({
    pool = { "network_sync", "transform", "sector" },
})

function NetworkSyncSystem:update(dt)
    -- Clients interpolate towards the server's truth
    local lerp = Config.LERP_FACTOR or 10.0

    for _, e in ipairs(self.pool) do
        -- Skip interpolation for the local pilot (client-side prediction)
        if e:has("pilot") then goto continue_sync end

        local sync = e.network_sync
        local t    = e.transform
        local s    = e.sector

        -- Simple sector check: if sector differs, snap immediately
        if s.x ~= sync.target_sector_x or s.y ~= sync.target_sector_y then
            s.x = sync.target_sector_x
            s.y = sync.target_sector_y
            t.x = sync.target_x
            t.y = sync.target_y
        else
            -- Interpolate position
            t.x = t.x + (sync.target_x - t.x) * lerp * dt
            t.y = t.y + (sync.target_y - t.y) * lerp * dt

            -- Shortest-angle interpolation
            local dr = sync.target_r - t.r
            while dr < -math.pi do dr = dr + math.pi * 2 end
            while dr >  math.pi do dr = dr - math.pi * 2 end
            t.r = t.r + dr * lerp * dt
        end

        if e.physics and e.physics.body then
            e.physics.body:setPosition(t.x, t.y)
            e.physics.body:setAngle(t.r or 0)
        end

        ::continue_sync::
    end
end

return NetworkSyncSystem
