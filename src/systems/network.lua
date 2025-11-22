local Concord = require "concord"
local Config = require "src.config"

--[[ 
    ===========================================================================
    HOST AUTHORITATIVE PROTOCOL (OPTIMIZED)
    ===========================================================================
    
    1. INPUT (Client -> Host)
       "I|InputID(NetworkID)|Thrust(0/1)|Turn(-1/0/1)"
       
    2. SNAPSHOT (Host -> Client)
       "S|Count|[ID,SecX,SecY,X,Y,R]|[ID,SecX...]"
       
    3. WELCOME (Host -> Client)
       "W|AssignedNetworkID"
       
    4. DISCONNECT (Host -> Client)
       "D|NetworkID"
    ===========================================================================
]]

-- ============================================================================
-- LOW LEVEL SOCKET WRAPPER
-- ============================================================================
local EnetSocket = {}
EnetSocket.__index = EnetSocket

function EnetSocket.new(role)
    if not Config.NETWORK_AVAILABLE then return nil end
    local listen_addr = string.format("*:%d", Config.PORT)
    local connect_addr = string.format("%s:%d", Config.SERVER_HOST, Config.PORT)
    local host, peer

    if role == "HOST" then
        host = Config.ENET.host_create(listen_addr)
        print("Network: Hosting at " .. listen_addr)
    elseif role == "CLIENT" then
        host = Config.ENET.host_create()
        peer = host and host:connect(connect_addr)
        print("Network: Connecting to " .. connect_addr)
    end

    if not host then return nil end
    return setmetatable({
        role = role, host = host, peer = peer,
        queue = {}, peers = {}
    }, EnetSocket)
end

function EnetSocket:service()
    if not self.host then return end
    local event = self.host:service(0)
    while event do
        if event.type == "connect" then
            if self.role == "HOST" then self.peers[event.peer:connect_id()] = event.peer end
        elseif event.type == "disconnect" then
            if self.role == "HOST" then self.peers[event.peer:connect_id()] = nil end
        end
        table.insert(self.queue, event)
        event = self.host:service(0)
    end
end

function EnetSocket:send(data, peer, flag)
    flag = flag or "unreliable"
    if self.role == "HOST" then
        if peer then peer:send(data, 0, flag) else self.host:broadcast(data, 0, flag) end
    elseif self.peer then
        self.peer:send(data, 0, flag)
    end
end

local function split(str)
    local t = {}
    for s in string.gmatch(str, "[^|]+") do table.insert(t, s) end
    return t
end

-- ============================================================================
-- SYNC SYSTEM (Interpolation)
-- ============================================================================
local NetworkSyncSystem = Concord.system({ pool = {"network_sync", "transform", "sector"} })

function NetworkSyncSystem:update(dt)
    -- Clients interpolate towards the server's truth
    local lerp = Config.LERP_FACTOR or 10.0
    
    for _, e in ipairs(self.pool) do
        -- SKIP interpolation for the local pilot (Client-Side Prediction)
        if e:has("pilot") then goto continue_sync end

        local sync = e.network_sync
        local t = e.transform
        local s = e.sector

        -- Simple sector check: If sector differs too much, just snap (teleport)
        if s.x ~= sync.target_sector_x or s.y ~= sync.target_sector_y then
             -- Snap immediately if sector changes to avoid interpolation artifacts across boundaries
             s.x = sync.target_sector_x
             s.y = sync.target_sector_y
             t.x = sync.target_x
             t.y = sync.target_y
        else
            -- Interpolate
            t.x = t.x + (sync.target_x - t.x) * lerp * dt
            t.y = t.y + (sync.target_y - t.y) * lerp * dt
            
            -- Angle wrap
            local dr = sync.target_r - t.r
            while dr < -math.pi do dr = dr + math.pi * 2 end
            while dr > math.pi do dr = dr - math.pi * 2 end
            t.r = t.r + dr * lerp * dt
        end

        if e.physics and e.physics.body then
            e.physics.body:setPosition(t.x, t.y)
            e.physics.body:setAngle(t.r or 0)
        end
        
        ::continue_sync::
    end
end

-- ============================================================================
-- IO SYSTEM (Logic)
-- ============================================================================
local NetworkIOSystem = Concord.system({
    inputs = {"input", "network_identity"}, -- Entities we send inputs for
    networked = {"network_identity", "transform", "sector"} -- Entities we sync
})

function NetworkIOSystem:init()
    self.role = "SINGLE"
    self.socket = nil
    self.timer = 0
    self.send_rate = Config.SEND_RATE or 0.03
    self.entity_map = {} -- ID -> Entity
    self.connection_state = "disconnected"
    self.connect_time = 0
end

function NetworkIOSystem:setRole(role)
    self.role = role
    self.socket = EnetSocket.new(role)
    self.connect_time = 0

    if self.socket then
        if role == "CLIENT" then
            self.connection_state = "connecting"
        else
            self.connection_state = "connected"
        end
    else
        if role == "CLIENT" then
            self.connection_state = "failed"
        else
            self.connection_state = "disconnected"
        end
    end
end

function NetworkIOSystem:update(dt)
    if not self.socket then return end

    if self.role == "CLIENT" then
        if self.connection_state == "connecting" then
            self.connect_time = self.connect_time + dt
            if self.connect_time >= Config.CONNECT_TIMEOUT then
                self.connection_state = "failed"
                return
            end
        elseif self.connection_state == "failed" then
            return
        end
    end
    
    -- 1. Service Network
    self.socket:service()
    local event = table.remove(self.socket.queue, 1)
    while event do
        self:handleEvent(event)
        event = table.remove(self.socket.queue, 1)
    end

    -- 2. Send Packets
    self.timer = self.timer + dt
    if self.timer >= self.send_rate then
        self.timer = 0
        if self.role == "CLIENT" then self:clientSend() end
        if self.role == "HOST" then self:hostSend() end
    end
end

-- === SENDING ===

function NetworkIOSystem:clientSend()
    -- Send "INPUT" for my local player
    for _, e in ipairs(self.inputs) do
        -- Only send input for MY player
        if e.network_identity.id == Config.MY_NETWORK_ID then
            local i = e.input
            -- Packet: I|ID|THRUST(1/0)|TURN
            local packet = string.format("I|%s|%d|%d", 
                Config.MY_NETWORK_ID, 
                i.thrust and 1 or 0, 
                i.turn
            )
            self.socket:send(packet, nil, "unreliable")
        end
    end
end

function NetworkIOSystem:hostSend()
    -- Host gathers ALL networked entities and sends a Snapshot
    -- Packet: S | Count | ID | Name | Sx | Sy | x | y | r | ID...
    local parts = {}
    local count = 0
    
    for _, e in ipairs(self.networked) do
        local t = e.transform
        local s = e.sector
        local nid = e.network_identity.id
        local name = (e.name and e.name.value) or ""

        table.insert(parts, string.format("%s|%s|%d|%d|%.1f|%.1f|%.2f", 
            nid, name, s.x, s.y, t.x, t.y, t.r
        ))
        count = count + 1
    end
    
    if count > 0 then
        local packet = "S|" .. count .. "|" .. table.concat(parts, "|")
        self.socket:send(packet, nil, "unreliable")
    end
end

-- === RECEIVING ===

function NetworkIOSystem:handleEvent(event)
    if event.type == "connect" then
        if self.role == "HOST" then
            -- Client joined. Create a ship for them.
            local new_id = tostring(math.random(10000, 99999))
            print("Host: Client connected. Spawning ID: " .. new_id)
            
            -- Create Server-Side Entity
            self:getWorld():emit("spawn_player", new_id, event.peer)
            
            -- Tell Client who they are
            self.socket:send("W|" .. new_id, event.peer, "reliable")
        end
    elseif event.type == "disconnect" then
        if self.role == "HOST" then
            print("Host: Client disconnected")
        elseif self.role == "CLIENT" then
            self.connection_state = "failed"
        end
    elseif event.type == "receive" then
        local data = split(event.data)
        local op = data[1]

        if self.role == "HOST" then
            if op == "I" then
                -- Update server-side input component
                local id = data[2]
                local entity = self.entity_map[id]
                if entity and entity.input then
                    entity.input.thrust = (tonumber(data[3]) == 1)
                    entity.input.turn = tonumber(data[4])
                end
            elseif op == "N" then
                -- Client is reporting its display name
                local id = data[2]
                local name = data[3] or ""
                local entity = self.entity_map[id]
                if entity then
                    if entity.name then
                        entity.name.value = name
                    else
                        entity:give("name", name)
                    end
                end
            end
        elseif self.role == "CLIENT" then
            if op == "W" then
                local my_id = data[2]
                Config.MY_NETWORK_ID = my_id
                print("Client: Assigned ID " .. my_id)
                self.connection_state = "connected"

                local name = Config.PLAYER_NAME or "Player"
                if self.socket then
                    self.socket:send("N|" .. my_id .. "|" .. name, nil, "reliable")
                end
            elseif op == "S" then
                self:processSnapshot(data)
            end
        end
    end
end

function NetworkIOSystem:processSnapshot(data)
    -- Format: S | Count | [ID, Name, Sx, Sy, x, y, r] ...
    local count = tonumber(data[2])
    local index = 3
    local step = 7 -- Params per entity

    for i = 1, count do
        if index + step - 1 > #data then break end

        local id = data[index]
        local name = data[index+1] or ""
        local sx = tonumber(data[index+2])
        local sy = tonumber(data[index+3])
        local x  = tonumber(data[index+4])
        local y  = tonumber(data[index+5])
        local r  = tonumber(data[index+6])

        local entity = self.entity_map[id]
        local is_me = (id == Config.MY_NETWORK_ID)

        if not entity then
            -- Entity doesn't exist locally, SPAWN IT
            local world = self:getWorld()

            entity = Concord.entity(world)
            entity:give("transform", x, y, r)
            entity:give("sector", sx, sy)

            local color = is_me and {0.2, 1, 0.2} or {1, 0.2, 0.2}
            entity:give("render", { type = "drone", color = color }) -- Green if me, Red if other

            entity:give("network_identity", id)
            entity:give("network_sync", x, y, r, sx, sy)

            if is_me then
                entity:give("input") -- Local input storage
                entity:give("pilot") -- Tag as local player
                entity:give("controlling", entity) -- Self-controlling

                -- CRITICAL: Give physics body to local player so we can PREDICT movement
                if world.physics_world then
                    local body = love.physics.newBody(world.physics_world, x, y, "dynamic")
                    body:setLinearDamping(Config.LINEAR_DAMPING)
                    body:setAngularDamping(Config.LINEAR_DAMPING)

                    local shape = love.physics.newCircleShape(10)
                    local fixture = love.physics.newFixture(body, shape, 1)
                    fixture:setRestitution(0.2)

                    entity:give("physics", body, shape, fixture)
                    entity:give("vehicle", Config.THRUST, Config.ROTATION_SPEED, Config.MAX_SPEED)
                    fixture:setUserData(entity)
                end
            else
                if world.physics_world then
                    local body = love.physics.newBody(world.physics_world, x, y, "kinematic")
                    body:setLinearDamping(Config.LINEAR_DAMPING)

                    local shape = love.physics.newCircleShape(10)
                    local fixture = love.physics.newFixture(body, shape, 1)
                    fixture:setRestitution(0.2)

                    entity:give("physics", body, shape, fixture)
                    fixture:setUserData(entity)
                end
            end

            if name ~= "" then
                if entity.name then
                    entity.name.value = name
                else
                    entity:give("name", name)
                end
            elseif is_me then
                entity:give("name", Config.PLAYER_NAME or "Player")
            end

            self.entity_map[id] = entity
        else
            -- Update Target for Interpolation
            if entity.network_sync then
                local ns = entity.network_sync
                ns.target_sector_x = sx
                ns.target_sector_y = sy
                ns.target_x = x
                ns.target_y = y
                ns.target_r = r

                -- RECONCILIATION (Only for me)
                if is_me and entity.transform and entity.sector then
                    -- Calculate distance between predicted (current) and server (target)
                    local dist_sq = (entity.transform.x - x)^2 + (entity.transform.y - y)^2

                    -- If sector mismatch, snap immediately
                    if entity.sector.x ~= sx or entity.sector.y ~= sy then
                        if entity.physics and entity.physics.body then
                            entity.physics.body:setPosition(x, y)
                        end
                        entity.transform.x = x
                        entity.transform.y = y
                        entity.sector.x = sx
                        entity.sector.y = sy
                    -- If position drift is too large (> 50 units), snap
                    elseif dist_sq > 2500 then
                        if entity.physics and entity.physics.body then
                            entity.physics.body:setPosition(x, y)
                        end
                        entity.transform.x = x
                        entity.transform.y = y
                    end
                end
            end

            if name ~= "" then
                if entity.name then
                    entity.name.value = name
                else
                    entity:give("name", name)
                end
            end
        end

        index = index + step
    end
end

function NetworkIOSystem:getConnectionState()
    return self.connection_state or "disconnected"
end

return {
    Sync = NetworkSyncSystem,
    IO = NetworkIOSystem
}