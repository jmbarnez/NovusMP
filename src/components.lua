local Concord = require "concord"

Concord.component("transform", function(c, x, y, r)
    c.x = x or 0
    c.y = y or 0
    c.r = r or 0
end)

Concord.component("physics", function(c, body, shape, fixture)
    c.body = body
    c.shape = shape
    c.fixture = fixture
end)

Concord.component("input")

Concord.component("render", function(c, color)
    c.color = color or {1, 1, 1}
end)

Concord.component("network_identity", function(c, id)
    c.id = id
end)

Concord.component("network_sync", function(c, tx, ty, tr)
    c.target_x = tx or 0
    c.target_y = ty or 0
    c.target_r = tr or 0
end)