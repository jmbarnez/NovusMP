local Concord = require "concord"
local Ships = require "src.data.ships"
local Config = require "src.config"

local ShipManager = {}

function ShipManager.spawn(world, ship_type_key, x, y, is_host_player)
    local data = Ships[ship_type_key]
    if not data then
        error("Unknown ship type: " .. tostring(ship_type_key))
    end

    -- Physics Body
    local body = love.physics.newBody(world.physics_world, x, y, "dynamic")
    body:setLinearDamping(data.linear_damping)
    body:setAngularDamping(data.linear_damping)
    body:setFixedRotation(true)

    local shape = love.physics.newCircleShape(data.radius)
    local fixture = love.physics.newFixture(body, shape, data.mass)
    fixture:setRestitution(data.restitution)

    -- Entity
    local ship = Concord.entity(world)
    ship:give("transform", x, y, 0)
    ship:give("sector", 0, 0)
    ship:give("physics", body, shape, fixture)
    ship:give("vehicle", data.thrust, data.rotation_speed, data.max_speed)
    ship:give("hull", data.max_hull)
    ship:give("shield", data.max_shield, data.shield_regen)
    fixture:setUserData(ship)

    -- Render component now stores the type and color
    -- Host is green-ish, Client is red-ish (default logic from before)
    local color = is_host_player and { 0.2, 1, 0.2 } or { 1, 0.2, 0.2 }
    ship:give("render", { type = data.render_type, color = color })

    if is_host_player then
        ship:give("name", Config.PLAYER_NAME or "Player")
    end

    -- Input component
    ship:give("input")
    ship:give("weapon", "pulse_laser")
    ship:give("level")

    return ship
end

return ShipManager
