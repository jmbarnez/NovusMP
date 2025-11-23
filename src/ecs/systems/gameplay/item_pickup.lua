local Concord = require "concord"
local EntityUtils = require "src.utils.entity_utils"

local ItemPickupSystem = Concord.system({
    pool = {"item", "physics"}
})



-- Note: Actual collision detection is handled via callbacks in PhysicsSystem,
-- but we can process the results or handle logic here if we want to decouple.
-- However, for simple pickup, we can just listen to the "collision" event emitted by PhysicsSystem.
-- This system might not even need an update loop if it's purely event driven.

-- Helper function to process item collection
local function collect_item(item, collector)
    if not (item and collector) then return end
    
    local itemComp = item.item
    if not itemComp then return end
    
    if itemComp.name == "Stone" then
        -- Try to add to cargo
        if collector.cargo then
            local cargo = collector.cargo
            local item_vol = itemComp.volume or 1.0
            
            if (cargo.current + item_vol) <= cargo.capacity then
                cargo.current = cargo.current + item_vol
                cargo.items["Stone"] = (cargo.items["Stone"] or 0) + 1
                print("Cargo: " .. cargo.current .. "/" .. cargo.capacity)
            else
                print("Cargo full! (" .. cargo.current .. "/" .. cargo.capacity .. ")")
                return -- Don't destroy item if cargo is full
            end
        end
    else
        print("Picked up " .. tostring(itemComp.name))
    end
    
    -- Destroy item
    EntityUtils.cleanup_physics_entity(item)
end

function ItemPickupSystem:onCollision(entityA, entityB, contact)


    local item, collector
    
    if entityA.item and entityB.wallet then
        item = entityA
        collector = entityB
    elseif entityB.item and entityA.wallet then
        item = entityB
        collector = entityA
    end
    
    if item and collector then
        collect_item(item, collector)
    end
end

function ItemPickupSystem:update(dt)
    -- Magnetic Pickup Logic
    local world = self:getWorld()
    if not world or not world.physics_world then return end
    
    for _, entity in ipairs(world:getEntities()) do
        if entity.magnet and entity.transform then
            local mag = entity.magnet
            local tx, ty = entity.transform.x, entity.transform.y
            
            -- Query physics world for items within radius
            local function queryCallback(fixture)
                local e = fixture:getUserData()
                if e and e.item and e.physics and e.physics.body then
                    local body = e.physics.body
                    local ix, iy = body:getPosition()
                    local dx = tx - ix
                    local dy = ty - iy
                    local dist2 = dx*dx + dy*dy
                    
                    -- Auto-pickup distance (e.g. 30 units)
                    local pickup_dist_sq = 30 * 30
                    
                    if dist2 < pickup_dist_sq then
                        -- Auto-collect if close enough
                        collect_item(e, entity)
                    elseif dist2 < (mag.radius * mag.radius) and dist2 > 1 then
                        local dist = math.sqrt(dist2)
                        
                        -- Gentle magnetic pull
                        -- Force decreases linearly with distance, but we scale it down overall
                        local force = mag.force * (1 - dist/mag.radius)
                        
                        -- Apply force towards magnet
                        local nx, ny = dx/dist, dy/dist
                        body:applyForce(nx * force, ny * force)
                    end
                end
                return true
            end
            
            local x1 = tx - mag.radius
            local y1 = ty - mag.radius
            local x2 = tx + mag.radius
            local y2 = ty + mag.radius
            
            world.physics_world:queryBoundingBox(x1, y1, x2, y2, queryCallback)
        end
    end
end

return ItemPickupSystem
