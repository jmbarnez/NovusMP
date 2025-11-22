local Concord = require "concord"
local Config = require "src.config"

local nameFont
local asteroidShapes = {}

local function hashString(s)
    local h = 0
    for i = 1, #s do
        h = (h * 31 + s:byte(i)) % 2147483647
    end
    return h
end

local RenderSystem = Concord.system({
    drawPool = { "transform", "render", "sector" },
    cameraPool = { "input", "controlling" }
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
        love.graphics.rectangle("line", -Config.SECTOR_SIZE / 2, -Config.SECTOR_SIZE / 2, Config.SECTOR_SIZE,
            Config.SECTOR_SIZE)

        -- Draw text at the sector boundary
        love.graphics.setColor(0.3, 0.3, 0.3, 1)
        love.graphics.print("SECTOR EDGE >", Config.SECTOR_SIZE / 2 - 100, 0)

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

                local is_self = (target_entity ~= nil and e == target_entity)

                if (not is_self) and e.name and e.name.value and e.name.value ~= "" then
                    local name = e.name.value
                    if not nameFont then
                        nameFont = love.graphics.newFont(12)
                    end
                    local prevFont = love.graphics.getFont()
                    love.graphics.setFont(nameFont)
                    local textWidth = nameFont:getWidth(name)
                    local textHeight = nameFont:getHeight()
                    love.graphics.setColor(1, 1, 1, 1)
                    love.graphics.print(name, -textWidth * 0.5, -(20 + textHeight))
                    love.graphics.setFont(prevFont)
                end

                love.graphics.rotate(t.r or 0)

                -- Check render type / asteroid
                if e.asteroid then
                    -- Procedural asteroid polygons (always used for asteroids)
                    local color = { 1, 1, 1, 1 }
                    if type(r) == "table" then
                        if type(r.color) == "table" then
                            color = r.color
                        elseif #r >= 3 then
                            color = r
                        end
                    elseif type(r) == "number" then
                        color = { r, r, r, 1 }
                    end

                    local cr = color[1] or 1
                    local cg = color[2] or 1
                    local cb = color[3] or 1
                    local ca = color[4] or 1
                    love.graphics.setColor(cr, cg, cb, ca)

                    local radius = 10
                    if type(r) == "table" and r.radius then
                        radius = r.radius
                    end

                    local key = tostring(e)

                    local poly = asteroidShapes[key]
                    if not poly then
                        poly = {}
                        local seed = hashString(key)
                        local rng = (love and love.math and love.math.newRandomGenerator) and love.math.newRandomGenerator(seed) or nil
                        local function rnd()
                            if rng and rng.random then
                                return rng:random()
                            else
                                return math.random()
                            end
                        end

                        local vertex_count = 8 + math.floor(rnd() * 5)
                        if vertex_count < 5 then vertex_count = 5 end

                        for i = 1, vertex_count do
                            local angle = (i / vertex_count) * math.pi * 2 + (rnd() - 0.5) * 0.4
                            local rr = radius * (0.7 + rnd() * 0.4)
                            table.insert(poly, math.cos(angle) * rr)
                            table.insert(poly, math.sin(angle) * rr)
                        end

                        asteroidShapes[key] = poly
                    end

                    love.graphics.polygon("fill", poly)

                    local inner = {}
                    for i = 1, #poly, 2 do
                        table.insert(inner, poly[i] * 0.7)
                        table.insert(inner, poly[i + 1] * 0.7)
                    end

                    local hr = math.min((cr or 1) * 1.1, 1)
                    local hg = math.min((cg or 1) * 1.1, 1)
                    local hb = math.min((cb or 1) * 1.1, 1)
                    local ha = (ca or 1) * 0.9
                    love.graphics.setColor(hr, hg, hb, ha)
                    love.graphics.polygon("fill", inner)

                    local orr = (cr or 1) * 0.5
                    local org = (cg or 1) * 0.5
                    local orb = (cb or 1) * 0.5
                    local ora = ca or 1
                    local oldLineWidth = love.graphics.getLineWidth()
                    love.graphics.setColor(orr, org, orb, ora)
                    love.graphics.setLineWidth(2)
                    love.graphics.polygon("line", poly)
                    love.graphics.setLineWidth(oldLineWidth)

                    love.graphics.setColor(cr, cg, cb, ca)

                    if e.hp and e.hp.max and e.hp.current and e.hp.current < e.hp.max and e.hp.last_hit_time then
                        local now = (love and love.timer and love.timer.getTime) and love.timer.getTime() or nil
                        if now then
                            local elapsed = now - (e.hp.last_hit_time or 0)
                            local visible_duration = 2.0
                            if elapsed >= 0 and elapsed <= visible_duration then
                                local pct = 0
                                if e.hp.max > 0 then
                                    pct = math.max(0, math.min(1, e.hp.current / e.hp.max))
                                end

                                local bar_width = (radius or 10) * 2
                                local bar_height = 4
                                local y_offset = -(radius or 10) - 10

                                love.graphics.setColor(0, 0, 0, 0.7)
                                love.graphics.rectangle("fill", -bar_width * 0.5, y_offset, bar_width, bar_height, 2, 2)

                                love.graphics.setColor(1.0, 0.9, 0.25, 1.0)
                                love.graphics.rectangle("fill", -bar_width * 0.5, y_offset, bar_width * pct, bar_height, 2, 2)

                                love.graphics.setColor(0, 0, 0, 1.0)
                                love.graphics.rectangle("line", -bar_width * 0.5, y_offset, bar_width, bar_height, 2, 2)
                            end
                        end
                    end
                elseif e.asteroid_chunk then
                    -- Render asteroid chunks (simpler than full asteroids)
                    local color = { 1, 1, 1, 1 }
                    if type(r) == "table" then
                        if type(r.color) == "table" then
                            color = r.color
                        elseif #r >= 3 then
                            color = r
                        end
                    elseif type(r) == "number" then
                        color = { r, r, r, 1 }
                    end

                    local cr = color[1] or 1
                    local cg = color[2] or 1
                    local cb = color[3] or 1
                    local ca = color[4] or 1
                     
                    love.graphics.setColor(cr, cg, cb, ca)

                    local radius = 10
                    if type(r) == "table" and r.radius then
                        radius = r.radius
                    end

                    local key = tostring(e)

                    local poly = asteroidShapes[key]
                    if not poly then
                        poly = {}
                        local seed = hashString(key)
                        local rng = (love and love.math and love.math.newRandomGenerator) and love.math.newRandomGenerator(seed) or nil
                        local function rnd()
                            if rng and rng.random then
                                return rng:random()
                            else
                                return math.random()
                            end
                        end

                        -- Simpler polygon for chunks (fewer vertices)
                        local vertex_count = 4 + math.floor(rnd() * 3)
                        if vertex_count < 4 then vertex_count = 4 end

                        for i = 1, vertex_count do
                            local angle = (i / vertex_count) * math.pi * 2 + (rnd() - 0.5) * 0.6
                            local rr = radius * (0.6 + rnd() * 0.5)
                            table.insert(poly, math.cos(angle) * rr)
                            table.insert(poly, math.sin(angle) * rr)
                        end

                        asteroidShapes[key] = poly
                    end

                    love.graphics.polygon("fill", poly)

                    -- No inner highlight for chunks, just outline
                    local orr = (cr or 1) * 0.5
                    local org = (cg or 1) * 0.5
                    local orb = (cb or 1) * 0.5
                    local ora = ca or 1
                    local oldLineWidth = love.graphics.getLineWidth()
                    love.graphics.setColor(orr, org, orb, ora)
                    love.graphics.setLineWidth(1.5)
                    love.graphics.polygon("line", poly)
                    love.graphics.setLineWidth(oldLineWidth)
                elseif e.projectile_shard then
                    -- Render projectile shards (tiny particles with fade-out)
                    local color = { 1, 1, 1, 1 }
                    if type(r) == "table" and r.color then
                        color = r.color
                    end

                    local cr = color[1] or 1
                    local cg = color[2] or 1
                    local cb = color[3] or 1
                    local ca = color[4] or 1
                     
                    -- Apply fade out based on lifetime
                    if e.lifetime then
                        local fade = 1.0 - (e.lifetime.elapsed / e.lifetime.duration)
                        ca = ca * math.max(0, fade)
                    end
                     
                    love.graphics.setColor(cr, cg, cb, ca)

                    local radius = 2
                    if type(r) == "table" and r.radius then
                        radius = r.radius
                    end

                    -- Simple circle for shards
                    love.graphics.circle("fill", 0, 0, radius)
                elseif type(r) == "table" and r.type then
                    if r.type == "projectile" then
                        local color = r.color or { 1, 1, 1, 1 }
                        local cr = color[1] or 1
                        local cg = color[2] or 1
                        local cb = color[3] or 1
                        local ca = color[4] or 1
                        love.graphics.setColor(cr, cg, cb, ca)

                        local shape = r.shape or "beam"
                        if shape == "beam" then
                            local radius = r.radius or 3
                            local length = r.length or (radius * 4)
                            local thickness = r.thickness or (radius * 0.7)
                            love.graphics.rectangle("fill", -length * 0.5, -thickness * 0.5, length, thickness)
                        elseif shape == "circle" then
                            local radius = r.radius or 3
                            love.graphics.circle("fill", 0, 0, radius)
                        else
                            local radius = r.radius or 3
                            love.graphics.circle("fill", 0, 0, radius)
                        end
                    else
                        -- Ships and other typed renderables
                        local Ships = require "src.data.ships"
                        local shipData = Ships[r.type]

                        if shipData and shipData.draw then
                            shipData.draw(r.color)
                        else
                            -- Fallback
                            local color = r.color or { 1, 1, 1 }
                            love.graphics.setColor(unpack(color))
                            love.graphics.circle("fill", 0, 0, 10)
                        end
                    end
                else
                    -- Fallback for simple shapes or old format
                    local color = { 1, 1, 1, 1 }
                    if type(r) == "table" then
                        if type(r.color) == "table" then
                            color = r.color
                        elseif #r >= 3 then
                            color = r
                        end
                    elseif type(r) == "number" then
                        color = { r, r, r, 1 }
                    end

                    local cr = color[1] or 1
                    local cg = color[2] or 1
                    local cb = color[3] or 1
                    local ca = color[4] or 1
                    love.graphics.setColor(cr, cg, cb, ca)

                    local radius = 10
                    if type(r) == "table" and r.radius then
                        radius = r.radius
                    end

                    love.graphics.circle("fill", 0, 0, radius)
                end
                 
                -- Debug: Draw a small red dot at the center to ensure it's being drawn at all
                -- love.graphics.setColor(1, 0, 0, 1)
                -- love.graphics.circle("fill", 0, 0, 2)

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
end

return RenderSystem
