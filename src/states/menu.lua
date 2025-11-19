local Gamestate = require "hump.gamestate"

local MenuState = {}

-- Simple Button UI Config
local BUTTON_WIDTH = 200
local BUTTON_HEIGHT = 50
local MARGIN = 20

function MenuState:init()
    self.buttons = {}
    self.fontTitle = love.graphics.newFont(48) -- Large font for Title
    self.fontButton = love.graphics.newFont(20) -- Medium font for Buttons
end

function MenuState:enter()
    local sw, sh = love.graphics.getDimensions()
    local cx = sw / 2
    local cy = sh / 2

    -- Define Buttons
    self.buttons = {
        {
            text = "NEW GAME",
            x = cx - BUTTON_WIDTH / 2,
            y = cy,
            w = BUTTON_WIDTH,
            h = BUTTON_HEIGHT,
            fn = function() 
                local PlayState = require("src.states.play")
                Gamestate.switch(PlayState, "SINGLE")
            end
        },
        {
            text = "JOIN GAME",
            x = cx - BUTTON_WIDTH / 2,
            y = cy + BUTTON_HEIGHT + MARGIN,
            w = BUTTON_WIDTH,
            h = BUTTON_HEIGHT,
            fn = function() 
                local PlayState = require("src.states.play")
                Gamestate.switch(PlayState, "CLIENT")
            end
        },
        {
            text = "QUIT",
            x = cx - BUTTON_WIDTH / 2,
            y = cy + (BUTTON_HEIGHT + MARGIN) * 2,
            w = BUTTON_WIDTH,
            h = BUTTON_HEIGHT,
            fn = function() love.event.quit() end
        }
    }
end

function MenuState:draw()
    local sw, sh = love.graphics.getDimensions()
    local mx, my = love.mouse.getPosition()
    
    -- Background
    love.graphics.setBackgroundColor(0.05, 0.05, 0.1)
    love.graphics.setColor(1, 1, 1)

    -- Draw Title "NOVUS"
    love.graphics.setFont(self.fontTitle)
    love.graphics.printf("NOVUS", 0, sh * 0.2, sw, "center")
    
    -- Draw Buttons
    love.graphics.setFont(self.fontButton)
    for _, btn in ipairs(self.buttons) do
        -- Check Hover
        local isHover = mx >= btn.x and mx <= btn.x + btn.w and my >= btn.y and my <= btn.y + btn.h
        
        if isHover then
            love.graphics.setColor(0.3, 0.7, 0.3) -- Bright Green Hover
        else
            love.graphics.setColor(0.2, 0.2, 0.2) -- Dark Gray Base
        end
        
        -- Button Body
        love.graphics.rectangle("fill", btn.x, btn.y, btn.w, btn.h, 5, 5) -- Rounded corners
        
        -- Button Border
        love.graphics.setColor(1, 1, 1)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", btn.x, btn.y, btn.w, btn.h, 5, 5)
        
        -- Button Text
        if isHover then love.graphics.setColor(1, 1, 1) else love.graphics.setColor(0.8, 0.8, 0.8) end
        local textH = self.fontButton:getHeight()
        -- Center text vertically and horizontally
        love.graphics.printf(btn.text, btn.x, btn.y + (btn.h - textH) / 2, btn.w, "center")
    end
    
    -- Restore default font size for other states/debug
    love.graphics.setFont(love.graphics.newFont(12))
end

function MenuState:mousepressed(x, y, button)
    if button == 1 then -- Left Click
        for _, btn in ipairs(self.buttons) do
            if x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h then
                btn.fn() -- Execute button action
            end
        end
    end
end

-- Keep Keyboard shortcuts for convenience
function MenuState:keypressed(key)
    local PlayState = require("src.states.play")
    if key == 'n' then Gamestate.switch(PlayState, "SINGLE")
    elseif key == 'j' then Gamestate.switch(PlayState, "CLIENT") 
    elseif key == 'escape' then love.event.quit() end
end

return MenuState