extends RefCounted
## Greywood Forest modules: trees, streams, hounds — the gentle intro.

const L := ZoneModule.Exit.LEFT
const R := ZoneModule.Exit.RIGHT
const S := ZoneModule.Exit.STRAIGHT


func modules(k: ModuleKit) -> Array:
	return [trail(k), trail_long(k), bend(k, L), bend(k, R), stream(k), climb_rocks(k),
		shelter_hut(k), overhang(k), hollow(k), gorge_bridge(k), landmark(k), station(k)]


func _side_trees(k: ModuleKit, z0: float, z1: float, step: float = 4.5) -> void:
	var z := z0
	var i := 0
	while z < z1:
		var off := 0.8 if i % 2 == 0 else -0.6
		k.tree(Vector3(-8.0 + off, 0, z), 0.9 + 0.2 * (i % 3))
		k.tree(Vector3(8.2 - off, 0, z + 2.0), 0.85 + 0.25 * ((i + 1) % 3))
		z += step
		i += 1


func trail(k: ModuleKit) -> ZoneModule:
	var m := k.begin("gw_trail", ["path"], 1, S, 1.4)
	k.full_floor()
	k.path_strip([Vector3(0, 0, 0), Vector3(-1.5, 0, 8), Vector3(1.0, 0, 14), Vector3(0, 0, 20)])
	_side_trees(k, 1.0, 20.0)
	k.log_obstacle(Vector3(-2.0, 0, 10), 9.0, PI * 0.5 + 0.1, 0.75)
	k.rock(Vector3(4.0, 0, 15), Vector3(1.6, 1.0, 1.4))
	k.rock(Vector3(-5.5, 0, 4), Vector3(1.2, 0.6, 1.0))
	k.slot("Enemy1", Vector3(4.5, 0, 6))
	k.slot("Loot1", Vector3(-6.0, 0, 16))
	return m


func trail_long(k: ModuleKit) -> ZoneModule:
	var m := k.begin("gw_trail_long", ["path", "chase_open"], 2, S, 1.0)
	k.full_floor()
	k.path_strip([Vector3(0, 0, 0), Vector3(3, 0, 12), Vector3(-3, 0, 26), Vector3(0, 0, 40)])
	_side_trees(k, 1.0, 40.0, 5.0)
	for p in [Vector3(-3, 0, 8), Vector3(4, 0, 20), Vector3(-2, 0, 31)]:
		k.rock(p, Vector3(1.8, 0.9, 1.5))
	k.log_obstacle(Vector3(1.5, 0, 24), 7.0, PI * 0.5 - 0.2, 0.8)
	k.grass(Vector3(-5.5, 0, 16), Vector2(4, 8), 24)
	k.slot("Enemy1", Vector3(-4, 0, 14))
	k.slot("Enemy2", Vector3(4, 0, 30))
	k.slot("Loot1", Vector3(6, 0, 36))
	return m


func bend(k: ModuleKit, dir: int) -> ZoneModule:
	var sx := 1.0 if dir == L else -1.0
	var m := k.begin("gw_bend_left" if dir == L else "gw_bend_right", ["path"], 1, dir, 1.3)
	k.full_floor()
	k.path_strip([Vector3(0, 0, 0), Vector3(0, 0, 8), Vector3(sx * 4, 0, 10), Vector3(sx * 10, 0, 10)])
	# outer corner: dense trees
	for p in [Vector3(-7, 0, 6), Vector3(-7, 0, 13), Vector3(-5, 0, 17.5), Vector3(1, 0, 17.5), Vector3(6, 0, 17)]:
		k.tree(Vector3(p.x * sx, 0, p.z), 1.1)
	# inner corner boulder
	k.rock(Vector3(sx * 6.5, 0, 3.5), Vector3(4.5, 2.6, 4.5), true)
	k.slot("Enemy1", Vector3(-sx * 4, 0, 14))
	k.slot("Loot1", Vector3(sx * 8, 0, 1.5))
	return m


func stream(k: ModuleKit) -> ZoneModule:
	var m := k.begin("gw_stream", ["path"], 2, S, 1.1)
	# banks and a lowered stream bed across the module (z 14..26)
	k.floor_box(-10, 10, 0, 14)
	k.floor_box(-10, 10, 26, 40)
	k.floor_box(-10, 10, 14, 26, -1.2, k.b.path_color.darkened(0.3))
	k.water(Vector3(0, -1.2, 20), Vector2(20, 12), 0.7, 2.6)
	# log bridge
	Geo.box(k.geo, Vector3(-4, -0.05, 20), Vector3(0.9, 0.5, 13.5), k.b.trunk_color, ["surface_wood"])
	k.path_strip([Vector3(0, 0, 0), Vector3(-4, 0, 10)])
	k.path_strip([Vector3(-4, 0, 30), Vector3(0, 0, 40)])
	_side_trees(k, 2.0, 12.0)
	_side_trees(k, 28.0, 40.0)
	# hidden stepping stones on the right
	var h := k.hidden()
	for i in 5:
		Geo.box(h, Vector3(4.5 + (i % 2) * 0.6, -0.5, 15.0 + i * 2.5), Vector3(1.2, 1.0, 1.2), k.b.rock_color.lightened(0.1), ["surface_stone"])
	k.hidden_marks(h, [Vector3(4.5, 0.2, 13.5), Vector3(4.8, 0.2, 27.0)])
	k.slot("Enemy1", Vector3(5, 0, 6))
	k.slot("Enemy2", Vector3(-5, 0, 33))
	k.slot("Loot1", Vector3(7, 0, 36))
	return m


func climb_rocks(k: ModuleKit) -> ZoneModule:
	var m := k.begin("gw_climb_rocks", ["climb", "path"], 2, S, 1.0)
	k.full_floor()
	# main route on the left (x -10..-2)
	k.path_strip([Vector3(0, 0, 0), Vector3(-5.5, 0, 8), Vector3(-5.5, 0, 32), Vector3(0, 0, 40)])
	# outcrop: tier 1 (3.2 m) and tier 2 (6.4 m), climbable faces toward the entry
	k.rock(Vector3(4.5, 0, 19), Vector3(9, 3.2, 22), true)
	k.rock(Vector3(5.0, 3.2, 22), Vector3(7, 3.2, 12), true)
	# top plateau loot (reward for the climb), drop off at the far end onto a step
	k.rock(Vector3(4.5, 0, 31.5), Vector3(5, 1.6, 3), true)
	k.label(Vector3(4.5, 8.5, 22), "^ climb")
	k.tree(Vector3(-9, 0, 4), 1.0)
	k.tree(Vector3(-9, 0, 36), 1.1)
	k.tree(Vector3(-1.5, 0, 22), 0.8)
	k.slot("Loot1", Vector3(5.0, 6.4, 23))
	k.slot("Enemy1", Vector3(-6, 0, 20))
	return m


func shelter_hut(k: ModuleKit) -> ZoneModule:
	var m := k.begin("gw_shelter_hut", ["shelter", "rest"], 1, S, 1.0)
	k.full_floor()
	k.path_strip([Vector3(0, 0, 0), Vector3(-2, 0, 10), Vector3(0, 0, 20)])
	k.hut(Vector3(5.5, 0, 10), PI * 0.5)
	_side_trees(k, 2.0, 20.0, 7.0)
	k.slot("Loot1", Vector3(5.5, 0, 10.5))
	k.slot("Enemy1", Vector3(-5, 0, 16))
	return m


func overhang(k: ModuleKit) -> ZoneModule:
	var m := k.begin("gw_overhang", ["shelter", "path"], 1, S, 0.9)
	k.full_floor()
	k.path_strip([Vector3(0, 0, 0), Vector3(1.5, 0, 10), Vector3(0, 0, 20)])
	k.overhang(Vector3(-5.5, 0, 10), PI * 0.5)
	k.tree(Vector3(7, 0, 5), 1.1)
	k.tree(Vector3(8, 0, 14), 1.0)
	k.rock(Vector3(5, 0, 17), Vector3(1.4, 0.8, 1.4))
	k.slot("Enemy1", Vector3(5, 0, 9))
	k.slot("Loot1", Vector3(-5.5, 0, 10))
	return m


func hollow(k: ModuleKit) -> ZoneModule:
	var m := k.begin("gw_hollow", ["stealth", "path"], 1, S, 1.0)
	k.full_floor()
	k.path_strip([Vector3(0, 0, 0), Vector3(0, 0, 20)])
	k.grass(Vector3(-5, 0, 10), Vector2(6, 16), 40)
	k.grass(Vector3(5, 0, 10), Vector2(6, 16), 40)
	k.grass(Vector3(0, 0, 10), Vector2(3, 6), 14)
	k.tree(Vector3(-8.5, 0, 3), 1.2)
	k.tree(Vector3(8.5, 0, 17), 1.2)
	k.rock(Vector3(3, 0, 4), Vector3(1.6, 1.0, 2.0))
	k.slot("Enemy1", Vector3(4, 0, 14))
	k.slot("Loot1", Vector3(-6, 0, 4))
	return m


func gorge_bridge(k: ModuleKit) -> ZoneModule:
	var m := k.begin("gw_gorge_bridge", ["bridge"], 2, S, 0.8, 2)
	k.floor_box(-10, 10, 0, 12)
	k.floor_box(-10, 10, 28, 40)
	k.floor_box(-10, 10, 12, 28, -9.0, k.b.rock_color.darkened(0.35))
	# chasm walls are climbable rubble steps so a fall is never a soft-lock
	for i in 8:
		Geo.box(k.geo, Vector3(-8.5, -9.0 + (i + 1) * 0.5, 13.0 + i * 1.6), Vector3(2.5, (i + 1) * 1.0, 1.6), k.b.rock_color, ["climbable"])
	Geo.box(k.geo, Vector3(-8.5, -4.5, 26.2), Vector3(2.5, 9.0, 1.6), k.b.rock_color, ["climbable"])
	k.water(Vector3(0, -9.0, 20), Vector2(20, 16), 0.4, 1.4)
	# the bridge
	Geo.box(k.geo, Vector3(0, -0.15, 20), Vector3(4, 0.3, 16.5), k.b.trunk_color, ["surface_wood"])
	for side in [-1.0, 1.0]:
		Geo.box(k.geo, Vector3(side * 2.1, 0.5, 20), Vector3(0.15, 1.0, 16.5), k.b.trunk_color.darkened(0.2))
	# hidden fallen trunk across on the right
	var h := k.hidden()
	Geo.box(h, Vector3(7, -0.2, 20), Vector3(1.0, 0.8, 17.5), k.b.trunk_color.lightened(0.1), ["surface_wood"])
	k.hidden_marks(h, [Vector3(7, 0.4, 11), Vector3(7, 0.4, 29)])
	k.tree(Vector3(-7, 0, 4), 1.0)
	k.tree(Vector3(7.5, 0, 34), 1.1)
	k.slot("Toll1", Vector3(0, 0, 9.5), 0.0)
	k.slot("Loot1", Vector3(-6.5, -9.0, 22))
	k.slot("Enemy1", Vector3(5, 0, 34))
	return m


func landmark(k: ModuleKit) -> ZoneModule:
	var m := k.begin("gw_old_tree", ["landmark", "path"], 1, S, 0.6)
	k.full_floor()
	k.path_strip([Vector3(0, 0, 0), Vector3(-4, 0, 10), Vector3(0, 0, 20)])
	Geo.cylinder(k.geo, Vector3(4.5, 7, 10), 2.4, 14, k.b.trunk_color.darkened(0.2), ["climbable"])
	Geo.deco_cone(k.geo, Vector3(4.5, 14, 10), 7.0, 8.0, k.b.foliage_color.darkened(0.1))
	for i in 6:
		var a := float(i) / 6.0 * TAU
		k.rock(Vector3(4.5 + cos(a) * 5.5, 0, 10 + sin(a) * 5.5), Vector3(0.9, 1.8, 0.9))
	k.slot("Loot1", Vector3(4.5, 0, 6.5))
	k.slot("Enemy1", Vector3(-5, 0, 16))
	return m


func station(k: ModuleKit) -> ZoneModule:
	var m := k.begin("gw_station", ["station"], 1, S, 1.0)
	k.full_floor()
	k.path_strip([Vector3(0, 0, 0), Vector3(0, 0, 20)])
	k.station()
	k.tree(Vector3(-8, 0, 3), 1.0)
	k.tree(Vector3(-8, 0, 17), 1.0)
	return m
