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
    c.fire = false
    c.move_x = 0
    c.move_y = 0
    c.target_angle = nil
end)

Concord.component("render", function(c, arg)
    if type(arg) == "table" then
        if arg.type or arg.render_type then
            c.type = arg.type or arg.render_type
            c.color = arg.color or {1, 1, 1}
            if arg.radius then
                c.radius = arg.radius
            end
            if arg.length then
                c.length = arg.length
            end
            if arg.thickness then
                c.thickness = arg.thickness
            end
            if arg.shape then
                c.shape = arg.shape
            end
        else
            c.color = arg
        end
    elseif type(arg) == "string" then
        c.type = arg
        c.color = {1, 1, 1}
    else
        c.color = arg or {1, 1, 1}
    end
end)

Concord.component("name", function(c, value)
    c.value = value or ""
end)

Concord.component("hull", function(c, max, current)
    c.max = max or 100
    c.current = current or c.max
end)

Concord.component("shield", function(c, max, regen)
    c.max = max or 100
    c.current = max or 100
    c.regen = regen or 0
end)

Concord.component("wallet", function(c, credits)
    c.credits = credits or 0
end)

Concord.component("skills", function(c)
    c.list = {}
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

Concord.component("weapon", function(c, weapon_name, mounts)
    c.weapon_name = weapon_name or "pulse_laser"
    c.cooldown = 0
    c.mounts = mounts or { { x = 0, y = 0 } }
end)

Concord.component("projectile", function(c, damage, lifetime, owner)
    c.damage = damage or 0
    c.lifetime = lifetime or 0
    c.owner = owner
end)

Concord.component("level", function(c, current, xp, next_level_xp)
    c.current = current or 1
    c.xp = xp or 0
    c.next_level_xp = next_level_xp or 1000
end)

Concord.component("hp", function(c, max, current)
    c.max = max or 100
    c.current = current or c.max
    c.last_hit_time = nil
end)

Concord.component("asteroid")