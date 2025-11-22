local Concord = require "concord"
local WeaponManager = require "src.managers.weapon_manager"

local WeaponSystem = Concord.system({
	pool = { "weapon", "input", "transform", "sector" }
})

function WeaponSystem:init()
	self.role = "SINGLE"
end

function WeaponSystem:setRole(role)
	self.role = role
end

function WeaponSystem:update(dt)
	local world = self:getWorld()

	for _, e in ipairs(self.pool) do
		local weapon = e.weapon
		local input = e.input
		local transform = e.transform
		local sector = e.sector

		weapon.cooldown = (weapon.cooldown or 0) - dt
		if weapon.cooldown < 0 then
			weapon.cooldown = 0
		end

		if not input.fire or weapon.cooldown > 0 then
			goto continue_weapon
		end

		local weapon_def = WeaponManager.get_weapon(weapon.weapon_name)
		if not weapon_def then
			goto continue_weapon
		end

		local mounts = weapon.mounts or { { x = 0, y = 0 } }
		local base_angle = transform.r or 0
		local desired_angle = input.target_angle or base_angle
		local max_offset = weapon_def.max_angle_offset
		if not max_offset then
			if weapon_def.cone_deg then
				max_offset = math.rad(weapon_def.cone_deg)
			else
				max_offset = math.pi
			end
		end
		local diff = desired_angle - base_angle
		while diff < -math.pi do
			diff = diff + math.pi * 2
		end
		while diff > math.pi do
			diff = diff - math.pi * 2
		end
		if diff > max_offset then
			diff = max_offset
		elseif diff < -max_offset then
			diff = -max_offset
		end
		local angle = base_angle + diff
		local cos_a = math.cos(angle)
		local sin_a = math.sin(angle)

		for i = 1, #mounts do
			local mount = mounts[i]
			local mx = mount.x or 0
			local my = mount.y or 0

			local px = transform.x + mx * cos_a - my * sin_a
			local py = transform.y + mx * sin_a + my * cos_a

			local projectile = Concord.entity(world)
			projectile:give("transform", px, py, angle)
			projectile:give("sector", sector.x, sector.y)
			projectile:give("projectile", weapon_def.damage, weapon_def.lifetime or 1.5, e)

			local proj_cfg = weapon_def.projectile or {}
			local render_type = proj_cfg.type or proj_cfg.render_type or "projectile"
			local proj_color = proj_cfg.color or weapon_def.color
			local proj_radius = proj_cfg.radius or weapon_def.radius or 3
			local proj_length = proj_cfg.length
			local proj_thickness = proj_cfg.thickness
			local proj_shape = proj_cfg.shape

			projectile:give("render", {
				type = render_type,
				color = proj_color,
				radius = proj_radius,
				length = proj_length,
				thickness = proj_thickness,
				shape = proj_shape
			})

			if world.physics_world then
				local body = love.physics.newBody(world.physics_world, px, py, "dynamic")
				body:setBullet(true)
				body:setAngle(angle)
				local radius = proj_cfg.radius or weapon_def.radius or 3
				local shape = love.physics.newCircleShape(radius)
				local fixture = love.physics.newFixture(body, shape, 0.1)
				fixture:setRestitution(0)
				projectile:give("physics", body, shape, fixture)
				fixture:setUserData(projectile)

				local speed = weapon_def.projectile_speed or 800
				local vx = math.cos(angle) * speed
				local vy = math.sin(angle) * speed
				body:setLinearVelocity(vx, vy)
			end
		end

		weapon.cooldown = weapon_def.cooldown or 0.25

		::continue_weapon::
	end
end

return WeaponSystem
