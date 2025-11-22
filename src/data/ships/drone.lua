local Config = require "src.config"

return {
    name = "Drone",
    -- Physics
    mass = 1,
    linear_damping = Config.LINEAR_DAMPING,
    restitution = 0.2,
    radius = 10,

    -- Vehicle
    thrust = Config.THRUST,
    rotation_speed = Config.ROTATION_SPEED,
    max_speed = Config.MAX_SPEED,

    -- Stats
    max_hull = 100,
    max_shield = 100,
    shield_regen = 5, -- per second

    -- Render
    render_type = "drone",
    draw = function(color)
        -- Main Body / Cockpit (central hexagon) - FILLED
        love.graphics.setColor(0.2, 0.4, 0.8, 1) -- Blue fill
        love.graphics.polygon("fill",
            8, 0,                                -- front point
            4, 3,                                -- top-right
            -2, 3,                               -- back-right
            -6, 0,                               -- back center
            -2, -3,                              -- back-left
            4, -3                                -- top-left
        )
        love.graphics.setColor(0, 0, 0, 1)       -- Black outline
        love.graphics.polygon("line",
            8, 0, 4, 3, -2, 3, -6, 0, -2, -3, 4, -3
        )

        -- Inner cockpit detail (darker blue)
        love.graphics.setColor(0.1, 0.2, 0.5, 1)
        love.graphics.polygon("fill",
            4, 0, 1, 2, -3, 2, -3, -2, 1, -2
        )
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.polygon("line",
            4, 0, 1, 2, -3, 2, -3, -2, 1, -2
        )

        -- Left Wing/Stabilizer - FILLED
        love.graphics.setColor(0.2, 0.4, 0.8, 1)
        love.graphics.polygon("fill",
            -2, 3, -4, 8, -6, 8, -5, 3
        )
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.polygon("line",
            -2, 3, -4, 8, -6, 8, -5, 3
        )

        -- Right Wing/Stabilizer - FILLED
        love.graphics.setColor(0.2, 0.4, 0.8, 1)
        love.graphics.polygon("fill",
            -2, -3, -4, -8, -6, -8, -5, -3
        )
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.polygon("line",
            -2, -3, -4, -8, -6, -8, -5, -3
        )

        -- Left Engine Pod - FILLED
        love.graphics.setColor(0.15, 0.3, 0.6, 1) -- Darker blue for engines
        love.graphics.rectangle("fill", -8, 6, 4, 3)
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.rectangle("line", -8, 6, 4, 3)
        love.graphics.line(-8, 7.5, -4, 7.5) -- engine detail line

        -- Right Engine Pod - FILLED
        love.graphics.setColor(0.15, 0.3, 0.6, 1)
        love.graphics.rectangle("fill", -8, -9, 4, 3)
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.rectangle("line", -8, -9, 4, 3)
        love.graphics.line(-8, -7.5, -4, -7.5) -- engine detail line

        -- Thruster Exhaust (glowing orange/yellow)
        love.graphics.setColor(1, 0.6, 0.2, 0.8)
        love.graphics.setLineWidth(2)
        love.graphics.line(-8, 7, -10, 7)
        love.graphics.line(-8, 8, -10, 8)
        love.graphics.line(-8, -7, -10, -7)
        love.graphics.line(-8, -8, -10, -8)
        love.graphics.setLineWidth(1)

        -- Front sensors/weapons
        love.graphics.setColor(0.1, 0.2, 0.5, 1)
        love.graphics.circle("fill", 12, 0, 1.5)
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.line(8, 0, 12, 0)
        love.graphics.circle("line", 12, 0, 1.5)

        -- Technical details on wings (black lines)
        love.graphics.line(-3.5, 5.5, -5, 6)
        love.graphics.line(-3.5, -5.5, -5, -6)

        -- Center line detail
        love.graphics.line(-2, 0, 0, 0)
    end
}
