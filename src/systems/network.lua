local Concord = require "concord"
local Config = require "src.config"

--[[ 
    ===========================================================================
    HOST AUTHORITATIVE PROTOCOL
    ===========================================================================
    
    1. INPUT (Client -> Host)
       "INPUT | InputID (NetworkID) | Thrust (0/1) | Turn (-1/0/1)"
       sent frequently so Host knows what the player wants to do.

    2. SNAPSHOT (Host -> Client)
       "SNAP | Count | [ID, SecX, SecY, X, Y, R] | [ID, SecX...]"
       Host broadcasts the state of ALL dynamic entities.

    3. WELCOME (Host -> Client)
       "WELCOME | AssignedNetworkID"
       Tells the client who they are.

    4. DISCONNECT (Host -> Client)
       "DISCONNECT | NetworkID"
       Tells clients to delete an entity.
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
    local lerp = 10.0 -- Higher = Snappier, Lower = Smoother
    
    for _, e in ipairs(self.pool) do
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
    self.send_rate = 0.03 -- 30Hz
    self.entity_map = {} -- ID -> Entity
end

function NetworkIOSystem:setRole(role)
    self.role = role
    self.socket = EnetSocket.new(role)
end

function NetworkIOSystem:update(dt)
    if not self.socket then return end
    
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
            -- Packet: INPUT|ID|THRUST(1/0)|TURN
            local packet = string.format("INPUT|%s|%d|%d", 
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
    -- Packet: SNAP | Count | ID | Sx | Sy | x | y | r | ID...
    local parts = {}
    local count = 0
    
    for _, e in ipairs(self.networked) do
        local t = e.transform
        local s = e.sector
        local nid = e.network_identity.id
        
        table.insert(parts, string.format("%s|%d|%d|%.1f|%.1f|%.2f", 
            nid, s.x, s.y, t.x, t.y, t.r
        ))
        count = count + 1
    end
    
    if count > 0 then
        local packet = "SNAP|" .. count .. "|" .. table.concat(parts, "|")
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
            self.socket:send("WELCOME|" .. new_id, event.peer, "reliable")
        end
    elseif event.type == "disconnect" then
        if self.role == "HOST" then
            -- Find entity belonging to this peer and destroy it
            -- (For now, we rely on ID mapping or simple cleanup later)
            print("Host: Client disconnected")
        end
    elseif event.type == "receive" then
        local data = split(event.data)
        local op = data[1]

        if self.role == "HOST" then
            if op == "INPUT" then
                -- Update server-side input component
                local id = data[2]
                local entity = self.entity_map[id]
                if entity and entity.input then
                    entity.input.thrust = (tonumber(data[3]) == 1)
                    entity.input.turn = tonumber(data[4])
                end
            end
        elseif self.role == "CLIENT" then
            if op == "WELCOME" then
                local my_id = data[2]
                Config.MY_NETWORK_ID = my_id
                print("Client: Assigned ID " .. my_id)
            elseif op == "SNAP" then
                self:processSnapshot(data)
            end
        end
    end
end

function NetworkIOSystem:processSnapshot(data)
    -- Format: SNAP | Count | [ID, Sx, Sy, x, y, r] ...
    local count = tonumber(data[2])
    local index = 3
    local step = 6 -- Params per entity
    
    for i = 1, count do
        if index + step - 1 > #data then break end
        
        local id = data[index]
        local sx = tonumber(data[index+1])
        local sy = tonumber(data[index+2])
        local x  = tonumber(data[index+3])
        local y  = tonumber(data[index+4])
        local r  = tonumber(data[index+5])
        
        local entity = self.entity_map[id]
        
        if not entity then
            -- Entity doesn't exist locally, SPAWN IT
            local world = self:getWorld()
            local is_me = (id == Config.MY_NETWORK_ID)
            
            entity = Concord.entity(world)
            entity:give("transform", x, y, r)
            entity:give("sector", sx, sy)
            entity:give("render", is_me and {0.2, 1, 0.2} or {1, 0.2, 0.2}) -- Green if me, Red if other
            entity:give("network_identity", id)
            entity:give("network_sync", x, y, r)
            
            -- IMPORTANT: If this is ME, I need an Input component so InputSystem can read my baton
            if is_me then
                entity:give("input") -- Local input storage
                entity:give("pilot") -- Tag as local player
                entity:give("controlling", entity) -- Self-controlling
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
            end
        end
        
        index = index + step
    end
end

function NetworkIOSystem:getConnectionState()
    return (self.socket and self.socket.peer) and "connected" or "connecting"
end

return {
    Sync = NetworkSyncSystem,
    IO = NetworkIOSystem
}