local Concord = require "concord"
	local Config  = require "src.config"
	local Ships   = require "src.data.ships"
	local NetCore = require "src.network.socket"
	local Chat    = require "src.ui.chat"

	local EnetSocket = NetCore.EnetSocket
	local split      = NetCore.split

	local NetworkIOSystem = Concord.system({
	    inputs   = { "input", "network_identity" },  -- Entities we send inputs for
	    networked = { "network_identity", "transform", "sector" }, -- Entities we sync
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

	    -- 1. Service network
	    self.socket:service()
	    local event = table.remove(self.socket.queue, 1)
	    while event do
	        self:handleEvent(event)
	        event = table.remove(self.socket.queue, 1)
	    end

	    -- 2. Send packets
	    self.timer = self.timer + dt
	    if self.timer >= self.send_rate then
	        self.timer = 0
	        if self.role == "CLIENT" then self:clientSend() end
	        if self.role == "HOST"   then self:hostSend()   end
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
	    -- Host gathers ALL networked entities and sends a snapshot
	    -- Packet: S | Count | ID | Name | Kind | Extra | Sx | Sy | x | y | r | ...
	    local parts = {}
	    local count = 0

	    for _, e in ipairs(self.networked) do
	        local t   = e.transform
	        local s   = e.sector
	        local nid = e.network_identity.id
	        local name = (e.name and e.name.value) or ""

	        local kind = "ship"
	        local extra = 0
	        if e.asteroid then
	            kind = "asteroid"
	            if e.render and e.render.radius then
	                extra = e.render.radius
	            elseif e.physics and e.physics.shape and e.physics.shape.getRadius then
	                extra = e.physics.shape:getRadius()
	            end
	        end

	        table.insert(parts, string.format("%s|%s|%s|%.1f|%d|%d|%.1f|%.1f|%.2f",
	            nid, name, kind, extra, s.x, s.y, t.x, t.y, t.r
	        ))
	        count = count + 1
	    end

	    if count > 0 then
	        local packet = "S|" .. count .. "|" .. table.concat(parts, "|")
	        self.socket:send(packet, nil, "unreliable")
	    end
	end

	function NetworkIOSystem:sendChat(message)
	    local name = Config.PLAYER_NAME or "Player"
	    local ts   = os.time()

	    if not self.socket or self.role == "SINGLE" then
	        Chat.addMessage(string.format("%s: %s", name, message), "text", ts)
	        return
	    end

	    if self.role == "HOST" then
	        Chat.addMessage(string.format("%s: %s", name, message), "text", ts)
	        local packet = string.format("C|%s|%d|%s", name, ts, message)
	        self.socket:send(packet, nil, "reliable")
	    elseif self.role == "CLIENT" then
	        local packet = string.format("C|%s|%d|%s", name, ts, message)
	        self.socket:send(packet, nil, "reliable")
	    end
	end

	-- === RECEIVING ===

	function NetworkIOSystem:handleEvent(event)
	    if event.type == "connect" then
	        if self.role == "HOST" then
	            -- Client joined. Create a ship for them.
	            local new_id = tostring(math.random(10000, 99999))
	            print("Host: Client connected. Spawning ID: " .. new_id)

	            -- Create server-side entity
	            self:getWorld():emit("spawn_player", new_id, event.peer)

	            -- Tell client who they are
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
	        local op   = data[1]

	        if self.role == "HOST" then
	            if op == "I" then
	                -- Update server-side input component
	                local id = data[2]
	                local entity = self.entity_map[id]
	                if entity and entity.input then
	                    entity.input.thrust = (tonumber(data[3]) == 1)
	                    entity.input.turn   = tonumber(data[4])
	                end
	            elseif op == "N" then
	                -- Client is reporting its display name
	                local id   = data[2]
	                local name = data[3] or ""
	                local entity = self.entity_map[id]
	                if entity then
	                    if entity.name then
	                        entity.name.value = name
	                    else
	                        entity:give("name", name)
	                    end
	                end
	            elseif op == "C" then
	                local name = data[2] or "?"
	                local ts   = tonumber(data[3]) or os.time()
	                local msg  = data[4] or ""
	                Chat.addMessage(string.format("%s: %s", name, msg), "text", ts)
	                local packet = string.format("C|%s|%d|%s", name, ts, msg)
	                self.socket:send(packet, nil, "reliable")
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
	            elseif op == "C" then
	                local name = data[2] or "?"
	                local ts   = tonumber(data[3]) or os.time()
	                local msg  = data[4] or ""
	                Chat.addMessage(string.format("%s: %s", name, msg), "text", ts)
	            end
	        end
	    end
	end

	function NetworkIOSystem:processSnapshot(data)
	    -- Format: S | Count | [ID, Name, Sx, Sy, x, y, r] ...
	    local count = tonumber(data[2])
	    local index = 3
	    local step  = 9 -- Params per entity

	    for i = 1, count do
	        if index + step - 1 > #data then break end

	        local id    = data[index]
	        local name  = data[index + 1] or ""
	        local kind  = data[index + 2] or "ship"
	        local extra = tonumber(data[index + 3]) or 0
	        local sx    = tonumber(data[index + 4])
	        local sy    = tonumber(data[index + 5])
	        local x     = tonumber(data[index + 6])
	        local y     = tonumber(data[index + 7])
	        local r     = tonumber(data[index + 8])

	        local entity = self.entity_map[id]
	        local is_me  = (id == Config.MY_NETWORK_ID)

	        if not entity then
	            -- Entity doesn't exist locally, spawn it
	            local world = self:getWorld()

	            if kind == "asteroid" then
	                entity = Concord.entity(world)
	                entity:give("transform", x, y, r)
	                entity:give("sector", sx, sy)
	                entity:give("render", { color = {0.7, 0.7, 0.7, 1}, radius = extra > 0 and extra or 30 })
	                entity:give("network_identity", id)
	                entity:give("network_sync", x, y, r, sx, sy)
	                entity:give("asteroid")

	                if world.physics_world then
	                    local radius = extra > 0 and extra or 30
	                    local body = love.physics.newBody(world.physics_world, x, y, "kinematic")
	                    body:setLinearDamping(Config.LINEAR_DAMPING)

	                    local shape   = love.physics.newCircleShape(radius)
	                    local fixture = love.physics.newFixture(body, shape, 1)
	                    fixture:setRestitution(0.1)

	                    entity:give("physics", body, shape, fixture)
	                    fixture:setUserData(entity)
	                end

	                self.entity_map[id] = entity
	            else
	                entity = Concord.entity(world)
	                entity:give("transform", x, y, r)
	                entity:give("sector", sx, sy)

	                local color = is_me and {0.2, 1, 0.2} or {1, 0.2, 0.2}
	                entity:give("render", { type = "drone", color = color }) -- Green if me, red if other

	                entity:give("network_identity", id)
	                entity:give("network_sync", x, y, r, sx, sy)

	                if is_me then
	                    entity:give("input")      -- Local input storage

	                    -- Give physics body to local player so we can predict movement
	                    if world.physics_world then
	                        local body = love.physics.newBody(world.physics_world, x, y, "dynamic")
	                        body:setLinearDamping(Config.LINEAR_DAMPING)
	                        body:setAngularDamping(Config.LINEAR_DAMPING)
	                        body:setFixedRotation(true)

	                        local shape   = love.physics.newCircleShape(10)
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

	                        local shape   = love.physics.newCircleShape(10)
	                        local fixture = love.physics.newFixture(body, shape, 1)
	                        fixture:setRestitution(0.2)

	                        entity:give("physics", body, shape, fixture)
	                        fixture:setUserData(entity)
	                    end
	                end

	                -- Attach hull/shield so HUD can display status for all players
	                local stats = Ships and Ships.drone
	                if stats then
	                    entity:give("hull", stats.max_hull)
	                    entity:give("shield", stats.max_shield, stats.shield_regen)
	                end

	                -- Notify the game state when the local client's ship is ready
	                if is_me then
	                    world:emit("client_ship_spawned", entity, true)
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
	            end
	        else
	            -- Update target for interpolation
	            if entity.network_sync then
	                local ns = entity.network_sync
	                ns.target_sector_x = sx
	                ns.target_sector_y = sy
	                ns.target_x = x
	                ns.target_y = y
	                ns.target_r = r

	                -- Reconciliation (only for me)
	                if is_me and entity.transform and entity.sector then
	                    -- Calculate distance between predicted (current) and server (target)
	                    local dist_sq = (entity.transform.x - x) ^ 2 + (entity.transform.y - y) ^ 2
	                    local snap_dist = Config.RECONCILE_SNAP_DISTANCE or 150
	                    local snap_dist_sq = snap_dist * snap_dist

	                    -- If sector mismatch, snap immediately
	                    if entity.sector.x ~= sx or entity.sector.y ~= sy then
	                        if entity.physics and entity.physics.body then
	                            entity.physics.body:setPosition(x, y)
	                        end
	                        entity.transform.x = x
	                        entity.transform.y = y
	                        entity.sector.x = sx
	                        entity.sector.y = sy
	                    -- If position drift is too large, snap (use configurable threshold)
	                    elseif dist_sq > snap_dist_sq then
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

	return NetworkIOSystem
