local Concord = require "concord"
local Config = require "src.config"

local ItemSpawners = {}

function ItemSpawners.spawn_stone(world, x, y, sector_x, sector_y)
    if not world then return end

    local item = Concord.entity(world)
    item:give("transform", x, y, math.random() * math.pi * 2)
    item:give("sector", sector_x or 0, sector_y or 0)
    
    -- Generate random polygon vertices
    local radius = 8
    local num_points = math.random(5, 7)
    local vertices = {}
    for i = 1, num_points do
        local angle = (i - 1) * (2 * math.pi / num_points)
        local r = radius * (0.7 + math.random() * 0.6) -- Random radius variation
        table.insert(vertices, r * math.cos(angle))
        table.insert(vertices, r * math.sin(angle))
    end

    -- Render as a small grey polygon
    item:give("render", {
        render_type = "item",
        color = {0.7, 0.7, 0.7, 1},
        shape = vertices -- Pass vertices to render component
    })
    
    item:give("item", "resource", "Stone", 1.0)
    
    -- Items should eventually disappear if not picked up
    item:give("lifetime", 60) 

    -- Physics for pickup (sensor)
    local body = love.physics.newBody(world.physics_world, x, y, "dynamic")
    body:setLinearDamping(1.0)
    body:setAngularDamping(1.0)
    
    local shape = love.physics.newPolygonShape(vertices)
    local fixture = love.physics.newFixture(body, shape, 0.5)
    fixture:setSensor(true) -- Items are sensors, ships fly through them
    fixture:setUserData(item)
    
    item:give("physics", body, shape, fixture)
    
    -- Give it a little random velocity
    local angle = math.random() * math.pi * 2
    local speed = 10 + math.random() * 20
    body:setLinearVelocity(math.cos(angle) * speed, math.sin(angle) * speed)
    body:setAngularVelocity((math.random() - 0.5) * 2)

    return item
end

return ItemSpawners
