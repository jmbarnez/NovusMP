-- Visual effects spawning utilities
local Concord = require "concord"

local VFXSpawners = {}

-- Spawn asteroid chunks when an asteroid is destroyed
function VFXSpawners.spawn_asteroid_chunks(world, parent_entity, num_chunks)
    if not (world and parent_entity) then return end
    
    local transform = parent_entity.transform
    local sector = parent_entity.sector
    local render = parent_entity.render
    
    if not (transform and sector and render) then return end
    
    num_chunks = num_chunks or (3 + math.random(0, 2))
    
    local parent_radius = render.radius or 10
    local parent_color = render.color or {0.6, 0.6, 0.6, 1}
    
    -- Calculate max chunk radius to conserve mass
    -- In 2D: total area of chunks ≤ parent area
    -- Area = π*r², so for N equal chunks: N * π*rchunk² ≤ π*rparent²
    -- Therefore: rchunk ≤ rparent / sqrt(N)
    local max_chunk_radius = parent_radius / math.sqrt(num_chunks)
    
    for i = 1, num_chunks do
        -- Random size with variance but respecting mass conservation
        local chunk_radius = max_chunk_radius * (0.6 + math.random() * 0.4)
        
        -- Random angle for radial distribution
        local angle = (math.pi * 2 / num_chunks) * i + (math.random() - 0.5) * 0.5
        
        -- Spawn position slightly offset from asteroid center
        local spawn_x = transform.x + math.cos(angle) * parent_radius * 0.5
        local spawn_y = transform.y + math.sin(angle) * parent_radius * 0.5
        
        -- Create chunk entity (no lifetime - chunks persist)
        local chunk = Concord.entity(world)
        chunk:give("transform", spawn_x, spawn_y, math.random() * math.pi * 2)
        chunk:give("sector", sector.x, sector.y)
        chunk:give("render", {
            render_type = "asteroid_chunk",
            color = parent_color,
            radius = chunk_radius
        })
        chunk:give("asteroid_chunk")
        
        -- Give chunks HP so they can be destroyed
        local hp_max = math.floor(chunk_radius * 1.5)
        chunk:give("hp", hp_max)
        
        -- Create physics body for chunk
        local chunk_body = love.physics.newBody(world.physics_world, spawn_x, spawn_y, "dynamic")
        chunk_body:setLinearDamping(1.0)
        chunk_body:setAngularDamping(1.0)
        
        local chunk_shape = love.physics.newCircleShape(chunk_radius * 0.8)
        local chunk_fixture = love.physics.newFixture(chunk_body, chunk_shape, 0.5)
        chunk_fixture:setRestitution(0.2)
        chunk_fixture:setUserData(chunk)
        
        chunk:give("physics", chunk_body, chunk_shape, chunk_fixture)
        
        -- Apply outward velocity
        local speed = 50 + math.random() * 100
        chunk_body:setLinearVelocity(
            math.cos(angle) * speed,
            math.sin(angle) * speed
        )
        chunk_body:setAngularVelocity((math.random() - 0.5) * 4)
    end
end

-- Spawn projectile shards when a projectile impacts
function VFXSpawners.spawn_projectile_shards(world, x, y, sector_x, sector_y, color, num_shards, shard_size)
    if not world then return end
    
    num_shards = num_shards or (4 + math.random(0, 2))
    shard_size = shard_size or (2 + math.random() * 2)
    color = color or {1, 1, 1, 1}
    
    for i = 1, num_shards do
        local angle = (math.pi * 2 / num_shards) * i + (math.random() - 0.5) * 1.0
        local spawn_x = x + math.cos(angle) * 3
        local spawn_y = y + math.sin(angle) * 3
        
        local shard = Concord.entity(world)
        shard:give("transform", spawn_x, spawn_y, math.random() * math.pi * 2)
        shard:give("sector", sector_x, sector_y)
        shard:give("render", {
            render_type = "projectile_shard",
            color = color,
            radius = shard_size
        })
        shard:give("projectile_shard")
        shard:give("lifetime", 0.3 + math.random() * 0.4)
        
        -- Create physics for shards
        local shard_body = love.physics.newBody(world.physics_world, spawn_x, spawn_y, "dynamic")
        shard_body:setLinearDamping(0.5)
        shard_body:setGravityScale(0)
        
        local shard_shape = love.physics.newCircleShape(shard_size * 0.3)
        local shard_fixture = love.physics.newFixture(shard_body, shard_shape, 0.1)
        shard_fixture:setSensor(true)
        shard_fixture:setUserData(shard)
        
        shard:give("physics", shard_body, shard_shape, shard_fixture)
        
        local speed = 80 + math.random() * 60
        shard_body:setLinearVelocity(
            math.cos(angle) * speed,
            math.sin(angle) * speed
        )
        shard_body:setAngularVelocity((math.random() - 0.5) * 8)
    end
end

return VFXSpawners
