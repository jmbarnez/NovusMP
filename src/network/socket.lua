local Config = require "src.config"

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
        role = role,
        host = host,
        peer = peer,
        queue = {},
        peers = {},
    }, EnetSocket)
end

function EnetSocket:service()
    if not self.host then return end
    local event = self.host:service(0)
    while event do
        if event.type == "connect" then
            if self.role == "HOST" then
                self.peers[event.peer:connect_id()] = event.peer
            end
        elseif event.type == "disconnect" then
            if self.role == "HOST" then
                self.peers[event.peer:connect_id()] = nil
            end
        end
        table.insert(self.queue, event)
        event = self.host:service(0)
    end
end

function EnetSocket:send(data, peer, flag)
    flag = flag or "unreliable"
    if self.role == "HOST" then
        if peer then
            peer:send(data, 0, flag)
        else
            self.host:broadcast(data, 0, flag)
        end
    elseif self.peer then
        self.peer:send(data, 0, flag)
    end
end

local function split(str)
    local t = {}
    for s in string.gmatch(str, "[^|]+") do
        table.insert(t, s)
    end
    return t
end

return {
    EnetSocket = EnetSocket,
    split = split,
}
