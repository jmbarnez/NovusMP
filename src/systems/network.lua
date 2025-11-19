local Concord = require "concord"
local Config = require "src.config"

-- --- Low Level Socket Wrapper ---
local EnetSocket = {}
EnetSocket.__index = EnetSocket

function EnetSocket.new(role)
    if not Config.NETWORK_AVAILABLE then return nil end

    local listen_address = string.format("*:%d", Config.PORT)
    local connect_address = string.format("%s:%d", Config.SERVER_HOST, Config.PORT)

    local host, peer
    
    if role == "HOST" then
        host = Config.ENET.host_create(listen_address)
    elseif role == "CLIENT" then
        host = Config.ENET.host_create()
        peer = host and host:connect(connect_address)
    else
        -- SINGLE player or invalid role: No network socket
        return nil
    end

    if not host then return nil end

    return setmetatable({
        role = role,
        host = host,
        peer = peer,
        queue = {},
        peers = {}
    }, EnetSocket)
end

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

function EnetSocket:drain(callback)
    local event = table.remove(self.queue, 1)
    while event do
        callback(event)
        event = table.remove(self.queue, 1)
    end
end

function EnetSocket:send(data, target_peer, channel, flag)
    channel = channel or 0
    flag = flag or "unreliable"

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

-- --- Concord Systems ---

local NetworkSyncSystem = Concord.system({
    pool = {"network_sync", "transform"}
})

function NetworkSyncSystem:update(dt)
    local lerp_speed = 1.0 / math.max(Config.SEND_RATE, 0.01)
    
    for _, e in ipairs(self.pool) do
        local sync = e.network_sync
        local t = e.transform
        
        t.x = t.x + (sync.target_x - t.x) * lerp_speed * dt
        t.y = t.y + (sync.target_y - t.y) * lerp_speed * dt
        
        local diff_r = sync.target_r - t.r
        while diff_r < -math.pi do diff_r = diff_r + math.pi * 2 end
        while diff_r > math.pi do diff_r = diff_r - math.pi * 2 end
        t.r = t.r + diff_r * lerp_speed * dt
    end
end

local NetworkIOSystem = Concord.system({
    sendPool = {"input", "transform"}
})

function NetworkIOSystem:init()
    self.time_since_send = 0
    self.entity_map = {} -- Maps network_id (string) -> entity
    self.peer_map = {}    -- Maps peer_connect_id -> network_id
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

    self.time_since_send = self.time_since_send + dt
    if self.time_since_send < Config.SEND_RATE then return end

    self.time_since_send = 0
    for _, e in ipairs(self.sendPool) do
        local t = e.transform
        local packet = string.format("STATE|%s|%.3f|%.3f|%.3f", Config.MY_NETWORK_ID, t.x, t.y, t.r)
        self.socket:send(packet)
    end
end

function NetworkIOSystem:on_peer_connect(peer)
    if self.role == "HOST" then
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
            -- Remove
            if self.entity_map[net_id] then
                self.entity_map[net_id]:destroy()
                self.entity_map[net_id] = nil
            end
            
            -- Broadcast
            local disconnect_packet = string.format("DISCONNECT|%s", net_id)
            self.socket:broadcast_except(disconnect_packet, peer, 0, "reliable")
            
            self.peer_map[peer_id] = nil
        end
    end
end

local function parse_packet(data)
    local segments = {}
    for segment in string.gmatch(data, "[^|]+") do
        table.insert(segments, segment)
    end
    return segments
end

function NetworkIOSystem:handle_packet(data, sender_peer)
    local items = parse_packet(data)
    if #items == 0 then return end
    local op = items[1]
    
    if op == "STATE" then
        if #items < 5 then return end
        local id = items[2]
        if id == Config.MY_NETWORK_ID then return end

        local x, y, r = tonumber(items[3]), tonumber(items[4]), tonumber(items[5])
        if not (x and y and r) then return end

        if self.role == "HOST" then
            self.peer_map[sender_peer:connect_id()] = id
            self.socket:broadcast_except(data, sender_peer, 0, "unreliable")
        end

        local entity = self.entity_map[id]
        
        if entity then
            local sync = entity.network_sync
            if sync then
                sync.target_x, sync.target_y, sync.target_r = x, y, r
            end
        else
            local world = self:getWorld()
            local e = Concord.entity(world)
            e:give("transform", x, y, r)
            e:give("render", { 1, 0, 0 })
            e:give("network_identity", id)
            e:give("network_sync", x, y, r)
            
            self.entity_map[id] = e
        end

    elseif op == "DISCONNECT" then
        local id = items[2]
        local entity = self.entity_map[id]
        if entity then
            entity:destroy()
            self.entity_map[id] = nil
            print("Removed disconnected entity: " .. id)
        end
        
        if self.role == "HOST" then
            self.socket:broadcast_except(data, sender_peer, 0, "reliable")
        end
    end
end

return {
    Sync = NetworkSyncSystem,
    IO = NetworkIOSystem
}