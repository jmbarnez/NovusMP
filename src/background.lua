local Background = {}
Background.__index = Background

local Utils = require "src.utils"

-- 1. NEBULA SHADER
-- Uses domain warping and multi-layered noise for a "cloudy" space look.
local NebulaShaderSource = [[
extern number time;
extern vec2 offset;
extern vec2 resolution;

// Simplex/Value noise function (simplified)
vec3 mod289(vec3 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec2 mod289(vec2 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec3 permute(vec3 x) { return mod289(((x*34.0)+1.0)*x); }

float snoise(vec2 v) {
    const vec4 C = vec4(0.211324865405187, 0.366025403784439,
            -0.577350269189626, 0.024390243902439);
    vec2 i  = floor(v + dot(v, C.yy) );
    vec2 x0 = v -   i + dot(i, C.xx);
    vec2 i1;
    i1 = (x0.x > x0.y) ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
    vec4 x12 = x0.xyxy + C.xxzz;
    x12.xy -= i1;
    i = mod289(i);
    vec3 p = permute( permute( i.y + vec3(0.0, i1.y, 1.0 ))
    + i.x + vec3(0.0, i1.x, 1.0 ));
    vec3 m = max(0.5 - vec3(dot(x0,x0), dot(x12.xy,x12.xy), dot(x12.zw,x12.zw)), 0.0);
    m = m*m ;
    m = m*m ;
    vec3 x = 2.0 * fract(p * C.www) - 1.0;
    vec3 h = abs(x) - 0.5;
    vec3 ox = floor(x + 0.5);
    vec3 a0 = x - ox;
    m *= 1.79284291400159 - 0.85373472095314 * ( a0*a0 + h*h );
    vec3 g;
    g.x  = a0.x  * x0.x  + h.x  * x0.y;
    g.yz = a0.yz * x12.xz + h.yz * x12.yw;
    return 130.0 * dot(m, g);
}

float fbm(vec2 uv) {
    float value = 0.0;
    float amplitude = 0.5;
    for (int i = 0; i < 6; i++) {
        value += amplitude * snoise(uv);
        uv *= 2.0;
        amplitude *= 0.5;
    }
    return value;
}

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
    vec2 uv = screen_coords / resolution.xy;
    vec2 pos = uv + (offset * 0.00005); 
    
    float n = fbm(pos * 2.0 + (time * 0.002));
    float n2 = fbm(pos * 4.0 + vec2(n * 1.5));
    float n3 = fbm(pos * 8.0 + vec2(n2 * 0.5));
    
    vec3 c1 = vec3(0.01, 0.0, 0.05);
    vec3 c2 = vec3(0.08, 0.03, 0.15);
    vec3 c3 = vec3(0.15, 0.05, 0.25);
    vec3 c4 = vec3(0.05, 0.0, 0.1);
    
    vec3 finalColor = mix(c1, c2, smoothstep(-0.3, 0.5, n));
    finalColor = mix(finalColor, c3, smoothstep(0.2, 0.8, n2) * 0.6);
    finalColor = mix(finalColor, c4, n3 * 0.3);
    
    vec2 center = uv - 0.5;
    float dist = length(center);
    float radialNoise = fbm(vec2(atan(center.y, center.x) * 2.0, dist * 4.0));
    float softEdge = smoothstep(0.5 + radialNoise * 0.2, 0.0, dist);
    
    return vec4(finalColor * softEdge, softEdge) * color;
}
]]

function Background.new()
    local self = setmetatable({}, Background)

    self.nebulaShader = love.graphics.newShader(NebulaShaderSource)
    self.time = 0
    
    local star_size = 16
    local star_canvas = love.graphics.newCanvas(star_size, star_size)
    love.graphics.setCanvas(star_canvas)
    love.graphics.clear(0,0,0,0)
    love.graphics.setColor(1,1,1,1)
    love.graphics.circle("fill", star_size/2, star_size/2, star_size/2 - 1)
    love.graphics.setCanvas()
    
    self.starTexture = love.graphics.newImage(star_canvas:newImageData())
    self.starBatch = love.graphics.newSpriteBatch(self.starTexture, 3000, "dynamic")
    
    self:generateStars()
    self:generateNebulaPatches()
    
    return self
end

function Background:generateNebulaPatches()
    self.nebulaPatches = {}
    local w, h = love.graphics.getDimensions()
    
    local patchCount = 8
    for i = 1, patchCount do
        local size = 150 + math.random() * 250
        local segments = 32
        local vertices = {}
        
        for j = 0, segments do
            local angle = (j / segments) * math.pi * 2
            local radiusVariation = 0.7 + math.random() * 0.6
            local noiseOffset = math.random() * 0.3
            local radius = (size / 2) * radiusVariation * (1 + noiseOffset * math.sin(angle * 3 + math.random() * 10))
            table.insert(vertices, math.cos(angle) * radius)
            table.insert(vertices, math.sin(angle) * radius)
        end
        
        table.insert(self.nebulaPatches, {
            x = math.random(0, w),
            y = math.random(0, h),
            size = size,
            vertices = vertices,
            seed = math.random() * 1000,
            colors = {
                {math.random() * 0.2, math.random() * 0.1, math.random() * 0.3},
                {math.random() * 0.3, math.random() * 0.15, math.random() * 0.4},
                {math.random() * 0.4, math.random() * 0.2, math.random() * 0.5},
                {math.random() * 0.2, math.random() * 0.05, math.random() * 0.25}
            },
            alpha = 0.3 + math.random() * 0.4
        })
    end
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
            } or {1.0, 1.0, 1.0}
        })
    end
end

function Background:update(dt)
    self.time = self.time + dt
end

function Background:draw(cam_x, cam_y, cam_sector_x, cam_sector_y)
    local sw, sh = love.graphics.getDimensions()
    
    local abs_x = (cam_sector_x or 0) * 10000 + (cam_x or 0)
    local abs_y = (cam_sector_y or 0) * 10000 + (cam_y or 0)
    
    -- Draw dark background
    love.graphics.setColor(0.01, 0.01, 0.02, 1)
    love.graphics.rectangle("fill", 0, 0, sw, sh)
    
    -- Draw nebula patches with organic shapes
    love.graphics.setShader(self.nebulaShader)
    for _, patch in ipairs(self.nebulaPatches) do
        local px = (patch.x - abs_x * 0.0002) % (sw + patch.size * 2) - patch.size
        local py = (patch.y - abs_y * 0.0002) % (sh + patch.size * 2) - patch.size
        
        self.nebulaShader:send("time", self.time + patch.seed)
        self.nebulaShader:send("resolution", {patch.size, patch.size})
        self.nebulaShader:send("offset", {patch.seed * 100, patch.seed * 100})
        
        love.graphics.push()
        love.graphics.translate(px + patch.size / 2, py + patch.size / 2)
        
        love.graphics.setColor(1, 1, 1, patch.alpha)
        love.graphics.polygon("fill", patch.vertices)
        
        love.graphics.pop()
    end
    love.graphics.setShader()
    
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