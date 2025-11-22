-- src/game.lua
-- This is now just the entry point that registers events and starts the Menu.

local Gamestate     = require "hump.gamestate"
local Config        = require "src.config"
local MenuState     = require "src.states.menu"
local Lurker        = require "lurker"
local WeaponManager = require "src.managers.weapon_manager"

function love.load()
    WeaponManager.load_plugins()
    
    -- Start game in Menu
    Gamestate.switch(MenuState)
end

function love.update(dt)
    Lurker.update(dt)
    Gamestate.update(dt)
end

function love.draw()
    Gamestate.draw()
end

function love.keypressed(key, scancode, isrepeat)
    Gamestate.keypressed(key, scancode, isrepeat)
end

function love.textinput(t)
    Gamestate.textinput(t)
end

-- Forward other events to Gamestate
function love.keyreleased(key, scancode)
    Gamestate.keyreleased(key, scancode)
end

function love.mousepressed(x, y, button, istouch, presses)
    Gamestate.mousepressed(x, y, button, istouch, presses)
end

function love.mousereleased(x, y, button, istouch, presses)
    Gamestate.mousereleased(x, y, button, istouch, presses)
end

function love.wheelmoved(x, y)
    Gamestate.wheelmoved(x, y)
end

function love.resize(w, h)
    Gamestate.resize(w, h)
end

function love.focus(f)
    Gamestate.focus(f)
end

function love.quit()
    return Gamestate.quit()
end