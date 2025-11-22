local Concord = require "concord"
local Config  = require "src.config"
local Network = require "src.systems.network"

local Asteroids = {}

local function spawn_single(world, sector_x, sector_y, x, y, radius)
    local body = love.physics.newBody(world.physics_world, x, y, "dynamic")
    body:setLinearDamping(Config.LINEAR_DAMPING * 2)
    body:setAngularDamping(Config.LINEAR_DAMPING * 2)

    local shape   = love.physics.newCircleShape(radius)
    local fixture = love.physics.newFixture(body, shape, radius * 0.2)
    fixture:setRestitution(0.1)

    local asteroid = Concord.entity(world)
    asteroid:give("transform", x, y, 0)
    asteroid:give("sector", sector_x or 0, sector_y or 0)
    asteroid:give("physics", body, shape, fixture)
    asteroid:give("render", { color = {0.7, 0.7, 0.7, 1}, radius = radius })
    asteroid:give("asteroid")

    world.next_asteroid_id = (world.next_asteroid_id or 0) + 1
    local nid = "AST_" .. tostring(world.next_asteroid_id)
    asteroid:give("network_identity", nid)

    local net = world:getSystem(Network.IO)
    if net and net.entity_map then
        net.entity_map[nid] = asteroid
    end

    fixture:setUserData(asteroid)

    return asteroid
end

function Asteroids.spawnField(world, sector_x, sector_y, seed, count)
    if not world or not world.physics_world then
        return
    end

    count = count or 40

    local use_seed = seed
    if type(use_seed) ~= "number" then
        use_seed = os.time()
    end

    local rng
    if love and love.math and love.math.newRandomGenerator then
        rng = love.math.newRandomGenerator(use_seed)
    else
        rng = math.random
    end

    local half_size = (Config.SECTOR_SIZE or 10000) * 0.5
    local inner_radius = half_size * 0.1
    local outer_radius = half_size * 0.8

    for i = 1, count do
        local a
        local r
        if type(rng) == "table" and rng.random then
            a = rng:random() * math.pi * 2
            local t = rng:random()
            r = inner_radius + (t * t) * (outer_radius - inner_radius)
        else
            a = math.random() * math.pi * 2
            local t = math.random()
            r = inner_radius + (t * t) * (outer_radius - inner_radius)
        end

        local x = math.cos(a) * r
        local y = math.sin(a) * r

        local radius
        if type(rng) == "table" and rng.random then
            radius = 15 + rng:random() * 45
        else
            radius = 15 + math.random() * 45
        end

        spawn_single(world, sector_x or 0, sector_y or 0, x, y, radius)
    end
end

return Asteroids
