local Theme = {}

-- Core palette for the custom UI / HUD library.
Theme.colors = {
    background = {0.01, 0.015, 0.035, 1.0},
    textPrimary = {1.0, 1.0, 1.0, 1.0},
    textMuted = {0.78, 0.8, 0.82, 1.0},
    button = {
        fill = {0.0, 0.0, 0.0, 0.05},
        fillHover = {0.0, 0.0, 0.0, 0.12},
        fillActive = {0.0, 0.0, 0.0, 0.18},
        outline = {1.0, 1.0, 1.0, 0.65},
        outlineHover = {1.0, 1.0, 1.0, 0.85},
        outlineActive = {1.0, 1.0, 1.0, 1.0},
    },
}

-- Shape and spacing tokens used by controls.
Theme.shapes = {
    buttonRounding = 0,
    outlineWidth = 1.5,
}

Theme.spacing = {
    buttonWidth = 200,
    buttonHeight = 40,
    buttonSpacing = 18,
    menuVerticalOffset = 62,
}

Theme.fonts = {
    title = {path = "assets/fonts/Orbitron-Regular.ttf", size = 128},
    button = {path = "assets/fonts/Orbitron-Regular.ttf", size = 20},
    chat = {path = "assets/fonts/Orbitron-Regular.ttf", size = 14},
    header = {path = "assets/fonts/Orbitron-Regular.ttf", size = 16},
    default = {path = "assets/fonts/Orbitron-Regular.ttf", size = 12},
}

local fontCache = {}

local function loadFont(def)
    if def == nil then
        return love.graphics.newFont(14)
    end

    local info = love.filesystem.getInfo(def.path)
    if info then
        return love.graphics.newFont(def.path, def.size)
    end

    return love.graphics.newFont(def.size)
end

---Retrieves and caches a named font defined in Theme.fonts.
---@param key string
---@return love.Font
function Theme.getFont(key)
    if not fontCache[key] then
        fontCache[key] = loadFont(Theme.fonts[key])
    end
    return fontCache[key]
end

---Returns the fill/outline colors for a button state.
---@param state 'default'|'hover'|'active'
---@return table fill
---@return table outline
function Theme.getButtonColors(state)
    local palette = Theme.colors.button
    if state == 'active' then
        return palette.fillActive, palette.outlineActive
    elseif state == 'hover' then
        return palette.fillHover, palette.outlineHover
    end
    return palette.fill, palette.outline
end

---Returns the primary text color adjusted for button state if desired.
---@param state 'default'|'hover'|'active'
---@return table
function Theme.getButtonTextColor(state)
    return Theme.colors.textPrimary
end

function Theme.getBackgroundColor()
    return Theme.colors.background
end

return Theme
