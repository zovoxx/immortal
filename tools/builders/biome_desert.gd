extends RefCounted
## Salt Desert: white glare, dust storms, scavengers everywhere, few shelters.

const L := ZoneModule.Exit.LEFT
const R := ZoneModule.Exit.RIGHT
const S := ZoneModule.Exit.STRAIGHT

const SALT := Color(0.95, 0.94, 0.9)
const BONE := Color(0.88, 0.85, 0.76)


func modules(k: ModuleKit) -> Array:
	return [flats(k), flats_long(k), bend(k, L), bend(k, R), mesa(k), ruin(k), ribcage(k), salt_pillars(k), station(k)]


func salt_block(k: ModuleKit, pos: Vector3, h: float, yaw: float = 0.0) -> void:
	Geo.box(k.geo, pos + Vector3(0, h * 0.5, 0), Vector3(1.6, h, 1.4), SALT, ["surface_sand"], null, yaw)


func bones(k: ModuleKit, pos: Vector3) -> void:
	for i in 4:
		Geo.deco_box(k.geo, pos + Vector3(i * 0.4 - 0.6, 0.08, sin(i) * 0.3), Vector3(0.12, 0.12, 0.9), BONE, null, Vector3(0, i * 0.5, 0))


func flats(k: ModuleKit) -> ZoneModule:
	var m := k.begin("sd_flats", ["path", "chase_open"], 1, S, 1.4)
	k.full_floor()
	k.path_strip([Vector3(0, 0, 0), Vector3(-2, 0, 10), Vector3(0, 0, 20)], 3.0)
	salt_block(k, Vector3(2.5, 0, 6), 0.9, 0.3)
	salt_block(k, Vector3(-4, 0, 13), 1.1, -0.2)
	bones(k, Vector3(5, 0, 15))
	k.slot("Enemy1", Vector3(5, 0, 10))
	k.slot("Loot1", Vector3(-6, 0, 4))
	return m


func flats_long(k: ModuleKit) -> ZoneModule:
	var m := k.begin("sd_flats_long", ["path", "chase_open"], 2, S, 1.2)
	k.full_floor()
	k.path_strip([Vector3(0, 0, 0), Vector3(3, 0, 15), Vector3(-2, 0, 30), Vector3(0, 0, 40)], 3.0)
	# a low dune: up and over
	Geo.ramp(k.geo, Vector3(-6, 0, 16), 6, 5, 1.8, k.b.ground_color.darkened(0.04))
	Geo.box(k.geo, Vector3(-6, 0.9, 23), Vector3(6, 1.8, 4), k.b.ground_color.darkened(0.04))
	Geo.ramp(k.geo, Vector3(-6, 0, 30), 6, 5, 1.8, k.b.ground_color.darkened(0.04), null, PI)
	salt_block(k, Vector3(5, 0, 26), 1.0)
	bones(k, Vector3(6, 0, 8))
	k.slot("Open1", Vector3(2, 0, 20), 0.0)
	k.slot("Enemy1", Vector3(5, 0, 12))
	k.slot("Enemy2", Vector3(-4, 0, 34))
	k.slot("Loot1", Vector3(-6, 1.8, 23))
	return m


func bend(k: ModuleKit, dir: int) -> ZoneModule:
	var sx := 1.0 if dir == L else -1.0
	var m := k.begin("sd_bend_left" if dir == L else "sd_bend_right", ["path"], 1, dir, 1.3)
	k.full_floor()
	k.path_strip([Vector3(0, 0, 0), Vector3(0, 0, 8), Vector3(sx * 4, 0, 10), Vector3(sx * 10, 0, 10)], 3.0)
	k.rock(Vector3(-sx * 6.5, 0, 14), Vector3(5, 2.2, 6))
	salt_block(k, Vector3(sx * 6, 0, 3), 0.9)
	bones(k, Vector3(-sx * 3, 0, 4))
	k.slot("Enemy1", Vector3(sx * 6, 0, 15))
	k.slot("Loot1", Vector3(-sx * 7, 0, 3))
	return m


func mesa(k: ModuleKit) -> ZoneModule:
	var m := k.begin("sd_mesa", ["climb", "path"], 2, S, 1.0)
	k.full_floor()
	k.path_strip([Vector3(0, 0, 0), Vector3(-5, 0, 10), Vector3(-5, 0, 30), Vector3(0, 0, 40)], 3.0)
	k.rock(Vector3(4.5, 0, 20), Vector3(8, 3.2, 22), true)
	k.rock(Vector3(5, 3.2, 23), Vector3(5, 3.2, 10), true)
	k.rock(Vector3(4.5, 0, 32.5), Vector3(5, 1.6, 3), true)
	bones(k, Vector3(-7, 0, 20))
	k.slot("Loot1", Vector3(5, 6.4, 24))
	k.slot("Enemy1", Vector3(-6, 0, 22))
	return m


func ruin(k: ModuleKit) -> ZoneModule:
	var m := k.begin("sd_ruin", ["shelter", "rest"], 1, S, 1.0)
	k.full_floor()
	k.path_strip([Vector3(0, 0, 0), Vector3(-1.5, 0, 10), Vector3(0, 0, 20)], 3.0)
	k.hut(Vector3(5.5, 0, 10), PI * 0.5, k.b.rock_color)
	salt_block(k, Vector3(-5, 0, 6), 1.0)
	k.slot("Loot1", Vector3(5.5, 0, 10))
	k.slot("Enemy1", Vector3(-6, 0, 15))
	return m


func ribcage(k: ModuleKit) -> ZoneModule:
	var m := k.begin("sd_ribcage", ["landmark", "stealth"], 1, S, 0.9)
	k.full_floor()
	k.path_strip([Vector3(0, 0, 0), Vector3(0, 0, 20)], 3.0)
	for i in 5:
		var z := 3.0 + i * 3.5
		for side in [-1.0, 1.0]:
			Geo.box(k.geo, Vector3(side * 4.2, 2.5, z), Vector3(0.6, 5.0, 0.6), BONE, ["climbable"])
		Geo.deco_box(k.geo, Vector3(0, 5.2, z), Vector3(9.0, 0.5, 0.6), BONE)
	Geo.deco_sphere(k.geo, Vector3(0, 1.0, 19), 1.6, BONE)
	k.slot("Enemy1", Vector3(6.5, 0, 10))
	k.slot("Loot1", Vector3(-6.5, 0, 10))
	return m


func salt_pillars(k: ModuleKit) -> ZoneModule:
	var m := k.begin("sd_salt_pillars", ["path"], 1, S, 1.0)
	k.full_floor()
	k.path_strip([Vector3(0, 0, 0), Vector3(2, 0, 10), Vector3(0, 0, 20)], 3.0)
	for p in [Vector3(-5, 0, 4), Vector3(6, 0, 7), Vector3(-6, 0, 14), Vector3(5, 0, 17)]:
		Geo.box(k.geo, p + Vector3(0, 3.5, 0), Vector3(1.4, 7.0, 1.4), SALT, ["surface_sand"])
	salt_block(k, Vector3(-1, 0, 9), 0.8)
	k.slot("Enemy1", Vector3(-4, 0, 9))
	k.slot("Loot1", Vector3(6.5, 0, 12))
	return m


func station(k: ModuleKit) -> ZoneModule:
	var m := k.begin("sd_station", ["station"], 1, S, 1.0)
	k.full_floor()
	k.path_strip([Vector3(0, 0, 0), Vector3(0, 0, 20)], 3.0)
	k.station()
	bones(k, Vector3(-7, 0, 6))
	return m
