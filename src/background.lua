local Background = {}
Background.__index = Background

local Utils = require "src.utils"

-- Static nebula shader (no time-based animation, but with color/intensity variation)
local NebulaShaderSource = [[
extern vec2 offset;
extern vec2 resolution;
extern vec3 baseColorA;
extern vec3 baseColorB;
extern number intensity;

// Simplex/Value noise (2D)
vec3 mod289(vec3 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec2 mod289(vec2 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec3 permute(vec3 x) { return mod289(((x*34.0)+1.0)*x); }

float snoise(vec2 v) {
    const vec4 C = vec4(0.211324865405187, 0.366025403784439,
                        -0.577350269189626, 0.024390243902439);
    vec2 i  = floor(v + dot(v, C.yy));
    vec2 x0 = v - i + dot(i, C.xx);
    vec2 i1 = (x0.x > x0.y) ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
    vec4 x12 = x0.xyxy + C.xxzz;
    x12.xy -= i1;
    i = mod289(i);
    vec3 p = permute(permute(i.y + vec3(0.0, i1.y, 1.0))
                   + i.x + vec3(0.0, i1.x, 1.0));
    vec3 m = max(0.5 - vec3(
        dot(x0, x0),
        dot(x12.xy, x12.xy),
        dot(x12.zw, x12.zw)
    ), 0.0);
    m = m * m;
    m = m * m;
    vec3 x = 2.0 * fract(p * C.www) - 1.0;
    vec3 h = abs(x) - 0.5;
    vec3 ox = floor(x + 0.5);
    vec3 a0 = x - ox;
    m *= 1.79284291400159 - 0.85373472095314 * (a0*a0 + h*h);
    vec3 g;
    g.x  = a0.x  * x0.x  + h.x  * x0.y;
    g.yz = a0.yz * x12.xz + h.yz * x12.yw;
    return 130.0 * dot(m, g);
}

float fbm(vec2 uv) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;
    for (int i = 0; i < 5; i++) {
        value += amplitude * snoise(uv * frequency);
        frequency *= 2.0;
        amplitude *= 0.5;
    }
    return value;
}

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
    vec2 uv = screen_coords / resolution.xy;

    // Centered, gently warped UVs (no time, so this is static)
    vec2 p = (uv - 0.5) * 2.0;

    // Use offset to pick a different part of noise space between sectors
    vec2 baseUV = p * 1.2 + offset * 0.0002;

    float base  = fbm(baseUV * 1.2);
    float layer = fbm(baseUV * 2.5);
    float detail = fbm(baseUV * 5.0);

    float density = smoothstep(-0.3, 0.6, base)
                  + 0.4 * smoothstep(0.1, 0.9, layer)
                  + 0.3 * detail;

    density = clamp(density * intensity, 0.0, 1.5);

    // Blend between two base colors, with some small extra variation
    vec3 colA = baseColorA;
    vec3 colB = baseColorB;
    float mixBase = smoothstep(0.0, 1.0, base);
    float mixDetail = smoothstep(0.0, 1.0, detail);
    vec3 col = mix(colA, colB, mixBase);
    col += 0.25 * mix(colA, colB, mixDetail) * (density * 0.5);

    // Radial softening so edges fade into space
    float r = length(p);
    float vignette = smoothstep(1.4, 0.3, r);
    float glow = smoothstep(0.0, 0.9, density) * vignette;

    col *= glow;

    return vec4(col, glow) * color;
}
]]

function Background.new()
    local self = setmetatable({}, Background)

    self.nebulaShader = love.graphics.newShader(NebulaShaderSource)
    self.time = 0

    -- Random static nebula palette/intensity chosen once per Background
    self.nebulaColorA = {
        0.01 + math.random() * 0.04, -- dark base
        0.00 + math.random() * 0.06,
        0.04 + math.random() * 0.10
    }
    self.nebulaColorB = {
        0.06 + math.random() * 0.20, -- brighter accent
        0.10 + math.random() * 0.20,
        0.18 + math.random() * 0.25
    }
    self.nebulaIntensity = 0.7 + math.random() * 0.6

    local star_size = 16
    local star_canvas = love.graphics.newCanvas(star_size, star_size)
    love.graphics.setCanvas(star_canvas)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.circle("fill", star_size / 2, star_size / 2, star_size / 2 - 1)
    love.graphics.setCanvas()

    self.starTexture = love.graphics.newImage(star_canvas:newImageData())
    self.starBatch = love.graphics.newSpriteBatch(self.starTexture, 3000, "dynamic")

    self:generateStars()

    return self
end

-- deprecated patch generator kept as no-op to avoid caller errors
function Background:generateNebulaPatches()
    self.nebulaPatches = {}
end

function Background:generateStars()
    self.stars = {}
    local w, h = love.graphics.getDimensions()

    local count = 1500
    for i = 1, count do
        local brightness = math.random()
        local size_factor = brightness ^ 2

        table.insert(self.stars, {
            x = math.random(0, w),
            y = math.random(0, h),
            size = (0.05 + size_factor * 0.35),
            speed = 0.001 + size_factor * 0.005,
            alpha = 0.15 + (brightness ^ 2) * 0.5,
            twinkle_speed = 0.5 + math.random() * 2.0,
            twinkle_offset = math.random() * math.pi * 2,
            color_tint = math.random() < 0.1 and {
                1.0,
                0.9 + math.random() * 0.1,
                0.95 + math.random() * 0.05
            } or { 1.0, 1.0, 1.0 }
        })
    end
end

function Background:update(dt)
    -- keep time for stars only; nebula is static
    self.time = self.time + dt
end

function Background:draw(cam_x, cam_y, cam_sector_x, cam_sector_y)
    local sw, sh = love.graphics.getDimensions()

    local abs_x = (cam_sector_x or 0) * 10000 + (cam_x or 0)
    local abs_y = (cam_sector_y or 0) * 10000 + (cam_y or 0)

    -- Base background
    love.graphics.setColor(0.01, 0.01, 0.02, 1)
    love.graphics.rectangle("fill", 0, 0, sw, sh)

    -- Fullscreen static procedural nebula
    love.graphics.setShader(self.nebulaShader)
    self.nebulaShader:send("resolution", { sw, sh })
    self.nebulaShader:send("offset", { abs_x, abs_y })
    self.nebulaShader:send("baseColorA", self.nebulaColorA)
    self.nebulaShader:send("baseColorB", self.nebulaColorB)
    self.nebulaShader:send("intensity", self.nebulaIntensity)

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", 0, 0, sw, sh)
    love.graphics.setShader()

    -- Stars
    self.starBatch:clear()

    for _, star in ipairs(self.stars) do
        local px = (star.x - abs_x * star.speed) % sw
        local py = (star.y - abs_y * star.speed) % sh

        local twinkle = 0.5 + 0.25 * math.sin(self.time * star.twinkle_speed + star.twinkle_offset)
        local alpha = star.alpha * twinkle

        self.starBatch:setColor(
            star.color_tint[1],
            star.color_tint[2],
            star.color_tint[3],
            alpha
        )
        self.starBatch:add(px, py, 0, star.size, star.size, 8, 8)
    end

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(self.starBatch)
end

return Background