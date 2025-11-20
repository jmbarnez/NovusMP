local Concord = require "concord"
local Config = require "src.config"

--[[ 
    ===========================================================================
    NETWORK PROTOCOL DOCUMENTATION
    ===========================================================================
    Format: string separated by pipes "|".
    
    1. State Update (Sent by Client & Host)
       "STATE | NetworkID | X | Y | Rotation"
    
    2. Welcome (Sent by Host on connect)
       "WELCOME | AssignedNetworkID"
       
    3. Disconnect (Sent by Host to all others)
       "DISCONNECT | NetworkID"
    ===========================================================================
]]

-- ============================================================================
-- LOW LEVEL SOCKET WRAPPER (ENet Helper)
-- ============================================================================

local EnetSocket = {}
EnetSocket.__index = EnetSocket

function EnetSocket.new(role)
    if not Config.NETWORK_AVAILABLE then return nil end

    local listen_address = string.format("*:%d", Config.PORT)
    local connect_address = string.format("%s:%d", Config.SERVER_HOST, Config.PORT)
    local host, peer
    
    if role == "HOST" then
        host = Config.ENET.host_create(listen_address)
        print("Network: Created HOST at " .. listen_address)
    elseif role == "CLIENT" then
        host = Config.ENET.host_create()
        peer = host and host:connect(connect_address)
        print("Network: Connecting to " .. connect_address)
    else
        -- Single player or invalid
        return nil
    end

    if not host then return nil end

    return setmetatable({
        role = role,
        host = host,
        peer = peer,      -- Only relevant for CLIENT
        queue = {},       -- Event queue
        peers = {}        -- Map of Connected Peers (for HOST)
    }, EnetSocket)
end

-- Polls ENet for events and queues them
function EnetSocket:service(timeout)
    if not self.host then return end
    local event = self.host:service(timeout or 0)
    while event do
        if event.type == "connect" then
            self.peers[event.peer:connect_id()] = event.peer
        elseif event.type == "disconnect" then
            self.peers[event.peer:connect_id()] = nil
        end
        table.insert(self.queue, event)
        event = self.host:service(0)
    end
end

-- Process the queued events with a callback
function EnetSocket:drain(callback)
    local event = table.remove(self.queue, 1)
    while event do
        callback(event)
        event = table.remove(self.queue, 1)
    end
end

-- Send data to specific peer or broadcast if host
function EnetSocket:send(data, target_peer, channel, flag)
    channel = channel or 0
    flag = flag or "unreliable" -- "reliable" or "unreliable"

    if self.role == "HOST" then
        if target_peer then
            target_peer:send(data, channel, flag)
        else
            self.host:broadcast(data, channel, flag)
        end
    elseif self.peer then
        self.peer:send(data, channel, flag)
    end
end

-- Host utility: Send to everyone EXCEPT one peer (e.g., the sender)
function EnetSocket:broadcast_except(data, except_peer, channel, flag)
    if self.role ~= "HOST" then return end
    channel = channel or 0
    flag = flag or "unreliable"

    for _, peer in pairs(self.peers) do
        if not except_peer or peer:connect_id() ~= except_peer:connect_id() then
            peer:send(data, channel, flag)
        end
    end
end

-- Helper to split string by pipe
local function parse_packet(data)
    local segments = {}
    for segment in string.gmatch(data, "[^|]+") do
        table.insert(segments, segment)
    end
    return segments
end


-- ============================================================================
-- CONCORD SYSTEM: NetworkSync
-- Handles smoothing (interpolation) of remote entities
-- ============================================================================

local NetworkSyncSystem = Concord.system({
    pool = {"network_sync", "transform"}
})

function NetworkSyncSystem:update(dt)
    -- Lerp factor determines how quickly visual position catches up to network data
    local lerp_speed = 1.0 / math.max(Config.SEND_RATE, 0.01)
    
    for _, e in ipairs(self.pool) do
        local sync = e.network_sync
        local t = e.transform
        
        -- Linear Interpolation for Position
        t.x = t.x + (sync.target_x - t.x) * lerp_speed * dt
        t.y = t.y + (sync.target_y - t.y) * lerp_speed * dt
        
        -- Angular Interpolation (Shortest path)
        local diff_r = sync.target_r - t.r
        -- Normalize difference to -PI to +PI
        while diff_r < -math.pi do diff_r = diff_r + math.pi * 2 end
        while diff_r > math.pi do diff_r = diff_r - math.pi * 2 end
        
        t.r = t.r + diff_r * lerp_speed * dt
    end
end


-- ============================================================================
-- CONCORD SYSTEM: NetworkIO
-- Handles sending packets and receiving packets (Parsing)
-- ============================================================================

local NetworkIOSystem = Concord.system({
    sendPool = {"input", "transform"} -- Entities that move locally and need to broadcast state
})

function NetworkIOSystem:init()
    self.time_since_send = 0
    self.entity_map = {}  -- Map: network_id (string) -> ECS Entity
    self.peer_map = {}    -- Map: peer_connect_id -> network_id (string)
    self.role = nil
    self.socket = nil
end

function NetworkIOSystem:setRole(role)
    self.role = role
    self.socket = EnetSocket.new(role)
    
    if role ~= "SINGLE" and not self.socket and Config.NETWORK_AVAILABLE then
        print("Networking unavailable: ENet host could not be created.")
    end
end

function NetworkIOSystem:update(dt)
    if not self.socket then return end

    -- 1. Receive Data
    self.socket:service(0)
    self.socket:drain(function(event)
        if event.type == "receive" then
            self:handle_packet(event.data, event.peer)
        elseif event.type == "connect" then
            self:on_peer_connect(event.peer)
        elseif event.type == "disconnect" then
            self:on_peer_disconnect(event.peer)
        end
    end)

    -- 2. Send Data (throttled by Config.SEND_RATE)
    self.time_since_send = self.time_since_send + dt
    if self.time_since_send < Config.SEND_RATE then return end

    self.time_since_send = 0
    
    -- Broadcast local player state
    for _, e in ipairs(self.sendPool) do
        local t = e.transform
        -- Format: STATE|MyID|X|Y|Rotation
        local packet = string.format("STATE|%s|%.3f|%.3f|%.3f", Config.MY_NETWORK_ID, t.x, t.y, t.r)
        self.socket:send(packet)
    end
end

-- --- Event Handlers ---

function NetworkIOSystem:on_peer_connect(peer)
    if self.role == "HOST" then
        -- Send a welcome packet so the new peer knows who we are (or assigns them an ID, conceptually)
        local welcome = string.format("WELCOME|%s", Config.MY_NETWORK_ID)
        self.socket:send(welcome, peer, 0, "reliable")
    end
end

function NetworkIOSystem:on_peer_disconnect(peer)
    local peer_id = peer:connect_id()
    
    if self.role == "HOST" then
        print(string.format("Peer disconnected: %s", peer_id))
        
        local net_id = self.peer_map[peer_id]
        if net_id then
            -- 1. Remove Entity from local world
            if self.entity_map[net_id] then
                self.entity_map[net_id]:destroy()
                self.entity_map[net_id] = nil
            end
            
            -- 2. Tell other clients to remove this Entity
            local disconnect_packet = string.format("DISCONNECT|%s", net_id)
            self.socket:broadcast_except(disconnect_packet, peer, 0, "reliable")
            
            self.peer_map[peer_id] = nil
        end
    end
end

function NetworkIOSystem:handle_packet(data, sender_peer)
    local items = parse_packet(data)
    if #items == 0 then return end
    local op = items[1]
    
    -- === HANDLE STATE UPDATES ===
    if op == "STATE" then
        if #items < 5 then return end
        local id = items[2]
        
        -- Ignore our own packets if they echo back
        if id == Config.MY_NETWORK_ID then return end

        -- Parse coordinates
        local x, y, r = tonumber(items[3]), tonumber(items[4]), tonumber(items[5])
        if not (x and y and r) then return end -- Packet corruption check

        -- If we are HOST, relay this packet to everyone else
        if self.role == "HOST" then
            self.peer_map[sender_peer:connect_id()] = id
            self.socket:broadcast_except(data, sender_peer, 0, "unreliable")
        end

        -- Update or Create the remote entity
        local entity = self.entity_map[id]
        
        if entity then
            -- Update existing
            local sync = entity.network_sync
            if sync then
                sync.target_x, sync.target_y, sync.target_r = x, y, r
            end
        else
            -- Create new representation of remote player
            local world = self:getWorld()
            local e = Concord.entity(world)
            e:give("transform", x, y, r)
            e:give("render", { 1, 0, 0 }) -- Red color for enemies/others
            e:give("network_identity", id)
            e:give("network_sync", x, y, r)
            
            self.entity_map[id] = e
        end

    -- === HANDLE DISCONNECTIONS ===
    elseif op == "DISCONNECT" then
        local id = items[2]
        local entity = self.entity_map[id]
        if entity then
            entity:destroy()
            self.entity_map[id] = nil
            print("Network: Removed disconnected entity " .. id)
        end
        
        -- Relay disconnection if we are Host
        if self.role == "HOST" then
            self.socket:broadcast_except(data, sender_peer, 0, "reliable")
        end
    end
end

return {
    Sync = NetworkSyncSystem,
    IO = NetworkIOSystem
}