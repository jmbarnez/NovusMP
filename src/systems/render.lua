local Concord = require "concord"
local Config = require "src.config"

local RenderSystem = Concord.system({
    drawPool = {"transform", "render"},
    cameraPool = {"input", "transform"}
})

function RenderSystem:draw()
    local world = self:getWorld()
    local screen_w, screen_h = love.graphics.getDimensions()
    local camera = world.camera
    local cam_x, cam_y = 0, 0

    -- Handle Camera
    if camera then
        for _, e in ipairs(self.cameraPool) do
            local t = e.transform
            camera:lookAt(t.x, t.y)
        end
        local cx, cy = camera:position()
        cam_x, cam_y = cx - screen_w / 2, cy - screen_h / 2
    else
        for _, e in ipairs(self.cameraPool) do
            local t = e.transform
            cam_x = math.floor(t.x - screen_w/2)
            cam_y = math.floor(t.y - screen_h/2)
        end
    end

    -- Draw Stars
    if world.starfield then
        -- FIX: Use a fixed virtual size for wrapping (e.g. World Width or a large constant).
        -- If we use screen_w here, stars 'jump' when the window resizes.
        -- We use math.max to ensure the wrap bounds are at least as big as a large monitor (e.g. 3000px)
        -- to prevent black gaps on wide screens.
        local wrap_w = math.max(Config.WORLD_WIDTH, 3000)
        local wrap_h = math.max(Config.WORLD_HEIGHT, 3000)

        for _, star in ipairs(world.starfield) do
            -- Calculate position relative to the virtual wrap bounds
            local raw_x = (star.x - cam_x * star.speed) % wrap_w
            local raw_y = (star.y - cam_y * star.speed) % wrap_h

            -- Align to pixel centers so MSAA doesn't stretch the points
            local x = math.floor(raw_x) + 0.5
            local y = math.floor(raw_y) + 0.5

            -- Performance: Only draw if the star lands within the actual screen view
            if x >= -star.size * 2 and x <= screen_w + star.size * 2 and
               y >= -star.size * 2 and y <= screen_h + star.size * 2 then

                -- Optional soft glow for brighter stars
                if star.glow_radius then
                    love.graphics.setColor(star.color[1], star.color[2], star.color[3], star.glow_alpha)
                    love.graphics.circle("fill", x, y, star.glow_radius)
                end

                love.graphics.setColor(star.color[1], star.color[2], star.color[3], star.alpha)
                love.graphics.setPointSize(star.size)
                love.graphics.points(x, y)
            end
        end
    end

    local function draw_world()
        -- Draw World Bounds
        love.graphics.setColor(0.3, 0.3, 0.3)
        love.graphics.rectangle("line", 0, 0, Config.WORLD_WIDTH, Config.WORLD_HEIGHT)

        -- Draw Ships
        for _, e in ipairs(self.drawPool) do
            local t = e.transform
            local r = e.render
            love.graphics.push()
            love.graphics.translate(t.x, t.y)
            love.graphics.rotate(t.r)
            love.graphics.setColor(r.color)
            love.graphics.polygon("line", 15, 0, -10, -10, -5, 0, -10, 10)
            love.graphics.pop()
        end
    end

    if camera then
        camera:draw(draw_world)
    else
        love.graphics.push()
        love.graphics.translate(-cam_x, -cam_y)
        draw_world()
        love.graphics.pop()
    end

    love.graphics.setColor(1, 1, 1)
    love.graphics.print("FPS: " .. love.timer.getFPS(), 10, 10)
end

return RenderSystem