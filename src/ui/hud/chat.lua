local Theme = require "src.ui.theme"
local utf8 = require "utf8"

local Chat = {
    active = false,
    enabled = false,
    lines = {},
    inputBuffer = "",
    maxLines = 50,
    
    -- Layout
    x = 20,
    width = 600,
    height = 300,
    
    colors = {
        background = {0, 0, 0, 0.5},
        inputBackground = {0.1, 0.1, 0.1, 0.9},
        text = {1, 1, 1, 1},
        system = {1, 1, 0, 1},
        error = {1, 0.2, 0.2, 1},
        debug = {0.7, 0.7, 0.7, 1},
    }
}

function Chat.init()
    Chat.font = Theme.getFont("chat")
    Chat.lineHeight = Chat.font:getHeight() + 4
    
    -- Initial welcome message
    Chat.addMessage("Welcome to NovusMP!", "system")
    Chat.addMessage("Press ` (tilde) to chat.", "system")
end

function Chat.addMessage(text, type, timestamp)
    type = type or "text"
    local color = Chat.colors[type] or Chat.colors.text
    
    table.insert(Chat.lines, {
        text = text,
        color = color,
        timestamp = timestamp or os.time()
    })
    
    if #Chat.lines > Chat.maxLines then
        table.remove(Chat.lines, 1)
    end
end

-- Helper functions
function Chat.print(text) Chat.addMessage(tostring(text), "text") end
function Chat.system(text) Chat.addMessage(tostring(text), "system") end
function Chat.error(text) Chat.addMessage(tostring(text), "error") end
function Chat.debug(text) Chat.addMessage(tostring(text), "debug") end

function Chat.setSendHandler(fn)
    Chat.sendHandler = fn
end

function Chat.enable()
    Chat.enabled = true
end

function Chat.disable()
    Chat.enabled = false
    Chat.active = false
    Chat.inputBuffer = ""
end

function Chat.isEnabled()
    return Chat.enabled
end

function Chat.update(dt)
    if not Chat.enabled then return end
    -- Logic for fading or scrolling could go here
end

function Chat.draw()
    if not Chat.enabled then return end

    local screenH = love.graphics.getHeight()
    local bottom = screenH - 20
    
    -- If active, shift up to make room for input box
    local inputHeight = 30
    local listBottom = bottom - (Chat.active and inputHeight or 0)
    
    love.graphics.setFont(Chat.font)
    
    -- Draw messages (bottom-up)
    local count = 0
    for i = #Chat.lines, 1, -1 do
        local line = Chat.lines[i]
        local y = listBottom - (count + 1) * Chat.lineHeight
        
        -- Stop if we go above the allowed height
        if listBottom - y > Chat.height then break end
        
        local timePrefix = ""
        if line.timestamp then
            timePrefix = os.date("[%H:%M] ", line.timestamp)
        end
        local fullText = timePrefix .. line.text
        
        -- Text shadow for readability
        love.graphics.setColor(0, 0, 0, 0.8)
        love.graphics.print(fullText, Chat.x + 1, y + 1)
        
        love.graphics.setColor(line.color)
        love.graphics.print(fullText, Chat.x, y)
        
        count = count + 1
    end
    
    -- Draw input box if active
    if Chat.active then
        local inputY = bottom - inputHeight + 5
        
        love.graphics.setColor(Chat.colors.inputBackground)
        love.graphics.rectangle("fill", Chat.x, inputY, Chat.width, inputHeight - 5)
        
        love.graphics.setColor(Theme.colors.button.outline)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", Chat.x, inputY, Chat.width, inputHeight - 5)
        
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print("> " .. Chat.inputBuffer .. "|", Chat.x + 5, inputY + 2)
    end
    
    -- Reset color
    love.graphics.setColor(1, 1, 1, 1)
end

function Chat.keypressed(key)
    if not Chat.enabled then
        return false
    end

    -- Toggle chat with ` (tilde)
    if key == "`" then
        Chat.active = not Chat.active
        love.keyboard.setKeyRepeat(Chat.active)
        return true -- Always consume the toggle key
    end

    if Chat.active then
        if key == "return" or key == "kpenter" then
            -- Send message
            if #Chat.inputBuffer > 0 then
                local message = Chat.inputBuffer
                Chat.inputBuffer = ""
                if Chat.sendHandler then
                    Chat.sendHandler(message)
                else
                    Chat.addMessage("You: " .. message, "text")
                end
            end
            Chat.active = false
            love.keyboard.setKeyRepeat(false)
            return true
        elseif key == "escape" then
            Chat.active = false
            love.keyboard.setKeyRepeat(false)
            return true
        elseif key == "backspace" then
            local byteoffset = utf8.offset(Chat.inputBuffer, -1)
            if byteoffset then
                Chat.inputBuffer = string.sub(Chat.inputBuffer, 1, byteoffset - 1)
            end
            return true
        end
        
        -- Consume all keys when chat is active
        return true
    end
    
    return false
end

function Chat.textinput(t)
    if not Chat.enabled then
        return false
    end

    if Chat.active then
        Chat.inputBuffer = Chat.inputBuffer .. t
        return true
    end
    return false
end

return Chat
