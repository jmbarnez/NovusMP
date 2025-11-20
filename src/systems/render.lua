local Concord = require "concord"
local Config = require "src.config"

local RenderSystem = Concord.system({
    drawPool = {"transform", "render", "sector"},
    cameraPool = {"input"} 
})

function RenderSystem:draw()
    local world = self:getWorld()
    local screen_w, screen_h = love.graphics.getDimensions()
    local camera = world.camera
    
    -- 1. Find Camera Focus & Sector
    local cam_x, cam_y = 0, 0
    local cam_sector_x, cam_sector_y = 0, 0

    -- Find the target entity (Pilot or Ship)
    local target_entity = nil
    for _, e in ipairs(self.cameraPool) do
        if e.controlling and e.controlling.entity then
            target_entity = e.controlling.entity
        elseif e.transform then
            target_entity = e
        end
    end

    if target_entity and target_entity.transform and target_entity.sector then
        cam_x = target_entity.transform.x
        cam_y = target_entity.transform.y
        cam_sector_x = target_entity.sector.x
        cam_sector_y = target_entity.sector.y
    end

    -- Update HUMP Camera to the local coordinates
    if camera then
        camera:lookAt(cam_x, cam_y)
    end

    -- 2. Draw Starfield Background (Restored & Fixed for Sectors)
    if world.starfield then
        -- We need a continuous coordinate for parallax, or the stars will jump
        -- when we wrap from 5000 to -5000.
        local abs_cam_x = (cam_sector_x * Config.SECTOR_SIZE) + cam_x
        local abs_cam_y = (cam_sector_y * Config.SECTOR_SIZE) + cam_y

        -- Wrap rendering around the current screen size so stars always cover the view
        local wrap_w = screen_w
        local wrap_h = screen_h

        -- We draw stars in "Screen Space" (Camera ignored), calculating their positions manually
        love.graphics.push()
        love.graphics.origin() -- Reset any camera transforms
        
        local vertices = {}
        for i, star in ipairs(world.starfield) do
            -- Parallax Math using the continuous absolute position
            local x = (star.x - abs_cam_x * star.speed) % wrap_w
            local y = (star.y - abs_cam_y * star.speed) % wrap_h

            x = math.floor(x) + 0.5
            y = math.floor(y) + 0.5

            if x > -10 and x < screen_w + 10 and y > -10 and y < screen_h + 10 then
                if star.glow_radius then
                    love.graphics.setColor(star.color[1], star.color[2], star.color[3], star.glow_alpha)
                    love.graphics.circle("fill", x, y, star.glow_radius)
                end
            end

            local r, g, b = star.color[1], star.color[2], star.color[3]
            local a = star.alpha or 1
            vertices[i] = {x, y, r, g, b, a}
        end

        if world.star_mesh and #vertices > 0 then
            world.star_mesh:setVertices(vertices)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.setPointSize(1.5)
            love.graphics.draw(world.star_mesh)
        end
        love.graphics.pop()
    end

    -- 3. Draw World Content
    local function draw_world_content()
        -- Draw visual boundaries of the CURRENT sector (Debug Visual)
        love.graphics.setColor(0.1, 0.1, 0.1)
        love.graphics.rectangle("line", -Config.SECTOR_SIZE/2, -Config.SECTOR_SIZE/2, Config.SECTOR_SIZE, Config.SECTOR_SIZE)
        
        -- Draw text at the sector boundary to help you find it
        love.graphics.print("SECTOR EDGE >", Config.SECTOR_SIZE/2 - 100, 0)

        for _, e in ipairs(self.drawPool) do
            local t = e.transform
            local s = e.sector
            local r = e.render
            
            -- Calculate Sector Difference
            local diff_x = s.x - cam_sector_x
            local diff_y = s.y - cam_sector_y

            -- Optimization: Only draw entities in neighbor sectors
            if math.abs(diff_x) <= 1 and math.abs(diff_y) <= 1 then
                
                -- Calculate Relative Position to Camera's Sector
                local relative_x = t.x + (diff_x * Config.SECTOR_SIZE)
                local relative_y = t.y + (diff_y * Config.SECTOR_SIZE)

                love.graphics.push()
                love.graphics.translate(relative_x, relative_y)
                love.graphics.rotate(t.r)
                
                love.graphics.setColor(r.color)
                love.graphics.polygon("line", 15, 0, -10, -10, -5, 0, -10, 10)
                
                -- Debug: Print Sector ID on the ship
                if false then
                    love.graphics.setColor(1, 1, 1, 0.5)
                    love.graphics.print(s.x .. "," .. s.y, 20, 0)
                end

                love.graphics.pop()
            end
        end
    end

    -- 4. Execute World Draw
    if camera then
        camera:draw(draw_world_content)
    end

    -- 5. Draw HUD
    love.graphics.origin()
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("FPS: " .. love.timer.getFPS(), 10, 10)
    
    -- Debug Info: Distance to next sector
    local dist_x = (Config.SECTOR_SIZE/2) - math.abs(cam_x)
    local dist_y = (Config.SECTOR_SIZE/2) - math.abs(cam_y)
    
    love.graphics.print("Sector: [" .. cam_sector_x .. ", " .. cam_sector_y .. "]", 10, 30)
    love.graphics.print("Local Pos: " .. math.floor(cam_x) .. ", " .. math.floor(cam_y), 10, 50)
    love.graphics.print("Dist to Edge: " .. math.floor(math.min(dist_x, dist_y)), 10, 70)
end

return RenderSystem