local Utils = {}

local function clamp(value, min_val, max_val)
    if value < min_val then return min_val end
    if value > max_val then return max_val end
    return value
end

function Utils.clamp(val, min, max)
    return clamp(val, min, max)
end

function Utils.random_range(min_val, max_val)
    return min_val + math.random() * (max_val - min_val)
end

return Utils
