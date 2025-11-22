local PulseLaser = {
	name = "pulse_laser",
	cooldown = 0.25,
	projectile_speed = 800,
	damage = 10,
	lifetime = 1.5,
	cone_deg = 45,
	projectile = {
		color = {0.2, 0.8, 1.0, 1.0},
		radius = 3,
		shape = "beam",
		length = 16,
		thickness = 2
	}
}

return PulseLaser
