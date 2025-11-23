-- Math utility functions
local lume = require "lib.lume"

local MathUtils = {}

-- Calculate the shortest angular difference between two angles
-- Returns a value normalized to [-π, π]
function MathUtils.angle_difference(from_angle, to_angle)
    local diff = to_angle - from_angle
    
    -- Normalize to [-π, π]
    while diff < -math.pi do
        diff = diff + math.pi * 2
    end
    while diff > math.pi do
        diff = diff - math.pi * 2
    end
    
    return diff
end

-- Clamp a value between min and max (delegates to lume)
MathUtils.clamp = lume.clamp

-- Calculate angle from point 1 to point 2 (delegates to lume)
MathUtils.angle = lume.angle

return MathUtils
