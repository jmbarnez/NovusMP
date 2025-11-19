-- src/game.lua
-- This is now just the entry point that registers events and starts the Menu.

local Gamestate = require "hump.gamestate"
local Config    = require "src.config"
local MenuState = require "src.states.menu"

if not Config.NETWORK_AVAILABLE then
    print("WARNING: library 'enet' not found. Networking disabled.")
end

function love.load()
    Gamestate.registerEvents()
    Gamestate.switch(MenuState)
end