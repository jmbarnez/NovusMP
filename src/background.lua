local Background = {}
Background.__index = Background

math.randomseed(os.time())
math.random(); math.random(); math.random()

function Background.new()
    local self = setmetatable({}, Background)

    local star_size = 16
    local star_canvas = love.graphics.newCanvas(star_size, star_size)
    love.graphics.setCanvas(star_canvas)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.circle("fill", star_size / 2, star_size / 2, star_size / 2 - 1)
    love.graphics.setCanvas()

    self.starTexture = love.graphics.newImage(star_canvas:newImageData())
    self.starBatch = love.graphics.newSpriteBatch(self.starTexture, 3000, "static")

    self.time = 0
    self.nebulaShader = love.graphics.newShader([[
        extern number time;
        extern vec2 offset;
        extern vec2 resolution;
        extern number noiseScale;
        extern vec2 flow;
        extern number alphaScale;
        extern vec3 colorA;
        extern vec3 colorB;

        float hash(vec2 p) {
            p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
            return fract(sin(p.x + p.y) * 43758.5453123);
        }

        float noise(vec2 p) {
            vec2 i = floor(p);
            vec2 f = fract(p);

            float a = hash(i);
            float b = hash(i + vec2(1.0, 0.0));
            float c = hash(i + vec2(0.0, 1.0));
            float d = hash(i + vec2(1.0, 1.0));

            vec2 u = f * f * (3.0 - 2.0 * f);

            return mix(a, b, u.x) +
                (c - a) * u.y * (1.0 - u.x) +
                (d - b) * u.x * u.y;
        }

        float fbm(vec2 p) {
            float value = 0.0;
            float amplitude = 0.5;
            float frequency = 1.0;
            for (int i = 0; i < 5; i++) {
                value += amplitude * noise(p * frequency);
                frequency *= 2.0;
                amplitude *= 0.5;
            }
            return value;
        }

        vec4 effect(vec4 vcolor, Image tex, vec2 texcoord, vec2 screen_coords) {
            vec2 uv = screen_coords / resolution;
            vec2 p = (uv - 0.5) * 2.0;
            float dist = length(p);
            float vignette = 1.0 - smoothstep(0.9, 1.4, dist);

            vec2 ncoord = uv * noiseScale + offset * 0.00003;

            ncoord += flow * time;

            float n1 = fbm(ncoord);
            float n2 = fbm(ncoord * 2.7 + vec2(13.2, -4.7));

            float neb_raw = n1 * 1.3 - n2 * 0.7;
            neb_raw = clamp(neb_raw * 1.6 + 0.2, 0.0, 1.0);

            float ridged = 1.0 - abs(neb_raw * 2.0 - 1.0);
            float clouds = mix(neb_raw, ridged, 0.5);
            clouds = pow(clouds, 1.2);
            clouds *= (0.8 + 0.2 * vignette);

            vec3 nebula = mix(colorA, colorB, neb_raw);

            float core = smoothstep(0.65, 0.95, neb_raw);
            nebula += core * 0.25;

            float alpha = clouds * alphaScale;

            return vec4(nebula, alpha) * vcolor;
        }
    ]])

    self.nebulaParams = {}

    self.nebulaParams.noiseScale = 2.0 + math.random() * 3.0
    local flowAngle = math.random() * math.pi * 2
    local flowSpeed = math.random() * 0.00003
    self.nebulaParams.flow = {math.cos(flowAngle) * flowSpeed, math.sin(flowAngle) * flowSpeed}

    self.nebulaParams.alphaScale = 0.25 + math.random() * 0.5

    local function randomColorComponent(min, max)
        return min + math.random() * (max - min)
    end

    local intensityA = 0.5 + math.random() * 0.5
    local intensityB = 0.5 + math.random() * 0.5

    self.nebulaParams.colorA = {
        randomColorComponent(0.1, 0.9) * intensityA,
        randomColorComponent(0.1, 0.9) * intensityA,
        randomColorComponent(0.1, 0.9) * intensityA
    }

    self.nebulaParams.colorB = {
        randomColorComponent(0.1, 0.9) * intensityB,
        randomColorComponent(0.1, 0.9) * intensityB,
        randomColorComponent(0.1, 0.9) * intensityB
    }

    self:generateStars()

    return self
end

function Background:generateStars()
    self.stars = {}
    local w, h = love.graphics.getDimensions()

    -- Real star color temperatures (RGB approximations)
    local star_colors = {
        {0.6, 0.7, 1.0},   -- Blue (O-type, hottest)
        {0.75, 0.85, 1.0}, -- Blue-white (B-type)
        {0.95, 0.95, 1.0}, -- White (A-type)
        {1.0, 1.0, 0.95},  -- Yellow-white (F-type)
        {1.0, 0.95, 0.8},  -- Yellow (G-type, like our Sun)
        {1.0, 0.85, 0.6},  -- Orange (K-type)
        {1.0, 0.7, 0.5}    -- Red (M-type, coolest)
    }
    
    -- Distribution weights (red/orange stars are most common)
    local color_weights = {0.03, 0.08, 0.12, 0.15, 0.20, 0.22, 0.20}

    local count = 2000
    for i = 1, count do
        local brightness = math.random()
        local size_factor = brightness * brightness

        -- Select star color based on realistic distribution
        local roll = math.random()
        local cumulative = 0
        local color_tint = star_colors[#star_colors]
        for j, weight in ipairs(color_weights) do
            cumulative = cumulative + weight
            if roll <= cumulative then
                color_tint = star_colors[j]
                break
            end
        end

        local layer_roll = math.random()
        local layer
        if layer_roll < 0.2 then
            layer = 3
        elseif layer_roll < 0.6 then
            layer = 2
        else
            layer = 1
        end

        local size
        local speed
        local base_alpha

        if layer == 3 then
            size = 0.06 + size_factor * 0.18
            speed = 0.006 + size_factor * 0.010
            base_alpha = 0.5 + size_factor * 0.5
        elseif layer == 2 then
            size = 0.03 + size_factor * 0.14
            speed = 0.003 + size_factor * 0.007
            base_alpha = 0.3 + size_factor * 0.5
        else
            size = 0.015 + size_factor * 0.10
            speed = 0.001 + size_factor * 0.005
            base_alpha = 0.15 + size_factor * 0.4
        end

        local twinkle_speed = 0.5 + math.random() * 1.5
        local twinkle_amp = 0.3 + math.random() * 0.4
        local twinkle_phase = math.random() * math.pi * 2

        self.stars[i] = {
            x = math.random(0, w),
            y = math.random(0, h),
            size = size,
            speed = speed,
            alpha = base_alpha,
            base_alpha = base_alpha,
            layer = layer,
            twinkle_speed = twinkle_speed,
            twinkle_phase = twinkle_phase,
            twinkle_amp = twinkle_amp,
            color_tint = color_tint
        }
    end
end

function Background:update(dt)
    if self.time then
        self.time = self.time + dt
    end
    if self.stars then
        for _, star in ipairs(self.stars) do
            if star.twinkle_speed and star.base_alpha and star.twinkle_amp and star.twinkle_phase then
                star.twinkle_phase = star.twinkle_phase + star.twinkle_speed * dt
                local tw = 0.5 + 0.5 * math.sin(star.twinkle_phase)
                local alpha = star.base_alpha * (1.0 - star.twinkle_amp * 0.5 + star.twinkle_amp * tw)
                if alpha < 0 then alpha = 0 end
                if alpha > 1 then alpha = 1 end
                star.alpha = alpha
            end
        end
    end
end

function Background:draw(cam_x, cam_y, cam_sector_x, cam_sector_y)
    local sw, sh = love.graphics.getDimensions()

    local abs_x = (cam_sector_x or 0) * 10000 + (cam_x or 0)
    local abs_y = (cam_sector_y or 0) * 10000 + (cam_y or 0)

    -- Deep space background
    love.graphics.setColor(0.005, 0.005, 0.01, 1)
    love.graphics.rectangle("fill", 0, 0, sw, sh)

    love.graphics.setColor(0.01, 0.01, 0.03, 0.9)
    love.graphics.rectangle("fill", 0, 0, sw, sh * 0.6)
    love.graphics.setColor(0.0, 0.0, 0.06, 0.6)
    love.graphics.rectangle("fill", 0, sh * 0.3, sw, sh * 0.7)

    if self.nebulaShader and self.nebulaParams then
        local offset_x = abs_x * 0.05
        local offset_y = abs_y * 0.05
        self.nebulaShader:send("time", self.time or 0)
        self.nebulaShader:send("offset", {offset_x, offset_y})
        self.nebulaShader:send("resolution", {sw, sh})
        self.nebulaShader:send("noiseScale", self.nebulaParams.noiseScale)
        self.nebulaShader:send("flow", self.nebulaParams.flow)
        self.nebulaShader:send("alphaScale", self.nebulaParams.alphaScale)
        self.nebulaShader:send("colorA", self.nebulaParams.colorA)
        self.nebulaShader:send("colorB", self.nebulaParams.colorB)
        love.graphics.setShader(self.nebulaShader)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle("fill", 0, 0, sw, sh)
        love.graphics.setShader()
    end

    -- Stars with parallax
    self.starBatch:clear()
    
    for _, star in ipairs(self.stars) do
        local px = (star.x - abs_x * star.speed) % sw
        local py = (star.y - abs_y * star.speed) % sh

        self.starBatch:setColor(
            star.color_tint[1],
            star.color_tint[2],
            star.color_tint[3],
            star.alpha
        )
        self.starBatch:add(px, py, 0, star.size, star.size, 8, 8)
    end

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(self.starBatch)
end

return Background