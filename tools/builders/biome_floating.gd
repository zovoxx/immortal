extends RefCounted
## Floating Ruins: broken platforms over a void. Wall-runs, climbing, gaps, wind gusts.

const L := ZoneModule.Exit.LEFT
const R := ZoneModule.Exit.RIGHT
const S := ZoneModule.Exit.STRAIGHT

const STONE := Color(0.62, 0.6, 0.66)
const RUNE := Color(0.55, 0.75, 1.0)


func modules(k: ModuleKit) -> Array:
	return [walkway(k), steps(k), bend(k, L), bend(k, R), spire(k), shrine(k),
		wallrun_gap(k), sky_bridge(k), islands(k), station(k)]


func plat(k: ModuleKit, x0: float, x1: float, z0: float, z1: float, top: float = 0.0) -> void:
	k.floor_box(x0, x1, z0, z1, top, k.b.path_color.darkened(randf_range(0.0, 0.12)), 1.6, ["surface_stone"])
	# hanging rock under the platform
	Geo.deco_box(k.geo, Vector3((x0 + x1) * 0.5, top - 2.4, (z0 + z1) * 0.5), Vector3((x1 - x0) * 0.7, 2.0, (z1 - z0) * 0.7), k.b.rock_color.darkened(0.25))


func pillar(k: ModuleKit, pos: Vector3, h: float) -> void:
	Geo.box(k.geo, pos + Vector3(0, h * 0.5, 0), Vector3(0.9, h, 0.9), STONE, ["surface_stone"])
	var r := Geo.deco_box(k.geo, pos + Vector3(0, h * 0.6, -0.46), Vector3(0.3, 0.3, 0.02), RUNE)
	r.material_override = Geo.mat(RUNE, 0.4, 2.0)


func walkway(k: ModuleKit) -> ZoneModule:
	var m := k.begin("fr_walkway", ["path"], 1, S, 1.3)
	plat(k, -4.5, 4.5, 0, 8.5)
	plat(k, -4.5, 4.5, 11, 20)
	plat(k, 5.5, 9.5, 4, 14, 1.0)
	pillar(k, Vector3(-4, 0, 2), 3.0)
	pillar(k, Vector3(-4, 0, 18), 2.2)
	k.slot("Enemy1", Vector3(0, 0, 16))
	k.slot("Loot1", Vector3(7.5, 1.0, 9))
	return m


func steps(k: ModuleKit) -> ZoneModule:
	var m := k.begin("fr_steps", ["path"], 2, S, 1.0)
	plat(k, -5, 5, 0, 6)
	var hs := [1.0, 2.0, 2.0, 1.0]
	for i in 4:
		plat(k, -2.2, 2.2, 7.5 + i * 5.5, 11.5 + i * 5.5, hs[i])
	plat(k, -5, 5, 29.5, 40)
	pillar(k, Vector3(4, 0, 34), 4.0)
	k.slot("Loot1", Vector3(-3, 0, 36))
	k.slot("Enemy1", Vector3(2, 0, 37))
	return m


func bend(k: ModuleKit, dir: int) -> ZoneModule:
	var sx := 1.0 if dir == L else -1.0
	var m := k.begin("fr_bend_left" if dir == L else "fr_bend_right", ["path"], 1, dir, 1.3)
	plat(k, -4.5, 4.5, 0, 13.5)
	# narrow balance beam toward the exit side
	if sx > 0:
		k.floor_box(4.5, 10, 9.25, 10.75, 0.0, STONE, 0.6, ["surface_stone"])
		plat(k, 7.5, 10, 6, 14)
	else:
		k.floor_box(-10, -4.5, 9.25, 10.75, 0.0, STONE, 0.6, ["surface_stone"])
		plat(k, -10, -7.5, 6, 14)
	pillar(k, Vector3(-sx * 3.5, 0, 12), 3.5)
	k.slot("Enemy1", Vector3(0, 0, 4))
	k.slot("Loot1", Vector3(-sx * 3, 0, 9))
	return m


func spire(k: ModuleKit) -> ZoneModule:
	var m := k.begin("fr_spire", ["climb", "path"], 2, S, 1.0)
	plat(k, -6, 6, 0, 8)
	plat(k, -6, 6, 32, 40)
	# main route: a narrow span
	k.floor_box(-0.9, 0.9, 8, 32, 0.0, STONE, 0.6, ["surface_stone"])
	# alt route: climb the spire, run the upper terrace, drop to the step, then down
	Geo.box(k.geo, Vector3(5, 1.6, 9.5), Vector3(3, 3.2, 3), STONE, ["climbable"])
	Geo.box(k.geo, Vector3(5, 4.8, 12), Vector3(3, 3.2, 3), STONE, ["climbable"])
	k.floor_box(3.5, 7.5, 12, 30, 6.4, STONE.darkened(0.1), 0.8, ["surface_stone"])
	Geo.box(k.geo, Vector3(5.5, 1.6, 31), Vector3(3, 3.2, 2), STONE, ["climbable"])
	k.slot("Loot1", Vector3(5.5, 6.4, 22))
	k.slot("Enemy1", Vector3(-3, 0, 36))
	return m


func shrine(k: ModuleKit) -> ZoneModule:
	var m := k.begin("fr_shrine", ["shelter", "rest", "landmark"], 1, S, 1.0)
	plat(k, -7, 7, 0, 20)
	for p in [Vector3(2.5, 0, 6), Vector3(8.5, 0, 6), Vector3(2.5, 0, 14), Vector3(8.5, 0, 14)]:
		pillar(k, p + Vector3(-1.5, 0, 0), 3.6)
	Geo.box(k.geo, Vector3(4, 3.8, 10), Vector3(8, 0.4, 10), STONE.darkened(0.15), ["climbable"])
	k.shelter_volume(Vector3(4, 0, 10), Vector3(5.5, 3.5, 7.5))
	k.slot("Loot1", Vector3(4, 0, 10))
	k.slot("Enemy1", Vector3(-4, 0, 16))
	return m


func wallrun_gap(k: ModuleKit) -> ZoneModule:
	var m := k.begin("fr_wallrun_gap", ["path"], 2, S, 0.9)
	plat(k, -6, 6, 0, 12)
	plat(k, -6, 6, 22, 40)
	Geo.box(k.geo, Vector3(-4.3, 3.0, 17), Vector3(0.6, 6.0, 14), Color(0.4, 0.5, 0.7), ["runnable"])
	# slower route: a broken beam with a jumpable 2.4 m gap
	k.floor_box(3.2, 4.8, 12, 16, 0.0, STONE, 0.6, ["surface_stone"])
	k.floor_box(3.2, 4.8, 18.4, 22, 0.0, STONE, 0.6, ["surface_stone"])
	var h := k.hidden()
	Geo.box(h, Vector3(0, -0.2, 17), Vector3(1.2, 0.3, 10.5), k.b.trunk_color, ["surface_wood"])
	k.hidden_marks(h, [Vector3(0, 0.3, 11.5), Vector3(0, 0.3, 22.5)])
	k.label(Vector3(-3.8, 6.8, 17), "wall-run")
	k.route([Vector3(4, 0, 8), Vector3(4, 0, 15.5), Vector3(4, 0, 19.5), Vector3(4, 0, 24), Vector3(0, 0, 40)])
	k.slot("Enemy1", Vector3(2, 0, 30))
	k.slot("Loot1", Vector3(-4, 0, 36))
	return m


func sky_bridge(k: ModuleKit) -> ZoneModule:
	var m := k.begin("fr_sky_bridge", ["bridge"], 2, S, 0.8)
	plat(k, -7, 7, 0, 12)
	plat(k, -7, 7, 28, 40)
	k.floor_box(-1.6, 1.6, 12, 28, 0.0, k.b.trunk_color, 0.4, ["surface_wood"])
	for side in [-1.0, 1.0]:
		Geo.box(k.geo, Vector3(side * 1.7, 0.5, 20), Vector3(0.12, 1.0, 16), k.b.trunk_color.darkened(0.2))
	pillar(k, Vector3(-3, 0, 11), 4.0)
	pillar(k, Vector3(3, 0, 11), 4.0)
	k.slot("Toll1", Vector3(0, 0, 9.5), 0.0)
	k.slot("Loot1", Vector3(5, 0, 34))
	k.slot("Enemy1", Vector3(-4, 0, 36))
	return m


func islands(k: ModuleKit) -> ZoneModule:
	var m := k.begin("fr_islands", ["stealth", "path"], 1, S, 1.0)
	plat(k, -3, 3, 0, 5)
	plat(k, -5, 1, 7, 11)
	plat(k, -1.5, 5, 12.6, 16.5)
	plat(k, -3, 3, 18, 20)
	k.grass(Vector3(-2, 0, 9), Vector2(5, 3.5), 14)
	k.grass(Vector3(3, 0, 14.6), Vector2(5, 3.2), 14)
	k.slot("Enemy1", Vector3(3, 0, 15))
	k.slot("Loot1", Vector3(-4, 0, 9))
	k.route([Vector3(0, 0, 4), Vector3(-1, 0, 9), Vector3(0.5, 0, 14), Vector3(0, 0, 17.5), Vector3(0, 0, 20)])
	return m


func station(k: ModuleKit) -> ZoneModule:
	var m := k.begin("fr_station", ["station"], 1, S, 1.0)
	k.floor_box(-10, 10, 0, 20, 0.0, k.b.path_color, 1.6, ["surface_stone"])
	k.station()
	pillar(k, Vector3(-8, 0, 4), 5.0)
	pillar(k, Vector3(-8, 0, 16), 5.0)
	return m
