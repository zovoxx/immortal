extends RefCounted
## Builds placeholder visual scenes (one per object) from primitives.

const BC := preload("res://tools/build_content.gd")

const STONE := Color(0.55, 0.53, 0.5)
const STONE_DARK := Color(0.4, 0.38, 0.36)
const WOOD := Color(0.45, 0.32, 0.2)
const CLOTH := Color(0.7, 0.2, 0.15)


func build_all() -> int:
	var n := 0
	for f in [
		["res://world/station/station_model.tscn", _station],
		["res://world/corpse/corpse_model.tscn", _corpse],
		["res://items/pickup_model.tscn", _pickup],
		["res://items/loot_cache_model.tscn", _loot_cache],
		["res://items/loot_bag_model.tscn", _loot_bag],
		["res://enemies/hound/hound_model.tscn", _hound],
		["res://enemies/scavenger/scavenger_model.tscn", _scavenger],
		["res://enemies/tollkeeper/tollkeeper_model.tscn", _tollkeeper],
		["res://enemies/rider/rider_model.tscn", _rider],
		["res://enemies/watchtower/watchtower_model.tscn", _watchtower],
		["res://world/weather/storm_front_model.tscn", _storm_front],
	]:
		var root: Node3D = f[1].call()
		if BC.save_scene(root, f[0]):
			n += 1
	return n


func _root(scene_name: String) -> Node3D:
	var r := Node3D.new()
	r.name = scene_name
	return r


func _marker(parent: Node, marker_name: String, pos: Vector3) -> Marker3D:
	var m := Marker3D.new()
	m.name = marker_name
	m.position = pos
	parent.add_child(m)
	return m


## Stone hut with a signal fire. Local frame: road runs along Z through x = 0; hut sits at +X.
func _station() -> Node3D:
	var r := _root("StationModel")
	var hut := Vector3(6.0, 0, 0)
	# floor
	Geo.box(r, hut + Vector3(0, 0.1, 0), Vector3(6, 0.2, 6), STONE_DARK, ["surface_stone"])
	# walls (open towards -X, facing the road)
	Geo.box(r, hut + Vector3(2.75, 1.6, 0), Vector3(0.5, 3.2, 6), STONE)
	Geo.box(r, hut + Vector3(0, 1.6, 2.75), Vector3(6, 3.2, 0.5), STONE)
	Geo.box(r, hut + Vector3(0, 1.6, -2.75), Vector3(6, 3.2, 0.5), STONE)
	Geo.box(r, hut + Vector3(-2.75, 2.7, 1.9), Vector3(0.5, 1.0, 2.2), STONE)
	Geo.box(r, hut + Vector3(-2.75, 2.7, -1.9), Vector3(0.5, 1.0, 2.2), STONE)
	Geo.box(r, hut + Vector3(-2.75, 1.0, 2.4), Vector3(0.5, 2.0, 1.2), STONE)
	Geo.box(r, hut + Vector3(-2.75, 1.0, -2.4), Vector3(0.5, 2.0, 1.2), STONE)
	# roof
	Geo.box(r, hut + Vector3(0, 3.4, 0), Vector3(6.8, 0.4, 6.8), WOOD)
	# signal fire tower beside the hut
	var fire := Vector3(2.2, 0, -4.0)
	Geo.box(r, fire + Vector3(0, 0.6, 0), Vector3(1.6, 1.2, 1.6), STONE, ["surface_stone"])
	Geo.deco_box(r, fire + Vector3(0, 1.3, 0), Vector3(1.2, 0.2, 1.2), STONE_DARK)
	_marker(r, "FirePoint", fire + Vector3(0, 1.45, 0))
	# props inside
	Geo.deco_box(r, hut + Vector3(1.2, 0.3, 1.6), Vector3(2.0, 0.2, 0.9), CLOTH)
	_marker(r, "RestPoint", hut + Vector3(1.2, 0.3, 1.6))
	Geo.box(r, hut + Vector3(1.6, 0.45, -1.6), Vector3(1.3, 0.7, 0.8), WOOD)
	_marker(r, "StashPoint", hut + Vector3(1.6, 0.9, -1.6))
	Geo.box(r, hut + Vector3(-0.8, 0.5, -2.0), Vector3(1.8, 0.8, 0.9), WOOD.darkened(0.2))
	Geo.deco_box(r, hut + Vector3(-0.8, 1.0, -2.0), Vector3(0.5, 0.2, 0.3), Color(0.5, 0.5, 0.55))
	_marker(r, "BenchPoint", hut + Vector3(-0.8, 1.0, -2.0))
	_marker(r, "SpawnPoint", Vector3(0, 0.1, 2.0))
	# road marker posts
	for z in [-6.0, 6.0]:
		Geo.box(r, Vector3(-3.0, 0.75, z), Vector3(0.3, 1.5, 0.3), WOOD)
		Geo.deco_box(r, Vector3(-3.0, 1.55, z), Vector3(0.5, 0.15, 0.5), CLOTH)
	return r


## Lying courier body + a cloth flag on a pole visible from far away.
func _corpse() -> Node3D:
	var r := _root("CorpseModel")
	var body := MeshInstance3D.new()
	body.name = "Body"
	var cap := CapsuleMesh.new()
	cap.radius = 0.3
	cap.height = 1.7
	body.mesh = cap
	body.material_override = Geo.mat(Color(0.33, 0.28, 0.24))
	body.rotation = Vector3(PI * 0.5, 0, 0)
	body.position = Vector3(0, 0.3, 0)
	r.add_child(body)
	Geo.deco_box(r, Vector3(0.0, 0.35, -0.55), Vector3(0.45, 0.25, 0.5), Color(0.5, 0.35, 0.2))
	Geo.deco_box(r, Vector3(0.45, 1.5, 0.2), Vector3(0.06, 3.0, 0.06), WOOD)
	var flag := Geo.deco_box(r, Vector3(0.45 + 0.45, 2.7, 0.2), Vector3(0.9, 0.55, 0.03), CLOTH)
	flag.name = "Flag"
	return r


func _pickup() -> Node3D:
	var r := _root("PickupModel")
	var m := Geo.deco_box(r, Vector3(0, 0.2, 0), Vector3(0.35, 0.3, 0.35), Color(0.8, 0.7, 0.4))
	m.name = "Mesh"
	return r


func _loot_cache() -> Node3D:
	var r := _root("LootCacheModel")
	Geo.box(r, Vector3(0, 0.4, 0), Vector3(1.2, 0.8, 0.8), WOOD)
	Geo.deco_box(r, Vector3(0, 0.85, 0), Vector3(1.25, 0.12, 0.85), WOOD.darkened(0.3))
	Geo.deco_box(r, Vector3(0, 0.6, -0.41), Vector3(0.2, 0.2, 0.04), Color(0.85, 0.7, 0.3))
	return r


func _loot_bag() -> Node3D:
	var r := _root("LootBagModel")
	Geo.deco_sphere(r, Vector3(0, 0.25, 0), 0.3, Color(0.4, 0.35, 0.3), null, 0.8)
	Geo.deco_box(r, Vector3(0, 0.55, 0), Vector3(0.1, 0.15, 0.1), Color(0.2, 0.15, 0.1))
	return r


# ------------------------------------------------------------------ enemies

func _hound() -> Node3D:
	var r := _root("HoundModel")
	var fur := Color(0.32, 0.28, 0.25)
	Geo.deco_box(r, Vector3(0, 0.55, 0), Vector3(0.45, 0.45, 1.1), fur)
	Geo.deco_box(r, Vector3(0, 0.75, -0.65), Vector3(0.35, 0.35, 0.4), fur.darkened(0.1))
	Geo.deco_box(r, Vector3(0, 0.68, -0.9), Vector3(0.2, 0.18, 0.25), fur.darkened(0.3))
	var eye := Geo.deco_box(r, Vector3(0, 0.82, -0.86), Vector3(0.3, 0.06, 0.05), Color(1.0, 0.5, 0.1))
	eye.material_override = Geo.mat(Color(1.0, 0.5, 0.1), 0.5, 2.0)
	for p in [Vector3(0.15, 0.2, -0.4), Vector3(-0.15, 0.2, -0.4), Vector3(0.15, 0.2, 0.4), Vector3(-0.15, 0.2, 0.4)]:
		Geo.deco_box(r, p, Vector3(0.1, 0.4, 0.1), fur.darkened(0.2))
	Geo.deco_box(r, Vector3(0, 0.75, 0.65), Vector3(0.08, 0.08, 0.4), fur, null, Vector3(0.6, 0, 0))
	return r


func _scavenger() -> Node3D:
	var r := _root("ScavengerModel")
	var feather := Color(0.12, 0.12, 0.14)
	var body := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.25
	cap.height = 1.0
	body.mesh = cap
	body.material_override = Geo.mat(feather)
	body.position = Vector3(0, 0.6, 0)
	r.add_child(body)
	Geo.deco_sphere(r, Vector3(0, 1.2, -0.05), 0.18, feather)
	Geo.deco_cone(r, Vector3(0, 1.2, -0.3), 0.06, 0.25, Color(0.85, 0.75, 0.3)).rotation.x = -PI * 0.5
	Geo.deco_box(r, Vector3(0, 0.75, 0.25), Vector3(0.5, 0.4, 0.2), Color(0.45, 0.35, 0.25))
	return r


func _tollkeeper() -> Node3D:
	var r := _root("TollkeeperModel")
	var armor := Color(0.35, 0.33, 0.3)
	var body := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.55
	cap.height = 2.3
	body.mesh = cap
	body.material_override = Geo.mat(armor)
	body.position = Vector3(0, 1.15, 0)
	r.add_child(body)
	Geo.deco_box(r, Vector3(0, 2.4, 0), Vector3(0.55, 0.5, 0.55), armor.darkened(0.3))
	Geo.deco_box(r, Vector3(0, 2.4, -0.28), Vector3(0.4, 0.08, 0.04), Color(0.9, 0.7, 0.2))
	var arm := Node3D.new()
	arm.name = "WeaponArm"
	arm.position = Vector3(-0.7, 1.7, 0)
	r.add_child(arm)
	Geo.deco_box(arm, Vector3(0, -0.5, 0), Vector3(0.2, 1.0, 0.2), armor)
	var mace := Geo.deco_box(arm, Vector3(0, -1.2, -0.3), Vector3(0.45, 0.45, 0.7), Color(0.3, 0.3, 0.32))
	mace.name = "Mace"
	var sign_post := Geo.deco_box(r, Vector3(1.0, 1.1, 0), Vector3(0.1, 2.2, 0.1), WOOD)
	sign_post.name = "Post"
	return r


func _rider() -> Node3D:
	var r := _root("RiderModel")
	var horse := Color(0.38, 0.27, 0.18)
	Geo.deco_box(r, Vector3(0, 1.3, 0), Vector3(0.8, 0.8, 2.2), horse)
	Geo.deco_box(r, Vector3(0, 1.9, -1.2), Vector3(0.45, 0.9, 0.5), horse, null, Vector3(-0.5, 0, 0))
	Geo.deco_box(r, Vector3(0, 2.2, -1.55), Vector3(0.35, 0.35, 0.6), horse.darkened(0.2))
	for p in [Vector3(0.3, 0.45, -0.8), Vector3(-0.3, 0.45, -0.8), Vector3(0.3, 0.45, 0.8), Vector3(-0.3, 0.45, 0.8)]:
		Geo.deco_box(r, p, Vector3(0.18, 0.9, 0.18), horse.darkened(0.3))
	var rider := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.3
	cap.height = 1.2
	rider.mesh = cap
	rider.material_override = Geo.mat(Color(0.25, 0.2, 0.3))
	rider.position = Vector3(0, 2.3, 0.1)
	r.add_child(rider)
	Geo.deco_sphere(r, Vector3(0, 3.05, 0.1), 0.2, Color(0.6, 0.5, 0.45))
	Geo.deco_box(r, Vector3(0.45, 2.4, -0.6), Vector3(0.06, 0.06, 2.0), Color(0.6, 0.6, 0.62))
	return r


## Static tower body. The lantern head is built by watchtower.gd at the "LanternPoint" marker.
func _watchtower() -> Node3D:
	var r := _root("WatchtowerModel")
	for p in [Vector3(1, 0, 1), Vector3(-1, 0, 1), Vector3(1, 0, -1), Vector3(-1, 0, -1)]:
		Geo.box(r, p * 1.1 + Vector3(0, 4.0, 0), Vector3(0.3, 8.0, 0.3), WOOD)
	Geo.box(r, Vector3(0, 8.1, 0), Vector3(3.2, 0.3, 3.2), WOOD.darkened(0.2))
	Geo.deco_box(r, Vector3(0, 9.9, 0), Vector3(3.4, 0.25, 3.4), WOOD.darkened(0.4))
	for p in [Vector3(1.5, 9.0, 1.5), Vector3(-1.5, 9.0, 1.5), Vector3(1.5, 9.0, -1.5), Vector3(-1.5, 9.0, -1.5)]:
		Geo.deco_box(r, p, Vector3(0.15, 1.8, 0.15), WOOD)
	Geo.deco_cone(r, Vector3(-1.0, 9.0, 0.8), 0.35, 0.6, Color(0.7, 0.55, 0.2))
	_marker(r, "LanternPoint", Vector3(0, 8.9, 0))
	_marker(r, "BellPoint", Vector3(-1.0, 9.0, 0.8))
	return r


func _storm_front() -> Node3D:
	var r := _root("StormFrontModel")
	var wall := MeshInstance3D.new()
	wall.name = "Wall"
	var bm := BoxMesh.new()
	bm.size = Vector3(120, 60, 4)
	wall.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.12, 0.13, 0.17, 0.55)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	wall.material_override = m
	wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	wall.position = Vector3(0, 25, 0)
	r.add_child(wall)
	return r
