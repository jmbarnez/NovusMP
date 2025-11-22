local Background = {}
Background.__index = Background
local Constants = require "src.constants"
local Config = require "src.config"

local STAR_FIELD_RADIUS = 60000

-- Improved seeding
math.randomseed(os.time() + math.floor(love.timer.getTime() * 1000))
math.random(); math.random(); math.random()

function Background.new(enableNebula)
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
    if enableNebula == false then
        self.nebulaShader = nil
    else
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
            p = vec2(dot(p, vec2(137.1, 311.7)), dot(p, vec2(269.5, 183.3)));
            return fract(sin(p.x + p.y) * 43758.5453123);
        }

        float noise(vec2 p) {
            vec2 i = floor(p);
            vec2 f = fract(p);
            f = f * f * (3.0 - 2.0 * f);
            
            float n = mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
                          mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x),
                          f.y);
            return n;
        }

        float fbm(vec2 p, int octaves) {
            float value = 0.0;
            float amplitude = 0.6;
            float frequency = 1.0;
            
            for (int i = 0; i < 6; i++) {
                if (i >= octaves) break;
                value += amplitude * noise(p * frequency);
                frequency *= 2.0;
                amplitude *= 0.5;
            }
            return value;
        }

        vec4 effect(vec4 vcolor, Image tex, vec2 texcoord, vec2 screen_coords) {
            vec2 uv = screen_coords / resolution;
            vec2 p = (uv - 0.5) * 2.0;
            
            vec2 ncoord = uv * noiseScale + offset * 0.00005;
            ncoord += flow * time * 0.8;
            
            float base = fbm(ncoord * 0.8, 5);
            float detail = fbm(ncoord * 3.2 + vec2(time * 0.1), 4);
            float turb = fbm(ncoord * 1.5 + vec2(time * 0.05), 1);
            
            float density = base * 0.7 + detail * 0.3;
            density = pow(density, 1.8);
            density += turb * 0.2;
            
            float mask = fbm(ncoord * 0.4 + vec2(13.7, -8.3), 3);
            mask = smoothstep(0.3, 0.8, mask);
            density *= mask;
            
            vec3 color = mix(colorA, colorB, density);
            
            float glow = smoothstep(0.6, 0.9, density);
            color += glow * mix(colorA, colorB, 0.5) * 0.4;
            
            float highlights = smoothstep(0.85, 1.0, density);
            color += highlights * vec3(0.9, 0.95, 1.0) * 0.3;
            
            float alpha = density * alphaScale * 0.85;
            alpha = clamp(alpha, 0.0, 1.0);
            
            return vec4(color, alpha) * vcolor;
        }
    ]])
    end

    self.nebulaParams = {}

    local function randomColorComponent(min, max)
        return min + math.random() * (max - min)
    end

    local intensityBase = Constants.BACKGROUND.NEBULA.INTENSITY_BASE
    local intensityRange = Constants.BACKGROUND.NEBULA.INTENSITY_RANGE

    -- Random base offset for a single nebula
    self.nebulaParams.offsetBase = { math.random() * 10000, math.random() * 10000 }

    local noiseBase = Constants.BACKGROUND.NEBULA.NOISE_SCALE_BASE
    local noiseRange = Constants.BACKGROUND.NEBULA.NOISE_SCALE_RANGE
    self.nebulaParams.noiseScale = noiseBase + math.random() * noiseRange

    local flowAngle = math.random() * math.pi * 2

    local flowSpeed = Constants.BACKGROUND.NEBULA.FLOW_SPEED_BASE + math.random() * Constants.BACKGROUND.NEBULA.FLOW_SPEED_RANGE
    self.nebulaParams.flow = {
        math.cos(flowAngle) * flowSpeed,
        math.sin(flowAngle) * flowSpeed
    }

    local intensityA = intensityBase + math.random() * intensityRange
    local intensityB = intensityBase + math.random() * intensityRange
    local hueShift = math.random() * Constants.BACKGROUND.NEBULA.HUE_SHIFT_RANGE

    self.nebulaParams.colorA = {
        randomColorComponent(0.15, 0.75) * intensityA,
        randomColorComponent(0.10 + hueShift, 0.85) * intensityA,
        randomColorComponent(0.35, 0.95) * intensityA
    }

    self.nebulaParams.colorB = {
        randomColorComponent(0.4, 0.9) * intensityB,
        randomColorComponent(0.1, 0.6) * intensityB,
        randomColorComponent(0.15, 0.7) * intensityB
    }

    local alphaBase = Constants.BACKGROUND.NEBULA.ALPHA_SCALE_BASE
    local alphaRange = Constants.BACKGROUND.NEBULA.ALPHA_SCALE_RANGE
    self.nebulaParams.alphaScale = alphaBase + math.random() * alphaRange

    -- Single-layer parallax factor
    self.nebulaParams.parallax = 0.05

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

    if self.nebulaShader and self.nebulaParams then
        love.graphics.setShader(self.nebulaShader)
        love.graphics.setColor(1, 1, 1, 1)

        local baseOffset = self.nebulaParams.offsetBase or { 0, 0 }
        local parallax = self.nebulaParams.parallax or 0.05
        local offset_x = baseOffset[1] + abs_x * parallax
        local offset_y = baseOffset[2] + abs_y * parallax

        self.nebulaShader:send("time", self.time or 0)
        self.nebulaShader:send("offset", {offset_x, offset_y})
        self.nebulaShader:send("resolution", {sw, sh})
        self.nebulaShader:send("noiseScale", self.nebulaParams.noiseScale)
        self.nebulaShader:send("flow", self.nebulaParams.flow)
        self.nebulaShader:send("alphaScale", self.nebulaParams.alphaScale)
        self.nebulaShader:send("colorA", self.nebulaParams.colorA)
        self.nebulaShader:send("colorB", self.nebulaParams.colorB)

        love.graphics.rectangle("fill", 0, 0, sw, sh)
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