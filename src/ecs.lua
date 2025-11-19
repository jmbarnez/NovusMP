local ECS = {}
ECS.__index = ECS

function ECS.new()
    return setmetatable({ entities = {}, systems = {}, next_id = 1 }, ECS)
end

function ECS:addEntity()
    local id = self.next_id
    self.next_id = self.next_id + 1
    local entity = { id = id, components = {} }
    table.insert(self.entities, entity)
    return entity
end

function ECS:addComponent(entity, name, data)
    entity.components[name] = data
    return entity
end

function ECS:getComponent(entity, name)
    return entity.components[name]
end

function ECS:addSystem(system)
    table.insert(self.systems, system)
end

function ECS:update(dt)
    for _, system in ipairs(self.systems) do
        -- We pass 'self' (the world instance) as the 3rd arg so systems can access world.controls, etc.
        if system.update then system:update(dt, self.entities, self) end
    end
end

function ECS:draw()
    for _, system in ipairs(self.systems) do
        if system.draw then system:draw(self.entities, self) end
    end
end

function ECS:iterate(entities, required_components, callback)
    for _, entity in ipairs(entities) do
        local has_all = true
        for _, req in ipairs(required_components) do
            if not entity.components[req] then
                has_all = false
                break
            end
        end
        if has_all then callback(entity) end
    end
end

return ECS