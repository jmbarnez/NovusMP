local Theme = require "src.ui.theme"
local Config = require "src.config"
local StatusPanel = require "src.hud.status_panel"

local HUD = {}

function HUD.draw(world, player)
    local sw, sh = love.graphics.getDimensions()
    
    -- Draw status panel (top-left)
    StatusPanel.draw(player)

    -- FPS Counter (Top Right)
    love.graphics.setColor(0.2, 1.0, 0.2, 1.0)
    love.graphics.setFont(Theme.getFont("default"))
    love.graphics.print("FPS: " .. love.timer.getFPS(), sw - 60, 10)
end

return HUD
