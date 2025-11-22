---@diagnostic disable: undefined-global

-- Join Game state: allows the player to enter an IP/port before connecting
-- as a CLIENT. It also remembers the last used server and exposes a hook
-- for future LAN auto-discovery / scanning.

local Gamestate  = require "hump.gamestate"
local Theme      = require "src.ui.theme"
local Config     = require "src.config"

-- Simple rectangle hit test used for button interaction
local function pointInRect(x, y, rect)
    return x >= rect.x and x <= rect.x + rect.w and y >= rect.y and y <= rect.y + rect.h
end

-- File used to remember the last server IP/port between sessions.
-- This lives in Love2D's save directory, not in the project tree.
local settingsFileName = "join_settings.txt"

-- Cached last-used values kept in memory so we do not hit the filesystem
-- every time the state is entered.
local lastIP
local lastPort

local JoinState = {}

-- Initialize the join screen: background, fonts, input fields, and buttons.
function JoinState:enter(prev)
    -- Background is a simple solid color; starfield is reserved for gameplay.

    -- Fonts for title, labels, and buttons.
    self.fontTitle  = Theme.getFont("title")
    self.fontLabel  = Theme.getFont("button")
    self.fontButton = Theme.getFont("button")

    -- Lazy-load saved settings from disk once per run.
    if not lastIP or not lastPort then
        if love.filesystem and love.filesystem.getInfo then
            local info = love.filesystem.getInfo(settingsFileName)
            if info then
                local ok, data = pcall(love.filesystem.read, settingsFileName)
                if ok and data then
                    local savedIP, savedPort = data:match("([^\n]+)\n([^\n]+)")
                    if savedIP and savedPort then
                        lastIP = savedIP
                        lastPort = savedPort
                    end
                end
            end
        end
    end

    -- Starting values for inputs: last-used if available, otherwise defaults
    -- from the Config module.
    self.ip = lastIP or Config.SERVER_HOST or "localhost"
    self.port = tostring(lastPort or Config.PORT or 12345)

    -- Track which field is currently active for keyboard input.
    self.activeField = "ip" -- 'ip' or 'port'

    -- Buttons for the bottom of the screen.
    self.buttons = {
        {
            label = "CONNECT",
            action = function()
                self:connect()
            end,
        },
        {
            label = "SCAN",
            action = function()
                self:startScan()
            end,
        },
        {
            label = "BACK",
            action = function()
                self:goBack()
            end,
        },
    }

    self.buttonRects = {}
    self.hoveredButton = nil
    self.activeButton = nil
    self.mouseWasDown = false

    -- Text displayed near the bottom for feedback (errors / status / scan info).
    self.statusMessage = ""
    self.scanInProgress = false
end

-- Per-frame update: animate background and handle button mouse interaction.
function JoinState:update(dt)
    -- Rebuild button rectangles based on current window size.
    self:updateButtonLayout()

    local mouseX, mouseY = love.mouse.getPosition()
    local isDown = love.mouse.isDown(1)

    -- Allow clicking directly into the IP / Port fields to change focus.
    if isDown and not self.mouseWasDown then
        if self.ipRect and pointInRect(mouseX, mouseY, self.ipRect) then
            self.activeField = "ip"
        elseif self.portRect and pointInRect(mouseX, mouseY, self.portRect) then
            self.activeField = "port"
        end
    end

    -- Hover detection for the bottom buttons.
    self.hoveredButton = nil
    for index, rect in ipairs(self.buttonRects) do
        if pointInRect(mouseX, mouseY, rect) then
            self.hoveredButton = index
            break
        end
    end

    -- Simple mouse press / release handling to trigger button actions.

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

-- Layout the button rectangles near the bottom of the screen.
function JoinState:updateButtonLayout()
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

    -- Push buttons down a bit so they sit below the input fields.
    local baseY = sh * 0.65
    local startY = baseY - totalHeight * 0.5

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

-- Render background, title, IP/port fields, buttons, and status text.
function JoinState:draw()
    local sw, sh = love.graphics.getDimensions()

    -- 1. Clear to a simple background color (no starfield on this screen)
    local bg = Theme.getBackgroundColor()
    love.graphics.clear(bg[1], bg[2], bg[3], bg[4])

    -- 2. Title
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(self.fontTitle)
    love.graphics.printf("JOIN GAME", 0, sh * 0.08, sw, "center")

    -- 3. Input fields for IP and Port
    local labelFont = self.fontLabel
    love.graphics.setFont(labelFont)
    local shapes = Theme.shapes

    local fieldWidth = 360
    local fieldHeight = 36
    local centerX = sw * 0.5
    local firstY = sh * 0.32
    local secondY = firstY + fieldHeight + 28

    -- Store the input rectangles so we can detect clicks and move focus.
    local fieldX = centerX - fieldWidth * 0.5
    self.ipRect = { x = fieldX, y = firstY,  w = fieldWidth, h = fieldHeight }
    self.portRect = { x = fieldX, y = secondY, w = fieldWidth, h = fieldHeight }

    -- Small helper for drawing a labeled input field.
    local function drawField(label, value, y, isActive)
        local labelY = y - fieldHeight * 0.9
        love.graphics.setColor(Theme.colors.textMuted)
        love.graphics.printf(label, centerX - fieldWidth * 0.5, labelY, fieldWidth, "left")

        local state = isActive and "active" or "default"
        local fillColor, outlineColor = Theme.getButtonColors(state)

        love.graphics.setColor(fillColor)
        love.graphics.rectangle("fill", centerX - fieldWidth * 0.5, y, fieldWidth, fieldHeight, shapes.buttonRounding, shapes.buttonRounding)

        love.graphics.setColor(outlineColor)
        love.graphics.rectangle("line", centerX - fieldWidth * 0.5, y, fieldWidth, fieldHeight, shapes.buttonRounding, shapes.buttonRounding)

        local textColor = Theme.getButtonTextColor(state)
        love.graphics.setColor(textColor)
        local padding = 10
        local textX = fieldX + padding
        local textY = y + (fieldHeight - labelFont:getHeight()) * 0.5
        love.graphics.printf(value, textX, textY, fieldWidth - padding * 2, "left")

        -- Draw a simple caret when this field is active so the player
        -- can clearly see where they are typing.
        if isActive then
            local textWidth = labelFont:getWidth(value)
            local caretX = textX + textWidth + 2
            local caretY = y + 6
            love.graphics.rectangle("fill", caretX, caretY, 2, fieldHeight - 12)
        end
    end

    drawField("SERVER IP", self.ip, firstY, self.activeField == "ip")
    drawField("PORT", self.port, secondY, self.activeField == "port")

    -- 4. Buttons (Connect / Scan / Back)
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

    -- 5. Status / error text
    if self.statusMessage and self.statusMessage ~= "" then
        love.graphics.setFont(self.fontLabel)
        love.graphics.setColor(Theme.colors.textMuted)
        love.graphics.printf(self.statusMessage, 0, sh * 0.9, sw, "center")
    end
end

-- Keyboard control for field focus, editing, and quick actions.
function JoinState:keypressed(key)
    -- Escape returns to the main menu.
    if key == "escape" then
        self:goBack()
        return
    end

    -- Tab / Up / Down toggle which input field is active.
    if key == "tab" or key == "up" or key == "down" then
        if self.activeField == "ip" then
            self.activeField = "port"
        else
            self.activeField = "ip"
        end
        return
    end

    -- Backspace deletes the last character in the active field.
    if key == "backspace" then
        if self.activeField == "ip" then
            self.ip = self.ip:sub(1, #self.ip - 1)
        elseif self.activeField == "port" then
            self.port = self.port:sub(1, #self.port - 1)
        end
        return
    end

    -- Enter attempts to connect using the current IP/port.
    if key == "return" or key == "kpenter" then
        self:connect()
        return
    end
end

-- Receive text characters from Love2D and append to the active input field.
function JoinState:textinput(t)
    if self.activeField == "ip" then
        -- Allow letters, digits, dots, colons, and dashes so both
        -- hostnames (e.g. "localhost") and IPs are supported.
        if t:match("[%w%.:%-]") then
            self.ip = self.ip .. t
        end
    elseif self.activeField == "port" then
        -- Ports are numeric only.
        if t:match("%d") then
            self.port = self.port .. t
        end
    end
end

-- Attempt to connect as a CLIENT using the supplied IP and port.
-- This updates Config.SERVER_HOST / Config.PORT before switching
-- into PlayState with role = "CLIENT".
function JoinState:connect()
    if not Config.NETWORK_AVAILABLE then
        self.statusMessage = "Networking is not available (ENet not found)."
        return
    end

    local host = (self.ip or ""):match("^%s*(.-)%s*$")
    local portNumber = tonumber(self.port)

    if not host or host == "" then
        self.statusMessage = "Please enter a server IP or hostname."
        return
    end

    if not portNumber then
        self.statusMessage = "Port must be a number."
        return
    end

    -- Push the chosen settings back into the shared Config table so that
    -- the Network system uses them when creating the ENet socket.
    Config.SERVER_HOST = host
    Config.PORT = portNumber

    -- Remember these values for this run.
    lastIP = host
    lastPort = tostring(portNumber)

    -- Optionally persist them via Love2D's save system so they survive
    -- between runs. Errors are printed but do not break the game.
    if love.filesystem and love.filesystem.write then
        local ok, err = pcall(love.filesystem.write, settingsFileName, host .. "\n" .. tostring(portNumber))
        if not ok then
            print("JoinState: failed to save server settings: " .. tostring(err))
        end
    end

    self.statusMessage = "Connecting to " .. host .. ":" .. tostring(portNumber) .. " ..."

    -- Switch into the main PlayState as a CLIENT. PlayState will hand off
    -- to the Network systems which will use the updated Config values.
    local PlayState = require "src.states.play"
    Gamestate.switch(PlayState, "CLIENT")
end

-- Placeholder hook for future LAN auto-scan / discovery.
-- Right now this simply reports that the feature is not implemented yet.
-- To implement real discovery, you could use LuaSocket or ENet to send a
-- broadcast/announcement packet and have hosts reply on a known port.
function JoinState:startScan()
    if not Config.SOCKET_AVAILABLE then
        self.statusMessage = "Auto-scan not available: LuaSocket is not present."
        return
    end

    self.statusMessage = "Auto-scan placeholder: implement LAN discovery here."
end

-- Return to the main menu state.
function JoinState:goBack()
    local MenuState = require "src.states.menu"
    Gamestate.switch(MenuState)
end

return JoinState
