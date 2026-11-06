extends Node3D
## Hand-built movement test course with every obstacle type: vault boxes, slide bars, climbable
## ledges (incl. a shimmy ledge and a stacked tower), wall-run walls, drop towers for fall damage,
## water, tall grass and a shelter. Reachable from the main menu ("Test Course").

const COURIER_SCENE := preload("res://player/courier.tscn")
const HUD_SCENE := preload("res://ui/hud.tscn")

const C_FLOOR := Color(0.32, 0.34, 0.3)
const C_BOX := Color(0.6, 0.45, 0.3)
const C_CLIMB := Color(0.55, 0.5, 0.42)
const C_RUN := Color(0.35, 0.45, 0.6)
const C_BAR := Color(0.7, 0.3, 0.25)
const C_TOWER := Color(0.45, 0.45, 0.5)

var courier: Courier
var hud: Node
var station: RelayStation


func _ready() -> void:
	_build_environment()
	_build_course()
	station = preload("res://world/station/relay_station.tscn").instantiate()
	station.station_index = 0
	add_child(station)
	station.position = Vector3(-14, 0, -12)
	courier = COURIER_SCENE.instantiate()
	courier.data = Game.courier
	add_child(courier)
	courier.global_position = Vector3(0, 0.1, -6)
	courier.camera_rig.face_direction(Vector3.BACK)
	hud = HUD_SCENE.instantiate()
	add_child(hud)
	hud.world = self
	Game.is_running = true
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	add_child(preload("res://ui/pause_menu.tscn").instantiate())
	add_child(preload("res://ui/loot_window.tscn").instantiate())
	var flow := DeathFlow.new()
	flow.world = self
	add_child(flow)
	var drop := Node3D.new()
	drop.name = "Drops"
	drop.add_to_group("drop_parent")
	add_child(drop)
	for c in Game.corpses_in_zone(0):
		spawn_corpse_node(c)
	# a few pickups and a cache to try carry slots
	CourierActions.spawn_pickup(self, "bandage", 1, Vector3(-4, 0.2, -4))
	CourierActions.spawn_pickup(self, "smoke_pot", 1, Vector3(-5, 0.2, -4))
	CourierActions.spawn_pickup(self, "scrap", 3, Vector3(-6, 0.2, -4))
	var cache := LootCache.new()
	cache.cache_id = "test_cache"
	add_child(cache)
	cache.position = Vector3(4, 0, -4)


# --- DeathFlow world interface (the test course is "zone 0" with origin at 0) ---
func zone_of_position(_pos: Vector3) -> int:
	return 0


func to_zone_local(_zone: int, pos: Vector3) -> Vector3:
	return pos


func spawn_corpse_node(data: CorpseData) -> void:
	var c: Corpse = preload("res://world/corpse/corpse.tscn").instantiate()
	c.data = data
	add_child(c)
	c.position = data.local_pos


func respawn_courier() -> void:
	if is_instance_valid(courier):
		courier.queue_free()
	courier = COURIER_SCENE.instantiate()
	courier.data = Game.courier
	add_child(courier)
	courier.global_transform = station.spawn_transform()
	courier.camera_rig.face_direction(Vector3.BACK)


func compass_targets() -> Array:
	return [{"pos": Vector3(0, 0, 60), "label": "▲", "color": UITheme.ACCENT, "dist": true}]


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var mat := ProceduralSkyMaterial.new()
	mat.sky_top_color = Color(0.35, 0.48, 0.65)
	mat.sky_horizon_color = Color(0.7, 0.72, 0.75)
	sky.sky_material = mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_density = 0.004
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.shadow_enabled = true
	add_child(sun)
	Settings.apply_graphics(env, sun, get_viewport())


func _build_course() -> void:
	var g := Node3D.new()
	g.name = "Geometry"
	add_child(g)
	Geo.box(g, Vector3(0, -0.5, 30), Vector3(140, 1, 140), C_FLOOR)
	Geo.label(g, Vector3(0, 3, -2), "RELAY — TEST COURSE", 90)

	# Lane A: vaults (x = 0)
	Geo.label(g, Vector3(0, 2.6, 6), "VAULT (run into them)")
	for i in 4:
		var h: float = [0.5, 0.9, 1.15, 1.6][i]
		Geo.box(g, Vector3(0, h * 0.5, 10 + i * 7), Vector3(3, h, 0.6), C_BOX)
		Geo.label(g, Vector3(2.2, h + 0.4, 10 + i * 7), "%.2fm%s" % [h, "" if h <= 1.2 else " (too tall)"], 40)
	Geo.box(g, Vector3(0, 0.5, 42), Vector3(3, 1.0, 3), C_BOX)
	Geo.label(g, Vector3(2.2, 1.4, 42), "mantle 1.0m", 40)

	# Lane B: slide (x = 12)
	Geo.label(g, Vector3(12, 2.6, 6), "SLIDE (sprint + crouch)")
	Geo.box(g, Vector3(10.4, 0.75, 12), Vector3(0.3, 1.5, 0.3), C_BAR)
	Geo.box(g, Vector3(13.6, 0.75, 12), Vector3(0.3, 1.5, 0.3), C_BAR)
	Geo.box(g, Vector3(12, 1.35, 12), Vector3(3.5, 0.4, 0.3), C_BAR)
	# low tunnel 1.15 m high
	Geo.box(g, Vector3(12, 1.55, 22), Vector3(3.5, 0.8, 6), C_BAR)
	Geo.box(g, Vector3(10.0, 0.6, 22), Vector3(0.4, 1.2, 6), C_BAR)
	Geo.box(g, Vector3(14.0, 0.6, 22), Vector3(0.4, 1.2, 6), C_BAR)

	# Lane C: climbing (x = 24)
	Geo.label(g, Vector3(24, 2.6, 4), "CLIMB (jump at ledges)")
	Geo.box(g, Vector3(24, 1.0, 10), Vector3(4, 2.0, 1.5), C_CLIMB, ["climbable"])
	Geo.box(g, Vector3(24, 1.7, 17), Vector3(4, 3.4, 2.0), C_CLIMB, ["climbable"])
	# shimmy ledge: long wall, pull up only at the far end
	Geo.box(g, Vector3(30, 1.6, 24), Vector3(10, 3.2, 1.0), C_CLIMB, ["climbable"])
	Geo.box(g, Vector3(28, 3.7, 24), Vector3(6, 1.0, 1.0), C_CLIMB)
	Geo.label(g, Vector3(30, 4.8, 24), "shimmy →", 40)
	# stacked tower 3.4 / 6.6 / 9.8
	for i in 3:
		var top := 3.4 + i * 3.2
		Geo.box(g, Vector3(24, top * 0.5, 32 + i * 1.6), Vector3(4, top, 1.6), C_CLIMB, ["climbable"])

	# Lane D: wall-run (x = -14)
	Geo.label(g, Vector3(-14, 2.6, 2), "WALL-RUN (sprint + jump along the blue wall)")
	Geo.ramp(g, Vector3(-14, 0, 0), 4, 8, 3, C_TOWER)
	Geo.box(g, Vector3(-14, 1.5, 10), Vector3(4, 3, 4), C_TOWER)
	Geo.box(g, Vector3(-14, 1.5, 26), Vector3(4, 3, 4), C_TOWER)
	Geo.box(g, Vector3(-16.6, 3.5, 18), Vector3(0.6, 7, 14), C_RUN, ["runnable"])
	Geo.box(g, Vector3(-8.0, 3.5, 34), Vector3(0.6, 7, 12), C_RUN, ["runnable"])

	# Lane E: drop towers (x = -32), climb the stairs and jump off
	Geo.label(g, Vector3(-32, 2.6, -2), "FALL DAMAGE: 5 / 8 / 12 / 17 m drops")
	var step_h := 1.0
	var z := 2.0
	var hgt := 0.0
	while hgt < 17.0:
		hgt += step_h
		Geo.box(g, Vector3(-36, hgt * 0.5, z), Vector3(3, hgt, 1.6), C_TOWER)
		for drop in [5.0, 8.0, 12.0, 17.0]:
			if is_equal_approx(hgt, drop):
				Geo.box(g, Vector3(-33.0, hgt - 0.25, z), Vector3(3.0, 0.5, 1.6), C_BAR)
				Geo.label(g, Vector3(-31.0, hgt + 0.6, z), "%dm" % int(drop), 50)
		z += 1.6

	# Lane F: water, tall grass, shelter, long stamina track (x = 44)
	Geo.label(g, Vector3(44, 2.6, 4), "WATER · TALL GRASS · SHELTER")
	var water := WaterVolume.new()
	water.size = Vector3(8, 1, 10)
	water.base_depth = 0.7
	water.position = Vector3(44, 0.0, 12)
	g.add_child(water)
	var grass := VolumeArea.new()
	grass.kind = "tall_grass"
	grass.size = Vector3(8, 1.4, 8)
	grass.position = Vector3(44, 0, 24)
	g.add_child(grass)
	for i in 40:
		var p := Vector3(44 + randf_range(-3.8, 3.8), 0.55, 24 + randf_range(-3.8, 3.8))
		Geo.deco_box(g, p, Vector3(0.08, 1.1, 0.08), Color(0.55, 0.6, 0.3))
	Geo.box(g, Vector3(44, 3.2, 36), Vector3(7, 0.6, 5), C_TOWER)
	Geo.box(g, Vector3(41, 1.5, 36), Vector3(0.8, 3, 5), C_TOWER)
	var shelter := VolumeArea.new()
	shelter.kind = "shelter"
	shelter.size = Vector3(6, 3, 4.5)
	shelter.position = Vector3(44.5, 0, 36)
	g.add_child(shelter)
	Geo.label(g, Vector3(55, 2.6, 4), "STAMINA TRACK (sprint)")
	for i in 9:
		Geo.box(g, Vector3(55, 0.05, 10 + i * 10), Vector3(3, 0.1, 0.3), C_BAR)
