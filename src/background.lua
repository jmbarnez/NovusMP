local Background = {}
Background.__index = Background
local Constants = require "src.constants"
local Config = require "src.config"

local STAR_FIELD_RADIUS = 60000

math.randomseed(os.time())
math.random(); math.random(); math.random()

function Background.new()
    local self = setmetatable({}, Background)

    local star_size = Constants.BACKGROUND.STAR_SIZE

    local star_canvas = love.graphics.newCanvas(star_size, star_size)
    love.graphics.setCanvas(star_canvas)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.circle("fill", star_size / 2, star_size / 2, star_size / 2 - 1)
    love.graphics.setCanvas()

    self.starTexture = love.graphics.newImage(star_canvas:newImageData())
    self.starBatch = love.graphics.newSpriteBatch(self.starTexture, Constants.BACKGROUND.STAR_SPRITE_BATCH_SIZE, "static")

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
        extern vec2 nebulaCenter;
        extern number vignetteInner;
        extern number vignetteOuter;

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
            float amplitude = 0.7;
            float frequency = 0.7;
            // Fewer, smoother octaves to avoid "puffy" blobs
            for (int i = 0; i < 4; i++) {
                value += amplitude * noise(p * frequency);
                frequency *= 1.9;
                amplitude *= 0.55;
            }
            return value;
        }

        // Sparse mask to create patchiness and thin regions
        float patchMask(vec2 p) {
            float m1 = fbm(p * 0.35 + vec2(7.3, -2.1));
            float m2 = fbm(p * 0.18 + vec2(-11.7, 4.9));
            float mask = m1 * 0.7 + m2 * 0.3;
            mask = pow(mask, 2.3);         // kill mid‑range, accentuate dense clumps
            mask = smoothstep(0.35, 0.75, mask);
            return mask;
        }

        vec4 effect(vec4 vcolor, Image tex, vec2 texcoord, vec2 screen_coords) {
            vec2 uv = screen_coords / resolution;
            vec2 p = (uv - nebulaCenter) * 2.0;
            float dist = length(p);

            // Stronger falloff so nebulae are thinner toward edges
            float vignette = 1.0 - smoothstep(vignetteInner, vignetteOuter, dist);

            // Base coordinates for nebula
            vec2 ncoord = uv * noiseScale + offset * 0.00003;
            ncoord += flow * time;

            // Multi-scale structure
            float n_coarse = fbm(ncoord * 0.9);
            float n_mid    = fbm(ncoord * 2.4 + vec2(13.2, -4.7));
            float n_fine   = fbm(ncoord * 5.3 + vec2(-8.1, 9.7));

            // Build a thinner density field
            float neb_raw = n_coarse * 1.1 - n_mid * 0.6 + n_fine * 0.25;
            neb_raw = clamp(neb_raw * 1.9 - 0.3, 0.0, 1.0);

            // Make it patchy: multiply by sparse mask
            float mask = patchMask(ncoord);
            neb_raw *= mask;

            // Sharpen the contrast a bit so there are clearer holes
            neb_raw = pow(neb_raw, 1.35);

            // Soft "ridges" to hint at thin filaments instead of blobs
            float ridged = 1.0 - abs(neb_raw * 2.3 - 1.1);
            float filaments = mix(neb_raw, ridged, 0.4);
            filaments = pow(filaments, 1.4);

            // Thin overall coverage: scale down intensity and limit to vignette
            float clouds = filaments * vignette;
            clouds *= 1.05;

            vec3 nebula = mix(colorA, colorB, neb_raw);

            // Emphasize pleasing mid-density regions
            float midband = smoothstep(0.25, 0.6, neb_raw);
            float softband = smoothstep(0.05, 0.35, neb_raw);

            // Soft backlight tint based on the layer's palette
            vec3 backTint = normalize(colorA + colorB + vec3(0.35, 0.35, 0.45));

            nebula *= 0.55 + 0.45 * midband;
            nebula += backTint * clouds * 0.25 * softband;

            // Small bright cores only in the densest regions
            float core = smoothstep(0.78, 0.96, neb_raw);
            nebula += core * 0.35;

            // Alpha: thin, patchy, and attenuated by vignette, but slightly stronger overall
            float alpha = clouds * alphaScale;
            alpha *= 0.8;
            alpha = clamp(alpha, 0.0, 1.0);

            return vec4(nebula, alpha) * vcolor;
        }
    ]])

    self.nebulaParams = { layers = {} }

    local function randomColorComponent(min, max)
        return min + math.random() * (max - min)
    end

    local intensityBase = Constants.BACKGROUND.NEBULA.INTENSITY_BASE
    local intensityRange = Constants.BACKGROUND.NEBULA.INTENSITY_RANGE

    local layerConfigs = {
        { parallax = 0.02, noiseMul = 0.8, alphaMul = 0.6 },
        { parallax = 0.04, noiseMul = 1.0, alphaMul = 0.8 },
        { parallax = 0.07, noiseMul = 1.3, alphaMul = 1.0 },
    }

    for _, cfg in ipairs(layerConfigs) do
        local layer = {}

        local cx = 0.5 + (math.random() - 0.5) * 0.8
        local cy = 0.5 + (math.random() - 0.5) * 0.8
        layer.center = { cx, cy }

        local inner = 0.45 + math.random() * 0.25
        local outer = inner + 0.4 + math.random() * 0.3
        layer.vignetteInner = inner
        layer.vignetteOuter = outer

        layer.offsetBase = { math.random() * 10000, math.random() * 10000 }

        local noiseBase = Constants.BACKGROUND.NEBULA.NOISE_SCALE_BASE
        local noiseRange = Constants.BACKGROUND.NEBULA.NOISE_SCALE_RANGE
        layer.noiseScale = (noiseBase + math.random() * noiseRange) * cfg.noiseMul

        local flowAngle = math.random() * math.pi * 2
        local flowSpeed = Constants.BACKGROUND.NEBULA.FLOW_SPEED_BASE + math.random() * Constants.BACKGROUND.NEBULA.FLOW_SPEED_RANGE
        layer.flow = {
            math.cos(flowAngle) * flowSpeed,
            math.sin(flowAngle) * flowSpeed
        }

        local intensityA = intensityBase + math.random() * intensityRange
        local intensityB = intensityBase + math.random() * intensityRange
        local hueShift = math.random() * Constants.BACKGROUND.NEBULA.HUE_SHIFT_RANGE

        layer.colorA = {
            randomColorComponent(0.15, 0.75) * intensityA,
            randomColorComponent(0.10 + hueShift, 0.85) * intensityA,
            randomColorComponent(0.35, 0.95) * intensityA
        }

        layer.colorB = {
            randomColorComponent(0.4, 0.9) * intensityB,
            randomColorComponent(0.1, 0.6) * intensityB,
            randomColorComponent(0.15, 0.7) * intensityB
        }

        local alphaBase = Constants.BACKGROUND.NEBULA.ALPHA_SCALE_BASE
        local alphaRange = Constants.BACKGROUND.NEBULA.ALPHA_SCALE_RANGE
        layer.alphaScale = (alphaBase + math.random() * alphaRange) * cfg.alphaMul

        layer.parallax = cfg.parallax

        table.insert(self.nebulaParams.layers, layer)
    end

    self:generateStars()

    return self
end

function Background:generateStars(w, h)
    self.stars = {}

    local sw, sh
    if w and h then
        sw, sh = w, h
    else
        sw, sh = love.graphics.getDimensions()
    end

    self.screenWidth = sw
    self.screenHeight = sh

    local star_colors = Constants.BACKGROUND.STAR_COLORS
    local color_weights = Constants.BACKGROUND.STAR_COLOR_WEIGHTS

    local count = Constants.BACKGROUND.STAR_COUNT

    for i = 1, count do
        local brightness = math.random()
        local size_factor = brightness * brightness

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
        local thresholds = Constants.BACKGROUND.LAYER_THRESHOLDS
        if layer_roll < thresholds.NEAR then
            layer = 3
        elseif layer_roll < thresholds.MID then
            layer = 2
        else
            layer = 1
        end

        local size
        local speed
        local base_alpha

        local layer_params = Constants.BACKGROUND.LAYER_PARAMS[layer]
        if layer_params then
            size = layer_params.SIZE_MIN + size_factor * layer_params.SIZE_FACTOR
            speed = layer_params.SPEED_MIN + size_factor * layer_params.SPEED_FACTOR
            base_alpha = layer_params.ALPHA_MIN + size_factor * layer_params.ALPHA_FACTOR
        end

        if size < Constants.BACKGROUND.MIN_STAR_SIZE then
            size = Constants.BACKGROUND.MIN_STAR_SIZE
        end

        local twinkle_speed
        local twinkle_amp
        if layer == 3 then
            twinkle_speed = 0.35 + math.random() * 0.5
            twinkle_amp = 0.08 + math.random() * 0.06
        elseif layer == 2 then
            twinkle_speed = 0.25 + math.random() * 0.4
            twinkle_amp = 0.04 + math.random() * 0.06
        else
            twinkle_speed = 0.18 + math.random() * 0.3
            twinkle_amp = 0.02 + math.random() * 0.04
        end

        local twinkle_phase = math.random() * math.pi * 2

        self.stars[i] = {
            x = math.random(0, self.screenWidth),
            y = math.random(0, self.screenHeight),
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

    if not self.screenWidth or self.screenWidth ~= sw or self.screenHeight ~= sh then
        self:generateStars(sw, sh)
    end

    local abs_x = (cam_sector_x or 0) * Config.SECTOR_SIZE + (cam_x or 0)
    local abs_y = (cam_sector_y or 0) * Config.SECTOR_SIZE + (cam_y or 0)

    local clear = Constants.BACKGROUND.CLEAR_COLOR
    love.graphics.setColor(clear[1], clear[2], clear[3], clear[4])
    love.graphics.rectangle("fill", 0, 0, sw, sh)

    if self.nebulaShader and self.nebulaParams and self.nebulaParams.layers then
        love.graphics.setShader(self.nebulaShader)
        love.graphics.setColor(1, 1, 1, 1)

        for _, layer in ipairs(self.nebulaParams.layers) do
            local baseOffset = layer.offsetBase or { 0, 0 }
            local parallax = layer.parallax or 0.05
            local offset_x = baseOffset[1] + abs_x * parallax
            local offset_y = baseOffset[2] + abs_y * parallax

            self.nebulaShader:send("time", self.time or 0)
            self.nebulaShader:send("offset", {offset_x, offset_y})
            self.nebulaShader:send("resolution", {sw, sh})
            self.nebulaShader:send("noiseScale", layer.noiseScale)
            self.nebulaShader:send("flow", layer.flow)
            self.nebulaShader:send("alphaScale", layer.alphaScale)
            self.nebulaShader:send("colorA", layer.colorA)
            self.nebulaShader:send("colorB", layer.colorB)
            self.nebulaShader:send("nebulaCenter", layer.center)
            self.nebulaShader:send("vignetteInner", layer.vignetteInner)
            self.nebulaShader:send("vignetteOuter", layer.vignetteOuter)

            love.graphics.rectangle("fill", 0, 0, sw, sh)
        end

        love.graphics.setShader()
    end

    self.starBatch:clear()
    
    for _, star in ipairs(self.stars) do
        local px = (star.x - abs_x * star.speed) % sw
        local py = (star.y - abs_y * star.speed) % sh

        px = math.floor(px + 0.5)
        py = math.floor(py + 0.5)

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