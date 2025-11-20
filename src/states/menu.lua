---@diagnostic disable: undefined-global

local Gamestate = require "hump.gamestate"
local Utils     = require "src.utils"
local Theme     = require "src.ui.theme"

local AuroraShaderSource = [[
extern number time;
extern vec2 resolution;

float layered_sin(vec2 uv, float speed, float scale, float offset)
{
    return sin(uv.x * scale + time * speed + offset);
}

vec3 aurora_color(float t)
{
    vec3 c1 = vec3(0.05, 0.6, 0.9);
    vec3 c2 = vec3(0.6, 0.2, 0.85);
    vec3 c3 = vec3(0.1, 0.9, 0.6);
    vec3 mixed = mix(c1, c2, smoothstep(0.0, 1.0, t));
    return mix(mixed, c3, 0.35 + 0.25 * sin(time * 0.4 + t * 3.14159265));
}

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 pixel_coords)
{
    vec4 tex = Texel(texture, texture_coords) * color;
    if (tex.a <= 0.001) {
        return tex;
    }

    vec2 uv = pixel_coords / resolution.xy;
    uv.y = 1.0 - uv.y;

    float waveA = layered_sin(uv, 0.3, 6.0, 0.0);
    float waveB = layered_sin(uv.yx, -0.45, 9.5, 1.5);
    float waveC = layered_sin(uv, 0.8, 3.5, 3.2);

    float band = 0.6 + 0.2 * waveA + 0.15 * waveB;
    float shimmer = 0.5 + 0.5 * sin(time * 1.2 + uv.y * 12.0 + waveC * 1.5);
    float intensity = clamp(band * shimmer, 0.1, 1.0);

    vec3 glow = aurora_color(uv.x + waveA * 0.1) * intensity;
    vec3 base = tex.rgb * 0.25;

    return vec4(glow + base, tex.a);
}
]]

local function pointInRect(x, y, rect)
    return x >= rect.x and x <= rect.x + rect.w and y >= rect.y and y <= rect.y + rect.h
end

local MenuState = {}

function MenuState:enter()

    -- Initialize Starfield if not present
    if not self.stars then
        local sw, sh = love.graphics.getDimensions()
        self.stars = Utils.generate_starfield({
            width = sw,
            height = sh,
            scale_density = true
        })
        self.starfieldBounds = {w = sw, h = sh}
        self.starMesh = Utils.build_star_mesh(self.stars)
    end

    -- Fonts
    self.fontTitle = Theme.getFont("title")
    self.fontButton = Theme.getFont("button")

    if not self.auroraShader then
        self.auroraShader = love.graphics.newShader(AuroraShaderSource)
        self.auroraTime = 0
    end

    if self.auroraShader then
        local sw, sh = love.graphics.getDimensions()
        self.auroraShader:send("time", self.auroraTime or 0)
        self.auroraShader:send("resolution", {sw, sh})
    end

    self.buttons = {
        {
            label = "NEW GAME",
            action = function()
                local PlayState = require("src.states.play")
                Gamestate.switch(PlayState, "SINGLE")
            end,
        },
        {
            label = "JOIN GAME",
            action = function()
                local PlayState = require("src.states.play")
                Gamestate.switch(PlayState, "CLIENT")
            end,
        },
        {
            label = "QUIT",
            action = function()
                love.event.quit()
            end,
        },
    }

    self.buttonRects = {}
    self.hoveredButton = nil
    self.activeButton = nil
    self.mouseWasDown = false
end

function MenuState:update(dt)
    local sw = love.graphics.getWidth()
    local sh = love.graphics.getHeight()

    -- Regenerate starfield if window size has changed significantly
    if not self.starfieldBounds or self.starfieldBounds.w ~= sw or self.starfieldBounds.h ~= sh then
        self.stars = Utils.generate_starfield({
            width = sw,
            height = sh,
            scale_density = true
        })
        self.starfieldBounds = {w = sw, h = sh}
        self.starMesh = Utils.build_star_mesh(self.stars)
    end

    -- 1. Update Starfield (subtle parallax drift)
    for _, star in ipairs(self.stars) do
        -- Drift left with layer-based speed (scaled by width for consistency)
        star.x = star.x - (star.speed * sw * 12) * dt

        local wrap_offset = (star.glow_radius or star.size or 1) * 2
        if star.x < -wrap_offset then
            star.x = sw + wrap_offset
            star.y = math.random(0, sh)
        end
    end

    if self.auroraShader then
        self.auroraTime = (self.auroraTime or 0) + dt
        self.auroraShader:send("time", self.auroraTime)
        self.auroraShader:send("resolution", {sw, sh})
    end

    self:updateButtonLayout()

    local mouseX, mouseY = love.mouse.getPosition()
    self.hoveredButton = nil
    for index, rect in ipairs(self.buttonRects) do
        if pointInRect(mouseX, mouseY, rect) then
            self.hoveredButton = index
            break
        end
    end

    local isDown = love.mouse.isDown(1)

    if isDown and not self.mouseWasDown then
        self.activeButton = self.hoveredButton
    elseif not isDown and self.mouseWasDown then
        if self.activeButton ~= nil and self.hoveredButton == self.activeButton then
            local button = self.buttons[self.activeButton]
            if button and button.action then
                button.action()
            end
        end
        self.activeButton = nil
    end

    if not isDown then
        self.activeButton = nil
    end

    self.mouseWasDown = isDown
end

function MenuState:updateButtonLayout()
    if not self.buttons then
        return
    end

    self.buttonRects = self.buttonRects or {}
    for index = 1, #self.buttonRects do
        self.buttonRects[index] = nil
    end

    local sw, sh = love.graphics.getDimensions()
    local spacing = Theme.spacing
    local totalHeight = #self.buttons * spacing.buttonHeight + (#self.buttons - 1) * spacing.buttonSpacing
    local startX = (sw - spacing.buttonWidth) * 0.5
    local centerY = sh * 0.5 + spacing.menuVerticalOffset
    local startY = centerY - totalHeight * 0.5

    for index = 1, #self.buttons do
        local y = startY + (index - 1) * (spacing.buttonHeight + spacing.buttonSpacing)
        self.buttonRects[index] = {
            x = startX,
            y = y,
            w = spacing.buttonWidth,
            h = spacing.buttonHeight,
        }
    end
end

function MenuState:draw()
    local sw, sh = love.graphics.getDimensions()

    -- 1. Draw Background (Deep Space)
    local bg = Theme.getBackgroundColor()
    love.graphics.clear(bg[1], bg[2], bg[3], bg[4] or 1)

    -- 2. Draw Stars with subtle glows and color variance
    local vertices = {}
    for i, star in ipairs(self.stars) do
        local x = math.floor(star.x) + 0.5
        local y = math.floor(star.y) + 0.5

        if star.glow_radius then
            love.graphics.setColor(star.color[1], star.color[2], star.color[3], star.glow_alpha)
            love.graphics.circle("fill", x, y, star.glow_radius)
        end

        local r, g, b = star.color[1], star.color[2], star.color[3]
        local a = star.alpha or 1
        vertices[i] = {x, y, r, g, b, a}
    end

    if self.starMesh and #vertices > 0 then
        self.starMesh:setVertices(vertices)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setPointSize(1.5)
        love.graphics.draw(self.starMesh)
    end

    -- 3. Draw Title "NOVUS"
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(self.fontTitle)
    if self.auroraShader then
        love.graphics.setShader(self.auroraShader)
    end
    -- Draw title slightly above center
    love.graphics.printf("NOVUS", 0, sh * 0.08, sw, "center")
    love.graphics.setShader()

    -- 4. Draw Menu Buttons (custom UI)
    self:updateButtonLayout()

    love.graphics.setFont(self.fontButton)
    local shapes = Theme.shapes
    love.graphics.setLineWidth(shapes.outlineWidth or 1)
    local textHeight = self.fontButton:getHeight()

    for index, button in ipairs(self.buttons) do
        local rect = self.buttonRects[index]
        if rect then
            local hovered = self.hoveredButton == index
            local active = love.mouse.isDown(1) and self.activeButton == index

            local state = "default"
            if active then
                state = "active"
            elseif hovered then
                state = "hover"
            end

            local fillColor, outlineColor = Theme.getButtonColors(state)
            local textColor = Theme.getButtonTextColor(state)

            love.graphics.setColor(fillColor)
            love.graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, shapes.buttonRounding, shapes.buttonRounding)

            love.graphics.setColor(outlineColor)
            love.graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h, shapes.buttonRounding, shapes.buttonRounding)

            love.graphics.setColor(textColor)
            love.graphics.printf(
                button.label,
                rect.x,
                rect.y + (rect.h - textHeight) * 0.5,
                rect.w,
                "center"
            )
        end
    end

    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

-- Keep keyboard shortcuts as a backup/convenience
function MenuState:keypressed(key)
    local PlayState = require("src.states.play")
    if key == 'n' then Gamestate.switch(PlayState, "SINGLE")
    elseif key == 'j' then Gamestate.switch(PlayState, "CLIENT") 
    elseif key == 'escape' then love.event.quit() end
end

return MenuState