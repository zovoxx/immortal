extends RefCounted
## Ruined Highway: broken concrete, rusted cars, watchtowers, lots of vaulting.

const L := ZoneModule.Exit.LEFT
const R := ZoneModule.Exit.RIGHT
const S := ZoneModule.Exit.STRAIGHT

const RUST := Color(0.55, 0.3, 0.18)
const RUST2 := Color(0.42, 0.33, 0.3)
const CONCRETE := Color(0.62, 0.61, 0.58)


func modules(k: ModuleKit) -> Array:
	return [road(k), road_long(k), bend(k, L), bend(k, R), overpass(k), tunnel(k),
		broken_bridge(k), gas_station(k), wreck_field(k), station(k)]


## Rusted car: 1.1 m body (vaultable) with a cabin on top.
func car(k: ModuleKit, pos: Vector3, yaw: float, color: Color = RUST) -> void:
	var b := Geo.box(k.geo, pos + Vector3(0, 0.55, 0), Vector3(1.9, 1.1, 4.2), color, ["surface_metal"], null, yaw)
	Geo.deco_box(b, Vector3(0, 0.75, 0.3), Vector3(1.6, 0.6, 2.0), color.darkened(0.25))


func barrier(k: ModuleKit, pos: Vector3, length: float, yaw: float = 0.0) -> void:
	Geo.box(k.geo, pos + Vector3(0, 0.45, 0), Vector3(0.6, 0.9, length), CONCRETE, ["surface_stone"], null, yaw)


func lane_marks(k: ModuleKit, z0: float, z1: float) -> void:
	var z := z0 + 1.0
	while z < z1:
		Geo.deco_box(k.geo, Vector3(0, 0.02, z), Vector3(0.2, 0.03, 2.0), Color(0.85, 0.8, 0.5))
		z += 5.0


func road(k: ModuleKit) -> ZoneModule:
	var m := k.begin("hw_road", ["path"], 1, S, 1.4)
	k.full_floor()
	k.floor_box(-7, 7, 0, 20, 0.02, k.b.path_color, 0.1)
	lane_marks(k, 0, 20)
	car(k, Vector3(-3.5, 0, 6), 0.2)
	car(k, Vector3(3.2, 0, 13), -0.4, RUST2)
	barrier(k, Vector3(0.5, 0, 17), 5.0, PI * 0.5)
	barrier(k, Vector3(-8, 0, 10), 14.0)
	barrier(k, Vector3(8, 0, 10), 14.0)
	k.slot("Enemy1", Vector3(5, 0, 4))
	k.slot("Loot1", Vector3(-5.5, 0, 15))
	return m


func road_long(k: ModuleKit) -> ZoneModule:
	var m := k.begin("hw_road_long", ["path", "chase_open"], 2, S, 1.0)
	k.full_floor()
	k.floor_box(-7, 7, 0, 40, 0.02, k.b.path_color, 0.1)
	lane_marks(k, 0, 40)
	for i in 5:
		car(k, Vector3(-4.0 + (i % 3) * 3.5, 0, 6 + i * 7), 0.3 * (i % 2 * 2 - 1), RUST if i % 2 == 0 else RUST2)
	# overturned bus: climbable alt line above the jam
	Geo.box(k.geo, Vector3(6.5, 1.5, 22), Vector3(2.6, 3.0, 11), Color(0.6, 0.5, 0.2), ["climbable", "surface_metal"])
	barrier(k, Vector3(-8.5, 0, 20), 36.0)
	k.slot("Tower1", Vector3(-7.5, 0, 30), 0.0)
	k.slot("Enemy1", Vector3(3, 0, 10))
	k.slot("Enemy2", Vector3(-3, 0, 34))
	k.slot("Loot1", Vector3(6.5, 3.0, 24))
	return m


func bend(k: ModuleKit, dir: int) -> ZoneModule:
	var sx := 1.0 if dir == L else -1.0
	var m := k.begin("hw_bend_left" if dir == L else "hw_bend_right", ["path"], 1, dir, 1.3)
	k.full_floor()
	k.floor_box(-5, 5, 0, 15, 0.02, k.b.path_color, 0.1)
	if sx > 0:
		k.floor_box(5, 10, 5, 15, 0.02, k.b.path_color, 0.1)
	else:
		k.floor_box(-10, -5, 5, 15, 0.02, k.b.path_color, 0.1)
	# outer guardrail
	barrier(k, Vector3(-sx * 7.5, 0, 9), 16.0)
	barrier(k, Vector3(sx * 1.0, 0, 17.5), 15.0, PI * 0.5)
	car(k, Vector3(-sx * 3.5, 0, 14), 0.9 * sx)
	Geo.box(k.geo, Vector3(sx * 7.0, 1.0, 2.5), Vector3(5, 2.0, 4), CONCRETE.darkened(0.1), ["climbable"])
	k.slot("Enemy1", Vector3(sx * 6.5, 0, 12))
	k.slot("Loot1", Vector3(-sx * 6, 0, 3))
	return m


func overpass(k: ModuleKit) -> ZoneModule:
	var m := k.begin("hw_overpass", ["climb", "path"], 2, S, 1.0)
	k.full_floor()
	k.floor_box(-7, 0, 0, 40, 0.02, k.b.path_color, 0.1)
	# collapsed overpass deck above the right side: climb the pillar faces (3.2 m), run the deck
	for z in [8.0, 20.0, 32.0]:
		Geo.box(k.geo, Vector3(5.5, 1.6, z), Vector3(3.0, 3.2, 2.0), CONCRETE, ["climbable"])
	Geo.box(k.geo, Vector3(5.5, 3.45, 21), Vector3(7.0, 0.5, 30), CONCRETE.darkened(0.08), ["climbable", "surface_stone"])
	Geo.box(k.geo, Vector3(5.5, 1.6, 6.9), Vector3(4.0, 3.2, 0.3), CONCRETE.darkened(0.2), ["climbable"])
	# ramp down at the far end
	Geo.ramp(k.geo, Vector3(5.5, 0, 36), 4, 4, 3.4, CONCRETE, null, PI)
	car(k, Vector3(-4, 0, 12), 0.1)
	car(k, Vector3(-2.5, 0, 26), -0.3, RUST2)
	barrier(k, Vector3(-3.5, 0, 34), 4.0, PI * 0.5)
	k.slot("Tower1", Vector3(-8, 0, 20), 0.0)
	k.slot("Enemy1", Vector3(-4, 0, 30))
	k.slot("Loot1", Vector3(6.0, 3.7, 26))
	return m


func tunnel(k: ModuleKit) -> ZoneModule:
	var m := k.begin("hw_tunnel", ["shelter", "stealth"], 1, S, 1.0)
	k.full_floor()
	k.floor_box(-6, 6, 0, 20, 0.02, k.b.path_color, 0.1)
	Geo.box(k.geo, Vector3(-6.5, 2.5, 10), Vector3(1.0, 5.0, 14), CONCRETE)
	Geo.box(k.geo, Vector3(6.5, 2.5, 10), Vector3(1.0, 5.0, 14), CONCRETE)
	Geo.box(k.geo, Vector3(0, 5.25, 10), Vector3(14, 0.5, 14), CONCRETE.darkened(0.1))
	k.shelter_volume(Vector3(0, 0, 10), Vector3(11, 4.8, 13))
	car(k, Vector3(-2.5, 0, 9), 0.05, RUST2)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.7, 0.4)
	lamp.omni_range = 8.0
	lamp.light_energy = 0.8
	lamp.position = Vector3(0, 4.5, 10)
	k.geo.add_child(lamp)
	k.slot("Loot1", Vector3(4, 0, 12))
	k.slot("Enemy1", Vector3(-4, 0, 18))
	return m


func broken_bridge(k: ModuleKit) -> ZoneModule:
	var m := k.begin("hw_broken_bridge", ["bridge"], 2, S, 0.8, 2)
	k.floor_box(-10, 10, 0, 12)
	k.floor_box(-10, 10, 28, 40)
	k.floor_box(-10, 10, 12, 28, -10.0, k.b.rock_color.darkened(0.4))
	for i in 9:
		Geo.box(k.geo, Vector3(8.5, -10.0 + (i + 1) * 0.55, 13.0 + i * 1.6), Vector3(2.5, (i + 1) * 1.1, 1.6), CONCRETE, ["climbable"])
	Geo.box(k.geo, Vector3(8.5, -5.0, 26.6), Vector3(2.5, 10.0, 2.0), CONCRETE, ["climbable"])
	# the surviving deck span
	Geo.box(k.geo, Vector3(-2, -0.25, 20), Vector3(6, 0.5, 16.5), k.b.path_color, ["surface_stone"])
	barrier(k, Vector3(-5.2, 0, 20), 16.0)
	barrier(k, Vector3(1.2, 0, 20), 16.0)
	var h := k.hidden()
	Geo.box(h, Vector3(5.5, -0.2, 20), Vector3(0.8, 0.3, 17), k.b.trunk_color, ["surface_wood"])
	k.hidden_marks(h, [Vector3(5.5, 0.3, 11), Vector3(5.5, 0.3, 29)])
	car(k, Vector3(5, 0, 5), 0.6)
	k.slot("Toll1", Vector3(-2, 0, 9.5), 0.0)
	k.slot("Enemy1", Vector3(4, 0, 34))
	k.slot("Loot1", Vector3(-6, -10.0, 20))
	return m


func gas_station(k: ModuleKit) -> ZoneModule:
	var m := k.begin("hw_gas_station", ["shelter", "landmark", "rest"], 1, S, 0.9)
	k.full_floor()
	k.floor_box(-4, 4, 0, 20, 0.02, k.b.path_color, 0.1)
	# canopy
	for p in [Vector3(3, 0, 6), Vector3(9, 0, 6), Vector3(3, 0, 14), Vector3(9, 0, 14)]:
		Geo.box(k.geo, p + Vector3(0, 2.0, 0), Vector3(0.5, 4.0, 0.5), CONCRETE)
	Geo.box(k.geo, Vector3(6, 4.2, 10), Vector3(8, 0.4, 10), Color(0.75, 0.25, 0.2), ["climbable"])
	k.shelter_volume(Vector3(6, 0, 10), Vector3(6.5, 4.0, 8.5))
	for z in [8.0, 12.0]:
		Geo.box(k.geo, Vector3(6, 0.7, z), Vector3(0.8, 1.4, 0.6), Color(0.8, 0.75, 0.6))
	Geo.box(k.geo, Vector3(-7, 1.5, 12), Vector3(4, 3, 6), CONCRETE.darkened(0.15), ["climbable"])
	car(k, Vector3(-2, 0, 15), 1.2, RUST2)
	k.slot("Loot1", Vector3(6, 0, 10))
	k.slot("Enemy1", Vector3(-5, 0, 4))
	return m


func wreck_field(k: ModuleKit) -> ZoneModule:
	var m := k.begin("hw_wreck_field", ["stealth", "path"], 1, S, 1.0)
	k.full_floor()
	k.floor_box(-7, 7, 0, 20, 0.02, k.b.path_color, 0.1)
	var spots := [Vector3(-5, 0, 3), Vector3(-1, 0, 6), Vector3(4, 0, 4), Vector3(6, 0, 10), Vector3(-6, 0, 11), Vector3(1.5, 0, 13), Vector3(-3, 0, 17), Vector3(5, 0, 17)]
	for i in spots.size():
		car(k, spots[i], float(i) * 0.7, RUST if i % 2 == 0 else RUST2)
	k.grass(Vector3(-7.5, 0, 6), Vector2(3, 8), 18)
	k.grass(Vector3(7.5, 0, 14), Vector2(3, 8), 18)
	k.slot("Enemy1", Vector3(0, 0, 10))
	k.slot("Loot1", Vector3(7.5, 0, 2))
	return m


func station(k: ModuleKit) -> ZoneModule:
	var m := k.begin("hw_station", ["station"], 1, S, 1.0)
	k.full_floor()
	k.floor_box(-3, 3, 0, 20, 0.02, k.b.path_color, 0.1)
	k.station()
	car(k, Vector3(-7, 0, 14), 0.3, RUST2)
	return m
