extends RefCounted
## Storm Plains: open grass, riders, frequent lightning storms. Lone trees and hedges beat riders.

const L := ZoneModule.Exit.LEFT
const R := ZoneModule.Exit.RIGHT
const S := ZoneModule.Exit.STRAIGHT

const FENCE := Color(0.45, 0.36, 0.25)


func modules(k: ModuleKit) -> Array:
	return [meadow(k), meadow_long(k), bend(k, L), bend(k, R), stone_ridge(k), windmill(k),
		creek(k), hedgerows(k), overhang(k), station(k)]


func fence(k: ModuleKit, from: Vector3, to: Vector3) -> void:
	var d := to - from
	var n := int(d.length() / 2.5)
	for i in n + 1:
		var p := from + d * (float(i) / maxf(n, 1))
		Geo.box(k.geo, p + Vector3(0, 0.6, 0), Vector3(0.2, 1.2, 0.2), FENCE, ["surface_wood"])
	var mid := (from + to) * 0.5
	var rail := Geo.deco_box(k.geo, mid + Vector3(0, 0.9, 0), Vector3(0.08, 0.1, d.length()), FENCE)
	rail.rotation.y = atan2(d.x, d.z)


func meadow(k: ModuleKit) -> ZoneModule:
	var m := k.begin("sp_meadow", ["path", "chase_open"], 1, S, 1.4)
	k.full_floor()
	k.path_strip([Vector3(0, 0, 0), Vector3(2, 0, 10), Vector3(0, 0, 20)], 2.5)
	k.tree(Vector3(-6, 0, 8), 1.2)
	k.tree(Vector3(7, 0, 15), 1.0)
	k.grass(Vector3(-5, 0, 15), Vector2(5, 6), 20)
	k.rock(Vector3(5, 0, 5), Vector3(1.5, 0.8, 1.2))
	k.slot("Open1", Vector3(0, 0, 10), 0.0)
	k.slot("Enemy1", Vector3(6, 0, 4))
	k.slot("Loot1", Vector3(-7, 0, 3))
	return m


func meadow_long(k: ModuleKit) -> ZoneModule:
	var m := k.begin("sp_meadow_long", ["path", "chase_open"], 2, S, 1.2)
	k.full_floor()
	k.path_strip([Vector3(0, 0, 0), Vector3(-3, 0, 14), Vector3(3, 0, 28), Vector3(0, 0, 40)], 2.5)
	for p in [Vector3(-6, 0, 6), Vector3(5, 0, 18), Vector3(-5, 0, 30), Vector3(7, 0, 36)]:
		k.tree(p, 1.1)
	k.grass(Vector3(5, 0, 8), Vector2(6, 8), 24)
	k.grass(Vector3(-5, 0, 22), Vector2(6, 10), 28)
	fence(k, Vector3(-9, 0, 34), Vector3(-2, 0, 38))
	k.slot("Open1", Vector3(0, 0, 12), 0.0)
	k.slot("Open2", Vector3(0, 0, 30), PI)
	k.slot("Enemy1", Vector3(5, 0, 26))
	k.slot("Loot1", Vector3(-7, 0, 15))
	return m


func bend(k: ModuleKit, dir: int) -> ZoneModule:
	var sx := 1.0 if dir == L else -1.0
	var m := k.begin("sp_bend_left" if dir == L else "sp_bend_right", ["path"], 1, dir, 1.3)
	k.full_floor()
	k.path_strip([Vector3(0, 0, 0), Vector3(0, 0, 7), Vector3(sx * 4, 0, 10), Vector3(sx * 10, 0, 10)], 2.5)
	fence(k, Vector3(-sx * 7, 0, 2), Vector3(-sx * 7, 0, 16))
	fence(k, Vector3(-sx * 6, 0, 17), Vector3(sx * 8, 0, 17))
	k.tree(Vector3(sx * 6, 0, 4), 1.3)
	k.slot("Enemy1", Vector3(-sx * 3, 0, 13))
	k.slot("Loot1", Vector3(sx * 8, 0, 2))
	return m


func stone_ridge(k: ModuleKit) -> ZoneModule:
	var m := k.begin("sp_stone_ridge", ["climb", "path"], 2, S, 1.0)
	k.full_floor()
	k.path_strip([Vector3(0, 0, 0), Vector3(-5, 0, 10), Vector3(-5, 0, 30), Vector3(0, 0, 40)], 2.5)
	# a ridge of stacked stones along the right: climb up (3.0 m) and run the top
	k.rock(Vector3(5, 0, 20), Vector3(5, 3.0, 26), true)
	k.rock(Vector3(5.5, 3.0, 14), Vector3(3, 2.4, 6), true)
	k.rock(Vector3(5, 0, 34.5), Vector3(4, 1.5, 3), true)
	k.tree(Vector3(-8, 0, 20), 1.2)
	k.slot("Open1", Vector3(-4, 0, 20), 0.0)
	k.slot("Loot1", Vector3(5.5, 5.4, 14))
	k.slot("Enemy1", Vector3(-6, 0, 34))
	return m


func windmill(k: ModuleKit) -> ZoneModule:
	var m := k.begin("sp_windmill", ["shelter", "landmark", "rest"], 1, S, 1.0)
	k.full_floor()
	k.path_strip([Vector3(0, 0, 0), Vector3(-2, 0, 10), Vector3(0, 0, 20)], 2.5)
	k.hut(Vector3(-6, 0, 12), -PI * 0.5, Color(0.55, 0.45, 0.32))
	# windmill tower: a tall climbable lightning rod
	Geo.box(k.geo, Vector3(6, 4.5, 8), Vector3(3, 9, 3), Color(0.6, 0.55, 0.45), ["climbable"])
	for i in 4:
		var blade := Geo.deco_box(k.geo, Vector3(6, 8.5, 6.3), Vector3(0.5, 6.0, 0.15), Color(0.8, 0.75, 0.65))
		blade.rotation.z = float(i) * PI * 0.25
	k.slot("Loot1", Vector3(-6, 0, 12))
	k.slot("Open1", Vector3(3, 0, 16), 0.0)
	return m


func creek(k: ModuleKit) -> ZoneModule:
	var m := k.begin("sp_creek", ["path"], 1, S, 1.0)
	k.floor_box(-10, 10, 0, 7)
	k.floor_box(-10, 10, 13, 20)
	k.floor_box(-10, 10, 7, 13, -1.0, k.b.path_color.darkened(0.3))
	k.water(Vector3(0, -1.0, 10), Vector2(20, 6), 0.5, 2.3)
	Geo.box(k.geo, Vector3(2, -0.1, 10), Vector3(2.5, 0.3, 7), Color(0.45, 0.35, 0.22), ["surface_wood"])
	k.path_strip([Vector3(0, 0, 0), Vector3(2, 0, 6)], 2.5)
	k.path_strip([Vector3(2, 0, 14), Vector3(0, 0, 20)], 2.5)
	k.grass(Vector3(-6, 0, 3.5), Vector2(6, 5), 16)
	k.tree(Vector3(7, 0, 16), 1.1)
	k.slot("Enemy1", Vector3(-5, 0, 16))
	k.slot("Loot1", Vector3(7, 0, 3))
	return m


func hedgerows(k: ModuleKit) -> ZoneModule:
	var m := k.begin("sp_hedgerows", ["stealth", "path"], 1, S, 1.0)
	k.full_floor()
	k.path_strip([Vector3(0, 0, 0), Vector3(0, 0, 20)], 2.5)
	var hedge := k.b.foliage_color.darkened(0.2)
	for row in 3:
		var z := 4.0 + row * 6.0
		var gap := -3.0 if row % 2 == 0 else 3.0
		Geo.box(k.geo, Vector3(gap - 6.5, 1.1, z), Vector3(9, 2.2, 1.2), hedge)
		Geo.box(k.geo, Vector3(gap + 6.5, 1.1, z), Vector3(9, 2.2, 1.2), hedge)
	k.grass(Vector3(-6, 0, 7), Vector2(5, 4), 14)
	k.grass(Vector3(6, 0, 13), Vector2(5, 4), 14)
	k.slot("Enemy1", Vector3(5, 0, 18))
	k.slot("Loot1", Vector3(-8, 0, 18))
	k.route([Vector3(-3, 0, 2), Vector3(-3, 0, 5.5), Vector3(3, 0, 8), Vector3(3, 0, 11.5), Vector3(-3, 0, 14), Vector3(-3, 0, 17.5), Vector3(0, 0, 20)])
	return m


func overhang(k: ModuleKit) -> ZoneModule:
	var m := k.begin("sp_overhang", ["shelter", "path"], 1, S, 0.8)
	k.full_floor()
	k.path_strip([Vector3(0, 0, 0), Vector3(1.5, 0, 10), Vector3(0, 0, 20)], 2.5)
	k.overhang(Vector3(-5.5, 0, 10), PI * 0.5)
	k.tree(Vector3(7, 0, 6), 1.2)
	k.slot("Open1", Vector3(2, 0, 14), 0.0)
	k.slot("Loot1", Vector3(-5.5, 0, 10))
	return m


func station(k: ModuleKit) -> ZoneModule:
	var m := k.begin("sp_station", ["station"], 1, S, 1.0)
	k.full_floor()
	k.path_strip([Vector3(0, 0, 0), Vector3(0, 0, 20)], 2.5)
	k.station()
	fence(k, Vector3(-8, 0, 2), Vector3(-8, 0, 18))
	return m
