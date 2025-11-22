-- src/systems/minimap.lua
local Concord = require "concord"
local Config  = require "src.config"

local MinimapSystem = Concord.system({
    -- Entities to draw on the minimap
    drawPool = { "transform", "render" },
    -- Entities to track for the camera center (usually the player)
    cameraPool = { "input", "controlling" }
})

-- Minimap Configuration
local MAP_SIZE = 200       -- Size of the minimap in pixels (square)
local MAP_MARGIN = 20      -- Margin from the top-right corner
local ZOOM_LEVEL = 0.1     -- Scale factor (how much world area is shown)
local BORDER_COLOR = {1, 1, 1, 1}
local BG_COLOR = {0, 0, 0, 0.8}

function MinimapSystem:draw()
    local screen_w, screen_h = love.graphics.getDimensions()
    
    -- 1. Define Minimap Position
    local map_x = screen_w - MAP_SIZE - MAP_MARGIN
    local map_y = MAP_MARGIN
    
    -- 2. Find Camera Center (Player Position)
    local cam_x, cam_y = 0, 0
    local cam_sector_x, cam_sector_y = 0, 0
    
    local target_entity = nil
    for _, e in ipairs(self.cameraPool) do
        if e.controlling and e.controlling.entity then
            target_entity = e.controlling.entity
            break
        elseif e.transform then -- Fallback
            target_entity = e
            break
        end
    end
    if target_entity and target_entity.transform then
        cam_x = target_entity.transform.x
        cam_y = target_entity.transform.y
        if target_entity.sector then
            cam_sector_x = target_entity.sector.x
            cam_sector_y = target_entity.sector.y
        end
    end
    
    -- 3. Draw Minimap Background & Border
    love.graphics.push()
    love.graphics.origin() -- Reset any previous transformations
    
    -- Draw Background
    love.graphics.setColor(BG_COLOR)
    love.graphics.rectangle("fill", map_x, map_y, MAP_SIZE, MAP_SIZE)
    
    -- Draw Border
    love.graphics.setColor(BORDER_COLOR)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", map_x, map_y, MAP_SIZE, MAP_SIZE)
    
    -- 4. Draw Entities (Clipped to Minimap)
    -- Enable Scissor to clip drawing to the minimap area
    love.graphics.setScissor(map_x, map_y, MAP_SIZE, MAP_SIZE)
    
    local center_x = map_x + MAP_SIZE / 2
    local center_y = map_y + MAP_SIZE / 2
    
    for _, e in ipairs(self.drawPool) do
        local t = e.transform
        local s = e.sector or {x=0, y=0}
        
        -- Calculate position relative to camera
        -- Handle Sector differences
        local diff_sector_x = s.x - cam_sector_x
        local diff_sector_y = s.y - cam_sector_y
        
        -- World difference including sectors
        local world_diff_x = (t.x - cam_x) + (diff_sector_x * Config.SECTOR_SIZE)
        local world_diff_y = (t.y - cam_y) + (diff_sector_y * Config.SECTOR_SIZE)
        
        -- Map position
        local draw_x = center_x + (world_diff_x * ZOOM_LEVEL)
        local draw_y = center_y + (world_diff_y * ZOOM_LEVEL)
        
        -- Check if within bounds (optimization)
        if draw_x > map_x and draw_x < map_x + MAP_SIZE and
           draw_y > map_y and draw_y < map_y + MAP_SIZE then
            
            -- Determine Color/Shape based on entity type
            if e.asteroid then
                love.graphics.setColor(0.6, 0.6, 0.6, 1) -- Grey for asteroids
                love.graphics.circle("fill", draw_x, draw_y, 3)
            elseif e.vehicle then -- Likely a ship
                if e == target_entity then
                    love.graphics.setColor(0, 1, 0, 1) -- Green for self
                else
                    love.graphics.setColor(1, 0, 0, 1) -- Red for others
                end
                love.graphics.circle("fill", draw_x, draw_y, 4)
            else
                -- Default white dot
                love.graphics.setColor(1, 1, 1, 0.5)
                love.graphics.circle("fill", draw_x, draw_y, 2)
            end
        end
    end
    
    -- Disable Scissor
    love.graphics.setScissor()
    love.graphics.pop()
end

return MinimapSystem
