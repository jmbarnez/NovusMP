local Concord = require "concord"

-- The standard local transform (Float relative to sector center)
Concord.component("transform", function(c, x, y, r)
    c.x = x or 0
    c.y = y or 0
    c.r = r or 0
end)

-- The Sector Coordinate (Integer Grid ID)
Concord.component("sector", function(c, x, y)
    c.x = x or 0
    c.y = y or 0
end)

Concord.component("physics", function(c, body, shape, fixture)
    c.body = body
    c.shape = shape
    c.fixture = fixture
end)

-- [UPDATED] Input now stores the *state* of controls, not just the tag
Concord.component("input", function(c)
    c.thrust = false
    c.turn = 0 -- -1 (left), 0 (none), 1 (right)
end)

Concord.component("render", function(c, color)
    c.color = color or {1, 1, 1}
end)

-- Pilot/Ship Separation
Concord.component("pilot")

Concord.component("controlling", function(c, entity)
    c.entity = entity
end)

Concord.component("vehicle", function(c, thrust, turn_speed, max_speed)
    c.thrust = thrust or 1000
    c.turn_speed = turn_speed or 5
    c.max_speed = max_speed or 500
end)

-- Networking
Concord.component("network_identity", function(c, id)
    c.id = id
    c.owner_peer_id = nil -- Used by Host to map Entity -> ENet Peer
end)

Concord.component("network_sync", function(c, tx, ty, tr)
    c.target_x = tx or 0
    c.target_y = ty or 0
    c.target_r = tr or 0
end)