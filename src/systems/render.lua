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
    cameraPool = { "input" }
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

                if e.name and e.name.value and e.name.value ~= "" then
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

                -- Check render type
                if type(r) == "table" and r.type then
                    -- Look up ship data if we have a type
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

                    if e.asteroid then
                        local key
                        if e.network_identity and e.network_identity.id then
                            key = e.network_identity.id
                        else
                            key = tostring(e)
                        end

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
                    else
                        love.graphics.circle("fill", 0, 0, radius)
                    end
                end

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
