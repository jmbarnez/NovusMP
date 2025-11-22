local WeaponManager = {}

WeaponManager.weapons = {}

function WeaponManager.load_plugins()
	local pulse_laser = require "src.plugins.weapons.pulse_laser"
	WeaponManager.weapons["pulse_laser"] = pulse_laser
end

function WeaponManager.get_weapon(name)
	return WeaponManager.weapons[name]
end

return WeaponManager
