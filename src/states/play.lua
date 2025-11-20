local Gamestate = require "hump.gamestate"
local baton     = require "baton"
local Camera    = require "hump.camera"
local Concord   = require "concord"
local Config    = require "src.config"
local Background = require "src.background"

-- Register Components
require "src.components"

-- Import Systems
local InputSystem   = require "src.systems.input"
local PhysicsSystem = require "src.systems.physics"
local Network       = require "src.systems.network"
local RenderSystem  = require "src.systems.render"

local PlayState = {}

function PlayState:enter(prev, role)
    self.role = role or "SINGLE"
    
    -- Initialize World
    self.world = Concord.world()
    
    -- Initialize Background System
    self.world.background = Background.new()

    -- Shared Context (Camera)
    local sw, sh = love.graphics.getDimensions()
    self.world.camera = Camera.new()
    
    if self.world.camera then
        self.world.camera:zoomTo(Config.CAMERA_DEFAULT_ZOOM)
    end
    
    -- Initialize Physics
    if self.world.physics_world then self.world.physics_world:destroy() end
    self.world.physics_world = love.physics.newWorld(0, 0, true)

    -- Initialize Controls
    self.world.controls = baton.new({
        controls = {
            left = {"key:left", "key:a"},
            right = {"key:right", "key:d"},
            thrust = {"key:up", "key:w"}
        }
    })

    -- Add Systems
    self.world:addSystems(
        InputSystem,
        PhysicsSystem,
        Network.Sync,
        Network.IO,
        RenderSystem
    )

    -- Initialize Network Role
    self.world:getSystem(Network.IO):setRole(self.role)

    -- === ENTITY SETUP ===
    local sx, sy = 0, 0
    if self.world.camera then self.world.camera:lookAt(sx, sy) end
    
    local body = love.physics.newBody(self.world.physics_world, sx, sy, "dynamic")
    body:setLinearDamping(Config.LINEAR_DAMPING)
    
    local shape = love.physics.newCircleShape(10)
    local fixture = love.physics.newFixture(body, shape, 1)
    fixture:setRestitution(0.2)
    
    local ship_color = (self.role == "CLIENT" and {0.2, 0.2, 1} or {0.2, 1, 0.2})

    local ship = Concord.entity(self.world)
    ship:give("transform", sx, sy, 0)
    ship:give("sector", 0, 0) 
    ship:give("physics", body, shape, fixture)
    ship:give("render", ship_color)
    ship:give("vehicle", Config.THRUST, Config.ROTATION_SPEED, Config.MAX_SPEED)

    local player = Concord.entity(self.world)
    player:give("pilot")             
    player:give("input")             
    player:give("controlling", ship) 
end

function PlayState:update(dt) 
    -- Update background shader times
    if self.world.background then
        self.world.background:update(dt)
    end
    self.world:emit("update", dt)
end

function PlayState:draw() 
    love.graphics.setBackgroundColor(0,0,0)
    self.world:emit("draw")
    
    -- UI Overlay
    love.graphics.setColor(1, 1, 1)
    local status_text = "Mode: " .. self.role
    if self.role == "SINGLE" then
        status_text = status_text .. " (Press 'H' to Host)"
    end
    love.graphics.print(status_text, 10, 70) 
end

function PlayState:keypressed(key)
    if key == 'h' and self.role == "SINGLE" then
        self.role = "HOST"
        self.world:getSystem(Network.IO):setRole("HOST")
    end
end

function PlayState:wheelmoved(_, y)
    if y == 0 then return end
    local camera = self.world and self.world.camera
    if not camera then return end

    local step = Config.CAMERA_ZOOM_STEP or 0.1
    local min_zoom = Config.CAMERA_MIN_ZOOM or 0.5
    local max_zoom = Config.CAMERA_MAX_ZOOM or 2.5

    local target = camera.scale + y * step
    if target < min_zoom then target = min_zoom end
    if target > max_zoom then target = max_zoom end

    camera:zoomTo(target)
end

return PlayState