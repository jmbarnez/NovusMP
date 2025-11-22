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
            break
        elseif e.transform then
            target_entity = e
            break
        end
    end

    if target_entity and target_entity.transform and target_entity.sector then
        cam_x = target_entity.transform.x
        cam_y = target_entity.transform.y
        cam_sector_x = target_entity.sector.x or 0
        cam_sector_y = target_entity.sector.y or 0
    end

    -- Update HUMP Camera to the local coordinates
    if camera then
        camera:lookAt(cam_x, cam_y)
    end

    -- 2. Draw Background (Nebula + Stars)
    love.graphics.push()
    love.graphics.origin()
    if world.background then
        world.background:draw(cam_x, cam_y, cam_sector_x, cam_sector_y)
    end
    love.graphics.pop()

    -- 3. Draw World Content
    local function draw_world_content()
        -- Draw visual boundaries of the CURRENT sector (Debug Visual)
        love.graphics.setColor(0.1, 0.1, 0.1, 1)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", -Config.SECTOR_SIZE/2, -Config.SECTOR_SIZE/2, Config.SECTOR_SIZE, Config.SECTOR_SIZE)
        
        -- Draw text at the sector boundary
        love.graphics.setColor(0.3, 0.3, 0.3, 1)
        love.graphics.print("SECTOR EDGE >", Config.SECTOR_SIZE/2 - 100, 0)

        for _, e in ipairs(self.drawPool) do
            local t = e.transform
            local s = e.sector
            local r = e.render
            
            if not (t and s and r and t.x and t.y and s.x and s.y) then
                goto continue
            end

            -- Calculate Sector Difference
            local diff_x = s.x - (cam_sector_x or 0)
            local diff_y = s.y - (cam_sector_y or 0)

            -- Optimization: Only draw entities in neighbor sectors
            if math.abs(diff_x) <= 1 and math.abs(diff_y) <= 1 then
                
                -- Calculate Relative Position to Camera's Sector
                local relative_x = t.x + (diff_x * Config.SECTOR_SIZE)
                local relative_y = t.y + (diff_y * Config.SECTOR_SIZE)

                love.graphics.push()
                love.graphics.translate(relative_x, relative_y)
                love.graphics.rotate(t.r or 0)
                
                love.graphics.setColor(r.color[1] or 1, r.color[2] or 1, r.color[3] or 1, r.color[4] or 1)
                love.graphics.polygon("line", 15, 0, -10, -10, -5, 0, -10, 10)
                
                love.graphics.pop()
            end

            ::continue::
        end
    end

    -- 4. Execute World Draw
    if camera then
        camera:draw(draw_world_content)
    else
        draw_world_content()
    end

    -- 5. Draw HUD
    love.graphics.origin()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("FPS: " .. love.timer.getFPS(), 10, 10)
    
    -- Safely handle nil values for camera position
    local sector_x_display = cam_sector_x or "N/A"
    local sector_y_display = cam_sector_y or "N/A"
    local pos_x_display = cam_x and math.floor(cam_x) or "N/A"
    local pos_y_display = cam_y and math.floor(cam_y) or "N/A"
    
    love.graphics.print("Sector: [" .. sector_x_display .. ", " .. sector_y_display .. "]", 10, 30)
    love.graphics.print("Local Pos: " .. pos_x_display .. ", " .. pos_y_display, 10, 50)
end

return RenderSystem