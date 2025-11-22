local Theme = require "src.ui.theme"
local Config = require "src.config"

local HUD = {}

function HUD.draw(world)
    local sw, sh = love.graphics.getDimensions()
    
    -- Find the player entity (Pilot -> Ship)
    local ship = nil
    for _, e in ipairs(world:getEntities()) do
        if e.pilot and e.controlling and e.controlling.entity then
            ship = e.controlling.entity
            break
        end
    end

    -- Setup fonts
    local fontBold = Theme.getFont("header") -- slightly larger/bold if available, or just use default
    local fontRegular = Theme.getFont("default")
    
    -- --- TOP LEFT PANEL ---
    local panelX = 20
    local panelY = 20
    local barWidth = 200
    local barHeight = 16
    local spacing = 8
    
    -- Helper to draw a bar
    local function drawBar(x, y, width, height, current, max, colorFill, colorBg, label)
        local pct = math.max(0, math.min(1, current / max))
        
        -- Background
        love.graphics.setColor(colorBg)
        love.graphics.rectangle("fill", x, y, width, height, 4, 4)
        
        -- Fill
        love.graphics.setColor(colorFill)
        love.graphics.rectangle("fill", x, y, width * pct, height, 4, 4)
        
        -- Border (Optional, maybe just use the background as the container)
        -- love.graphics.setColor(0,0,0,0.5)
        -- love.graphics.rectangle("line", x, y, width, height, 4, 4)
        
        -- Label / Text
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setFont(fontRegular)
        local text = string.format("%s: %d/%d", label, math.floor(current), math.floor(max))
        love.graphics.print(text, x + 4, y + (height - fontRegular:getHeight())/2)
    end

    if ship then
        -- 1. Shield Bar
        if ship.shield then
            drawBar(panelX, panelY, barWidth, barHeight, ship.shield.current, ship.shield.max, 
                {0.2, 0.6, 1, 0.9}, {0.1, 0.2, 0.3, 0.5}, "SHIELD")
            panelY = panelY + barHeight + spacing
        end
        
        -- 2. Hull Bar
        if ship.hull then
            drawBar(panelX, panelY, barWidth, barHeight, ship.hull.current, ship.hull.max, 
                {0.2, 0.8, 0.2, 0.9}, {0.1, 0.3, 0.1, 0.5}, "HULL")
            panelY = panelY + barHeight + spacing
        end
        
        -- 3. Sector / Pos Info
        if ship.sector and ship.transform then
            love.graphics.setColor(1, 1, 1, 0.8)
            love.graphics.setFont(fontRegular)
            
            local sectorText = string.format("SECTOR [%d, %d]", ship.sector.x, ship.sector.y)
            love.graphics.print(sectorText, panelX, panelY)
            panelY = panelY + fontRegular:getHeight() + 2
            
            local posText = string.format("POS %.0f, %.0f", ship.transform.x, ship.transform.y)
            love.graphics.print(posText, panelX, panelY)
            panelY = panelY + fontRegular:getHeight() + spacing
        end

        -- 4. Velocity / Speed
        if ship.physics and ship.physics.body then
            local vx, vy = ship.physics.body:getLinearVelocity()
            local velText = string.format("VEL %.1f, %.1f", vx, vy)
            love.graphics.print(velText, panelX, panelY)
            panelY = panelY + fontRegular:getHeight() + 2

            local speed = math.sqrt(vx * vx + vy * vy)
            local speedText = string.format("SPEED %.0f", speed)
            love.graphics.print(speedText, panelX, panelY)
        end
    else
        -- No ship found (maybe dead or spectating)
        love.graphics.setColor(1, 0.2, 0.2, 1)
        love.graphics.print("NO SIGNAL", panelX, panelY)
    end

    -- FPS Counter (Top Right)
    love.graphics.setColor(0.2, 1.0, 0.2, 1.0)
    love.graphics.print("FPS: " .. love.timer.getFPS(), sw - 60, 10)
end

return HUD
