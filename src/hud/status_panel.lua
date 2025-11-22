local Theme = require "src.ui.theme"

local StatusPanel = {}

-- Helper to draw a compact horizontal bar for the status panel
local function drawBar(x, y, width, height, current, max, colorFill, colorBg)
    local pct = 0
    if max and max > 0 then
        pct = math.max(0, math.min(1, (current or 0) / max))
    end

    love.graphics.setColor(colorBg)
    love.graphics.rectangle("fill", x, y, width, height, 0, 0)

    love.graphics.setColor(colorFill)
    love.graphics.rectangle("fill", x, y, width * pct, height, 0, 0)
end

-- Draw the status panel in the top-left, with level on the left and bars on the right
function StatusPanel.draw(player)
    if not player then
        return
    end

    -- Find the ship (if any)
    local ship = nil
    if player.controlling and player.controlling.entity then
        ship = player.controlling.entity
    end

    -- Panel positioning (top-left)
    local panelX = 20
    local panelY = 20
    local panelWidth = 260
    local panelHeight = 56

    local levelRadius = 16
    local levelCenterX = panelX + levelRadius + 4
    local levelCenterY = panelY + panelHeight / 2

    local barsX = levelCenterX + levelRadius + 16
    local barsY = panelY + panelHeight / 2 - 4
    local barWidth = panelWidth - (barsX - panelX) - 10
    local barHeight = 8

    local fontLevel = Theme.getFont("default")
    local fontLabel = Theme.getFont("chat")

    -- No background panel: render level + bar directly over the scene

    -- XP ring around level
    local levelComponent = (ship and ship.level) or player.level
    local xp = levelComponent and levelComponent.xp or 0
    local nextXp = levelComponent and levelComponent.next_level_xp or 1000
    local xpRatio = 0
    if nextXp > 0 then
        xpRatio = math.max(0, math.min(1, xp / nextXp))
    end

    local startAngle = -math.pi / 2
    local endAngle = startAngle + (2 * math.pi * xpRatio)

    love.graphics.setLineWidth(3)
    -- Background ring
    love.graphics.setColor(0.15, 0.15, 0.15, 0.9)
    love.graphics.arc("line", levelCenterX, levelCenterY, levelRadius, 0, 2 * math.pi)
    -- XP arc
    love.graphics.setColor(0.2, 0.7, 1.0, 1.0)
    love.graphics.arc("line", levelCenterX, levelCenterY, levelRadius, startAngle, endAngle)
    love.graphics.setLineWidth(1)

    -- Level text in the center (smaller font)
    love.graphics.setFont(fontLevel)
    love.graphics.setColor(Theme.colors.textPrimary)
    local levelValue = (levelComponent and levelComponent.current) or 1
    local levelText = tostring(levelValue)
    local textW = fontLevel:getWidth(levelText)
    local textH = fontLevel:getHeight()
    love.graphics.print(levelText, levelCenterX - textW / 2, levelCenterY - textH / 2)

    -- Sleek hybrid Shield/Hull bar
    love.graphics.setFont(fontLabel)
    
    local shieldCurrent = (ship and ship.shield and ship.shield.current) or 0
    local shieldMax = (ship and ship.shield and ship.shield.max) or 0
    local hullCurrent = (ship and ship.hull and ship.hull.current) or 0
    local hullMax = (ship and ship.hull and ship.hull.max) or 0
    
    local hullPct = 0
    if hullMax > 0 then
        hullPct = math.max(0, math.min(1, hullCurrent / hullMax))
    end

    local shieldPct = 0
    if shieldMax > 0 then
        shieldPct = math.max(0, math.min(1, shieldCurrent / shieldMax))
    end
    
    if hullPct > 0 or shieldPct > 0 then
        -- Subtle background
        love.graphics.setColor(0.05, 0.05, 0.05, 0.9)
        love.graphics.rectangle("fill", barsX, barsY, barWidth, barHeight, 0, 0)

        -- Hull portion (emerald green base)
        if hullPct > 0 then
            love.graphics.setColor(0.15, 0.85, 0.4, 1)
            love.graphics.rectangle("fill", barsX, barsY, barWidth * hullPct, barHeight, 0, 0)
        end

        -- Shield bar sitting directly on top of the hull bar (same band)
        if shieldPct > 0 then
            local shieldInset = 1
            local shieldHeight = math.max(2, barHeight - 2 * shieldInset)
            local shieldY = barsY + shieldInset
            love.graphics.setColor(0.2, 0.8, 1.0, 0.9)
            love.graphics.rectangle("fill", barsX + shieldInset, shieldY, (barWidth - 2 * shieldInset) * shieldPct, shieldHeight, 0, 0)
        end
    end
end

return StatusPanel
