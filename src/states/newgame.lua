---@diagnostic disable: undefined-global
local Gamestate = require "hump.gamestate"
local Theme = require "src.ui.theme"
local Config = require "src.config"
local PlayState = require "src.states.play"

local function pointInRect(x, y, rect)
    return x >= rect.x and x <= rect.x + rect.w and y >= rect.y and y <= rect.y + rect.h
end

local function generateRandomSeed()
    local n = math.random(100000, 999999999)
    return tostring(n)
end

local function stringToSeed(s)
    local h = 0
    for i = 1, #s do
        h = (h * 31 + s:byte(i)) % 2147483647
    end
    if h == 0 then
        h = 1
    end
    return h
end

local settingsFileName = "world_settings.txt"
local lastWorldName
local lastWorldSeed

local NewGameState = {}

function NewGameState:enter()
    self.fontTitle = Theme.getFont("button")
    self.fontLabel = Theme.getFont("button")
    self.fontButton = Theme.getFont("button")

    if not lastWorldName or not lastWorldSeed then
        if love.filesystem and love.filesystem.getInfo then
            local info = love.filesystem.getInfo(settingsFileName)
            if info then
                local ok, data = pcall(love.filesystem.read, settingsFileName)
                if ok and data then
                    local savedName, savedSeed = data:match("([^\n]+)\n([^\n]+)")
                    if savedName and savedSeed then
                        lastWorldName = savedName
                        lastWorldSeed = savedSeed
                    end
                end
            end
        end
    end

    self.worldName = lastWorldName or "New World"
    self.seedString = lastWorldSeed or generateRandomSeed()
    self.activeField = "name"

    self.buttons = {
        {
            label = "START",
            action = function()
                self:startGame("SINGLE")
            end,
        },
        {
            label = "RANDOM SEED",
            action = function()
                self.seedString = generateRandomSeed()
            end,
        },
        {
            label = "BACK",
            action = function()
                local MenuState = require("src.states.menu")
                Gamestate.switch(MenuState)
            end,
        },
    }

    self.buttonRects = {}
    self.hoveredButton = nil
    self.activeButton = nil
    self.mouseWasDown = false
end

function NewGameState:updateButtonLayout()
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
    local centerY = sh * 0.75
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

function NewGameState:update(dt)
    self:updateButtonLayout()

    local mouseX, mouseY = love.mouse.getPosition()
    local isDown = love.mouse.isDown(1)

    if isDown and not self.mouseWasDown then
        if self.nameRect and pointInRect(mouseX, mouseY, self.nameRect) then
            self.activeField = "name"
        elseif self.seedRect and pointInRect(mouseX, mouseY, self.seedRect) then
            self.activeField = "seed"
        end
    end

    self.hoveredButton = nil
    for index, rect in ipairs(self.buttonRects) do
        if pointInRect(mouseX, mouseY, rect) then
            self.hoveredButton = index
            break
        end
    end

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

function NewGameState:draw()
    local sw, sh = love.graphics.getDimensions()
    love.graphics.clear(0, 0, 0, 1)

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(self.fontTitle)
    love.graphics.printf("NEW GAME", 0, sh * 0.12, sw, "center")

    local labelFont = self.fontLabel
    love.graphics.setFont(labelFont)
    local shapes = Theme.shapes

    local fieldWidth = 360
    local fieldHeight = 36
    local centerX = sw * 0.5
    local firstY = sh * 0.32
    local secondY = firstY + fieldHeight + 28

    local fieldX = centerX - fieldWidth * 0.5
    self.nameRect = { x = fieldX, y = firstY, w = fieldWidth, h = fieldHeight }
    self.seedRect = { x = fieldX, y = secondY, w = fieldWidth, h = fieldHeight }

    local function drawField(label, value, rect, isActive)
        local labelY = rect.y - fieldHeight * 0.9
        love.graphics.setColor(Theme.colors.textMuted)
        love.graphics.printf(label, rect.x, labelY, rect.w, "left")

        local state = isActive and "active" or "default"
        local fillColor, outlineColor = Theme.getButtonColors(state)

        love.graphics.setColor(fillColor)
        love.graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, shapes.buttonRounding, shapes.buttonRounding)

        love.graphics.setColor(outlineColor)
        love.graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h, shapes.buttonRounding, shapes.buttonRounding)

        local textColor = Theme.getButtonTextColor(state)
        love.graphics.setColor(textColor)
        local padding = 10
        local textX = rect.x + padding
        local textY = rect.y + (rect.h - labelFont:getHeight()) * 0.5
        love.graphics.printf(value or "", textX, textY, rect.w - padding * 2, "left")

        if isActive then
            local textWidth = labelFont:getWidth(value or "")
            local caretX = textX + textWidth + 2
            local caretY = rect.y + 6
            love.graphics.rectangle("fill", caretX, caretY, 2, rect.h - 12)
        end
    end

    drawField("WORLD NAME", self.worldName, self.nameRect, self.activeField == "name")
    drawField("SEED", self.seedString, self.seedRect, self.activeField == "seed")

    self:updateButtonLayout()

    love.graphics.setFont(self.fontButton)
    local textHeight = self.fontButton:getHeight()
    love.graphics.setLineWidth(Theme.shapes.outlineWidth or 1)

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
            love.graphics.printf(button.label, rect.x, rect.y + (rect.h - textHeight) * 0.5, rect.w, "center")
        end
    end

    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

function NewGameState:startGame(role)
    local name = (self.worldName or ""):match("^%s*(.-)%s*$")
    if name == "" then
        name = "New World"
    end

    local seedString = self.seedString
    if not seedString or seedString == "" then
        seedString = generateRandomSeed()
    end

    self.worldName = name
    self.seedString = seedString

    local numericSeed = stringToSeed(seedString)

    Config.UNIVERSE_NAME = name
    Config.UNIVERSE_SEED = numericSeed
    Config.UNIVERSE_SEED_STRING = seedString

    lastWorldName = name
    lastWorldSeed = seedString

    if love.filesystem and love.filesystem.write then
        local ok, err = pcall(love.filesystem.write, settingsFileName, name .. "\n" .. seedString)
        if not ok then
            print("NewGameState: failed to save world settings: " .. tostring(err))
        end
    end

    Gamestate.switch(PlayState, role or "SINGLE")
end

function NewGameState:keypressed(key)
    if key == "escape" then
        local MenuState = require("src.states.menu")
        Gamestate.switch(MenuState)
        return
    end

    if key == "tab" or key == "up" or key == "down" then
        if self.activeField == "name" then
            self.activeField = "seed"
        else
            self.activeField = "name"
        end
        return
    end

    if key == "backspace" then
        if self.activeField == "name" then
            self.worldName = (self.worldName or ""):sub(1, #(self.worldName or "") - 1)
        elseif self.activeField == "seed" then
            self.seedString = (self.seedString or ""):sub(1, #(self.seedString or "") - 1)
        end
        return
    end

    if key == "return" or key == "kpenter" then
        self:startGame("SINGLE")
        return
    end
end

function NewGameState:textinput(t)
    if self.activeField == "name" then
        self.worldName = (self.worldName or "") .. t
    elseif self.activeField == "seed" then
        self.seedString = (self.seedString or "") .. t
    end
end

return NewGameState
