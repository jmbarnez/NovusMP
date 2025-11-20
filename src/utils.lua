local Utils = {}

local STAR_COLORS = {
    {weight = 0.10, color = {0.78, 0.85, 1.00}}, -- Blue-white
    {weight = 0.18, color = {0.86, 0.90, 1.00}}, -- Cool white
    {weight = 0.34, color = {1.00, 0.97, 0.90}}, -- Warm white
    {weight = 0.26, color = {1.00, 0.91, 0.75}}, -- Golden
    {weight = 0.12, color = {1.00, 0.82, 0.70}}  -- Soft orange/red
}

local TOTAL_COLOR_WEIGHT = 0
for _, entry in ipairs(STAR_COLORS) do
    TOTAL_COLOR_WEIGHT = TOTAL_COLOR_WEIGHT + entry.weight
end

local function clamp(value, min_val, max_val)
    if value < min_val then return min_val end
    if value > max_val then return max_val end
    return value
end

local function random_range(min_val, max_val)
    return min_val + math.random() * (max_val - min_val)
end

local function pick_star_color()
    local roll = math.random() * TOTAL_COLOR_WEIGHT
    local acc = 0
    for _, entry in ipairs(STAR_COLORS) do
        acc = acc + entry.weight
        if roll <= acc then
            return {
                clamp(entry.color[1] + random_range(-0.03, 0.03), 0, 1),
                clamp(entry.color[2] + random_range(-0.03, 0.03), 0, 1),
                clamp(entry.color[3] + random_range(-0.03, 0.03), 0, 1)
            }
        end
    end

    -- Fallback (should not happen)
    local fallback = STAR_COLORS[#STAR_COLORS].color
    return {fallback[1], fallback[2], fallback[3]}
end

local function add_stars(starfield, count, width, height, layer)
    for _ = 1, count do
        local star = {
            x = math.random() * width,
            y = math.random() * height,
            size = random_range(layer.size_min, layer.size_max),
            speed = random_range(layer.speed_min, layer.speed_max),
            alpha = random_range(layer.alpha_min, layer.alpha_max),
            color = pick_star_color()
        }

        if layer.glow_chance and math.random() < layer.glow_chance then
            star.glow_radius = random_range(layer.glow_min, layer.glow_max)
            star.glow_alpha = star.alpha * random_range(0.35, 0.55)
        end

        table.insert(starfield, star)
    end
end

function Utils.generate_starfield(options)
    options = options or {}

    local width = options.width or select(1, love.graphics.getDimensions())
    local height = options.height or select(2, love.graphics.getDimensions())
    local scale_density = options.scale_density or false
    local base_area = options.base_area or (1280 * 720)
    local area = width * height

    local function scaled_count(base_count)
        if not scale_density then
            return base_count
        end

        local scaled = math.floor(base_count * area / base_area + 0.5)
        if scaled < 1 then
            return 1
        end
        return scaled
    end

    local starfield = {}

    local layers = {
        {
            base_count = 600,
            size_min = 1.0,
            size_max = 1.1,
            speed_min = 0.0005,
            speed_max = 0.0012,
            alpha_min = 0.22,
            alpha_max = 0.45
        },
        {
            base_count = 220,
            size_min = 1.1,
            size_max = 1.4,
            speed_min = 0.0012,
            speed_max = 0.0026,
            alpha_min = 0.4,
            alpha_max = 0.65,
            glow_chance = 0.15,
            glow_min = 1.2,
            glow_max = 2.0
        },
        {
            base_count = 40,
            size_min = 1.4,
            size_max = 1.9,
            speed_min = 0.0026,
            speed_max = 0.0042,
            alpha_min = 0.65,
            alpha_max = 0.95,
            glow_chance = 0.55,
            glow_min = 2.0,
            glow_max = 3.6
        }
    }

    for _, layer in ipairs(layers) do
        local count = scaled_count(layer.base_count)
        add_stars(starfield, count, width, height, layer)
    end

    return starfield
end

function Utils.build_star_mesh(stars)
    if not stars or #stars == 0 then
        return nil
    end

    local format = {
        {"VertexPosition", "float", 2},
        {"VertexColor", "float", 4},
    }

    local vertices = {}
    for i, star in ipairs(stars) do
        local x = math.floor(star.x) + 0.5
        local y = math.floor(star.y) + 0.5

        local color = star.color or {1, 1, 1}
        local r, g, b = color[1], color[2], color[3]
        local a = star.alpha or 1

        vertices[i] = {x, y, r, g, b, a}
    end

    local mesh = love.graphics.newMesh(format, vertices, "points", "dynamic")
    return mesh
end

return Utils