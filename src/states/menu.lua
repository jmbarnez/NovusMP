---@diagnostic disable: undefined-global

local Gamestate = require "hump.gamestate"
local Utils     = require "src.utils"
local Theme     = require "src.ui.theme"
local Background = require "src.background"

-- Simplified Shader just for the Title Text (Aurora Effect on Text)
local TitleShaderSource = [[
extern number time;
vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 pixel_coords) {
    vec4 tex = Texel(texture, texture_coords) * color;
    if (tex.a <= 0.001) return tex;
    float shimmer = 0.5 + 0.5 * sin(time * 2.0 + pixel_coords.x * 0.05);
    return tex * vec4(1.0, 0.9 + 0.1*shimmer, 1.0, 1.0);
}
]]

local function pointInRect(x, y, rect)
    return x >= rect.x and x <= rect.x + rect.w and y >= rect.y and y <= rect.y + rect.h
end

local MenuState = {}

function MenuState:enter()
    -- Initialize Background System
    self.background = Background.new()
    self.menuScroll = 0 -- Used to animate background in menu

    -- Fonts
    self.fontTitle = Theme.getFont("title")
    self.fontButton = Theme.getFont("button")

    if not self.titleShader then
        self.titleShader = love.graphics.newShader(TitleShaderSource)
        self.shaderTime = 0
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
    
    -- Update Background
    if self.background then
        self.background:update(dt)
        -- Scroll the menu background slowly to the right
        self.menuScroll = self.menuScroll + (dt * 30) 
    end

    if self.titleShader then
        self.shaderTime = self.shaderTime + dt
        self.titleShader:send("time", self.shaderTime)
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

    -- 1. Draw Background (New System)
    -- We pass menuScroll as the 'camera x' to simulate movement
    if self.background then
        self.background:draw(self.menuScroll, 0, 0, 0)
    end

    -- 2. Draw Title "NOVUS"
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(self.fontTitle)
    if self.titleShader then
        love.graphics.setShader(self.titleShader)
    end
    love.graphics.printf("NOVUS", 0, sh * 0.08, sw, "center")
    love.graphics.setShader()

    -- 3. Draw Menu Buttons (custom UI)
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

function MenuState:keypressed(key)
    local PlayState = require("src.states.play")
    if key == 'n' then Gamestate.switch(PlayState, "SINGLE")
    elseif key == 'h' then Gamestate.switch(PlayState, "HOST")
    elseif key == 'j' then Gamestate.switch(PlayState, "CLIENT") 
    elseif key == 'escape' then love.event.quit() end
end

return MenuState