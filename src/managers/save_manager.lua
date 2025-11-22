local SaveManager = {}

SaveManager.schema_version = 1

local bitser = require "bitser"
local Config = require "src.config"

local function get_slot_filename(slot)
    slot = slot or 1
    return string.format("saves/slot_%d.dat", slot)
end

local function find_local_player(world, explicit_player)
    if explicit_player then
        return explicit_player
    end

    if not world or not world.getEntities then
        return nil
    end

    local entities = world:getEntities()
    if not entities or not entities.size then
        return nil
    end

    for i = 1, entities.size do
        local e = entities[i]
        if e and e.pilot then
            return e
        end
    end

    return nil
end

function SaveManager.build_snapshot(world, player)
    local snapshot = {
        schema_version = SaveManager.schema_version,
        universe = {
            name = Config.UNIVERSE_NAME,
            seed = Config.UNIVERSE_SEED,
            seed_string = Config.UNIVERSE_SEED_STRING,
        },
    }

    local p = find_local_player(world, player)
    if not p then
        return snapshot
    end

    local pdata = {}
    snapshot.player = pdata

    if p.wallet then
        pdata.wallet = {
            credits = p.wallet.credits or 0,
        }
    end

    if p.level then
        pdata.level = {
            current = p.level.current or 1,
            xp = p.level.xp or 0,
            next_level_xp = p.level.next_level_xp or 1000,
        }
    end

    local controlling = p.controlling
    local ship = controlling and controlling.entity or nil
    if not ship then
        return snapshot
    end

    local sdata = {}
    pdata.ship = sdata

    if ship.transform then
        sdata.transform = {
            x = ship.transform.x or 0,
            y = ship.transform.y or 0,
            r = ship.transform.r or 0,
        }
    end

    if ship.sector then
        sdata.sector = {
            x = ship.sector.x or 0,
            y = ship.sector.y or 0,
        }
    end

    if ship.vehicle then
        sdata.vehicle = {
            thrust = ship.vehicle.thrust or 0,
            turn_speed = ship.vehicle.turn_speed or 0,
            max_speed = ship.vehicle.max_speed or 0,
        }
    end

    if ship.hull then
        sdata.hull = {
            max = ship.hull.max or 0,
            current = ship.hull.current or 0,
        }
    end

    if ship.shield then
        sdata.shield = {
            max = ship.shield.max or 0,
            current = ship.shield.current or 0,
            regen = ship.shield.regen or 0,
        }
    end

    if ship.weapon then
        sdata.weapon = {
            weapon_name = ship.weapon.weapon_name,
        }
    end

    if ship.render then
        sdata.render = {
            type = ship.render.type,
            color = ship.render.color,
            radius = ship.render.radius,
            length = ship.render.length,
            thickness = ship.render.thickness,
            shape = ship.render.shape,
        }
    end

    if ship.name then
        sdata.name = ship.name.value
    end

    sdata.ship_type = sdata.render and sdata.render.type or "drone"

    return snapshot
end

function SaveManager.save(slot, world, player)
    local snapshot = SaveManager.build_snapshot(world, player)

    local filename = get_slot_filename(slot)

    if love and love.filesystem and love.filesystem.createDirectory then
        love.filesystem.createDirectory("saves")
    end

    local ok, err = pcall(bitser.dumpLoveFile, filename, snapshot)
    if not ok then
        print("SaveManager: failed to save '" .. tostring(filename) .. "': " .. tostring(err))
        return false, err
    end

    return true
end

function SaveManager.load(slot)
    local filename = get_slot_filename(slot)

    if not (love and love.filesystem and love.filesystem.getInfo) then
        return nil, "filesystem unavailable"
    end

    local info = love.filesystem.getInfo(filename)
    if not info then
        return nil, "no save file"
    end

    local ok, result = pcall(bitser.loadLoveFile, filename)
    if not ok then
        print("SaveManager: failed to load '" .. tostring(filename) .. "': " .. tostring(result))
        return nil, result
    end

    if type(result) ~= "table" or not result.schema_version then
        return nil, "invalid save data"
    end

    return result
end

function SaveManager.has_save(slot)
    local filename = get_slot_filename(slot)

    if not (love and love.filesystem and love.filesystem.getInfo) then
        return false
    end

    return love.filesystem.getInfo(filename) ~= nil
end

function SaveManager.apply_snapshot(world, player, ship, snapshot)
    if not snapshot or type(snapshot) ~= "table" then
        return
    end

    if snapshot.universe then
        local u = snapshot.universe
        Config.UNIVERSE_NAME = u.name
        Config.UNIVERSE_SEED = u.seed
        Config.UNIVERSE_SEED_STRING = u.seed_string
    end

    local pdata = snapshot.player
    if not pdata then
        return
    end

    if player and pdata.wallet and player.wallet then
        player.wallet.credits = pdata.wallet.credits or player.wallet.credits
    end

    if player and pdata.level and player.level then
        if pdata.level.current then
            player.level.current = pdata.level.current
        end
        if pdata.level.xp then
            player.level.xp = pdata.level.xp
        end
        if pdata.level.next_level_xp then
            player.level.next_level_xp = pdata.level.next_level_xp
        end
    end

    local sdata = pdata.ship
    if not (ship and sdata) then
        return
    end

    if sdata.transform and ship.transform then
        ship.transform.x = sdata.transform.x or ship.transform.x
        ship.transform.y = sdata.transform.y or ship.transform.y
        ship.transform.r = sdata.transform.r or ship.transform.r
        if ship.physics and ship.physics.body then
            ship.physics.body:setPosition(ship.transform.x, ship.transform.y)
            ship.physics.body:setAngle(ship.transform.r or 0)
        end
    end

    if sdata.sector and ship.sector then
        ship.sector.x = sdata.sector.x or ship.sector.x
        ship.sector.y = sdata.sector.y or ship.sector.y
    end

    if sdata.hull and ship.hull then
        if sdata.hull.max then
            ship.hull.max = sdata.hull.max
        end
        if sdata.hull.current then
            ship.hull.current = sdata.hull.current
        end
    end

    if sdata.shield and ship.shield then
        if sdata.shield.max then
            ship.shield.max = sdata.shield.max
        end
        if sdata.shield.current then
            ship.shield.current = sdata.shield.current
        end
        if sdata.shield.regen then
            ship.shield.regen = sdata.shield.regen
        end
    end

    if sdata.vehicle and ship.vehicle then
        if sdata.vehicle.thrust then
            ship.vehicle.thrust = sdata.vehicle.thrust
        end
        if sdata.vehicle.turn_speed then
            ship.vehicle.turn_speed = sdata.vehicle.turn_speed
        end
        if sdata.vehicle.max_speed then
            ship.vehicle.max_speed = sdata.vehicle.max_speed
        end
    end

    if sdata.weapon and ship.weapon then
        if sdata.weapon.weapon_name then
            ship.weapon.weapon_name = sdata.weapon.weapon_name
        end
        ship.weapon.cooldown = 0
    end

    if sdata.render and ship.render then
        if sdata.render.type then ship.render.type = sdata.render.type end
        if sdata.render.color then ship.render.color = sdata.render.color end
        if sdata.render.radius then ship.render.radius = sdata.render.radius end
        if sdata.render.length then ship.render.length = sdata.render.length end
        if sdata.render.thickness then ship.render.thickness = sdata.render.thickness end
        if sdata.render.shape then ship.render.shape = sdata.render.shape end
    end

    if sdata.name and ship.name then
        ship.name.value = sdata.name
    end
end

return SaveManager
