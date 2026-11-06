extends CanvasLayer
## Debug overlay (F3): FPS, zone, seed, biome, time, weather, courier state, enemy states (also as
## labels over enemies) and the scent trail drawn in the world.
## Cheats: F5 god mode, F6 spawn enemy (cycles types), F7 force storm, F8 teleport to zone N,
## F9 jump to the next zone.

const SPAWN_TYPES := ["hound", "scavenger", "tollkeeper", "rider", "watchtower"]

var _root: Control
var _text: Label
var _tp_box: LineEdit
var _spawn_idx: int = 0
var _scent_mm: MultiMeshInstance3D
var _scent_timer: float = 0.0


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UITheme.get_theme()
	add_child(_root)
	var bg := PanelContainer.new()
	bg.position = Vector2(20, 170)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bg)
	_text = UITheme.label("", 14, Color(0.8, 1.0, 0.8))
	bg.add_child(_text)
	_tp_box = LineEdit.new()
	_tp_box.placeholder_text = "Teleport to zone # (Enter)"
	_tp_box.custom_minimum_size = Vector2(300, 40)
	_tp_box.set_anchors_preset(Control.PRESET_CENTER)
	_tp_box.position = Vector2(-150, -20)
	_tp_box.visible = false
	_tp_box.text_submitted.connect(_on_tp_submitted)
	_root.add_child(_tp_box)
	_root.visible = Game.debug_overlay


func _world() -> GameWorld:
	return get_tree().get_first_node_in_group("world") as GameWorld


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_overlay"):
		Game.debug_overlay = not Game.debug_overlay
		_root.visible = Game.debug_overlay
		if not Game.debug_overlay and _scent_mm:
			_scent_mm.visible = false
	elif event.is_action_pressed("debug_god"):
		Game.god_mode = not Game.god_mode
		Events.notify.emit("God mode " + ("ON" if Game.god_mode else "OFF"))
	elif event.is_action_pressed("debug_spawn"):
		spawn_enemy(SPAWN_TYPES[_spawn_idx % SPAWN_TYPES.size()])
		_spawn_idx += 1
	elif event.is_action_pressed("debug_storm"):
		force_storm()
	elif event.is_action_pressed("debug_teleport"):
		_tp_box.visible = true
		_root.visible = true
		_tp_box.text = ""
		_tp_box.grab_focus()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event.is_action_pressed("debug_next_zone"):
		teleport_to_zone(Game.current_zone + 1)


func _on_tp_submitted(t: String) -> void:
	_tp_box.visible = false
	_root.visible = Game.debug_overlay
	_tp_box.release_focus()
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if t.is_valid_int():
		teleport_to_zone(maxi(int(t) - 1, 0))


## Moves the courier to the relay station at the start of zone `zone` (0-based).
func teleport_to_zone(zone: int) -> void:
	var w := _world()
	if w == null:
		return
	if w.weather and w.weather.has_method("end_storm"):
		w.weather.end_storm()
	Game.last_station = zone
	if not Game.activated_stations.has(zone):
		Game.activated_stations.append(zone)
	Game.highest_zone = maxi(Game.highest_zone, zone)
	w.respawn_courier()
	Events.notify.emit("Teleported to Zone %d" % (zone + 1))


func spawn_enemy(type: String) -> void:
	var w := _world()
	var c := Perception.courier()
	if w == null or c == null:
		return
	var pos := c.global_position + c.facing * 8.0 + Vector3.UP * 0.5
	var e := w.enemy_spawner.debug_spawn(type, pos)
	Events.notify.emit("Spawned %s" % type if e else "Could not spawn %s" % type)


func force_storm() -> void:
	var w := _world()
	if w and w.weather:
		if w.weather.active:
			w.weather.end_storm()
			Events.notify.emit("Storm cleared")
		else:
			w.weather.start_storm("", true)


func _process(delta: float) -> void:
	if not Game.debug_overlay:
		return
	var c := Perception.courier()
	var w := _world()
	var lines: PackedStringArray = []
	lines.append("FPS %d   (frame %.1f ms)   draw calls %d" % [Engine.get_frames_per_second(), delta * 1000.0, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)])
	lines.append("Seed %d   Zone %d (index %d, seed %d)   biome %s   Long Road +%d" % [Game.world_seed, Game.current_zone + 1, Game.current_zone, Game.zone_seed(Game.current_zone), BiomeDB.for_zone(Game.current_zone).id, Game.loop_index(Game.current_zone)])
	lines.append("Time of day %.2f %s   momentum %d   last relay %d   corpses %d   god %s" % [Game.time_of_day, "(night)" if Game.is_night() else "", Game.momentum, Game.last_station, Game.corpses.size(), "ON" if Game.god_mode else "off"])
	if w:
		lines.append("Loaded zones %s   origin cell %s   difficulty: groups %d hp x%.2f storm %.0f%% toll %d" % [str(w.streamer.loaded.keys()), str(w.streamer.origin_cell), Difficulty.enemy_groups(Game.current_zone), Difficulty.enemy_hp_mult(Game.current_zone), Difficulty.storm_chance(Game.current_zone) * 100.0, Difficulty.toll_price(Game.current_zone)])
		if w.weather:
			lines.append("Weather: %s %s  intensity %.2f  front %.0f m  visibility x%.2f  scent %s" % ["STORM" if w.weather.active else "clear", w.weather.kind if w.weather.active else "", w.weather.intensity, w.weather.front_progress, w.weather.visibility_mult(), "off" if w.weather.scent_disabled() else "on"])
	if c:
		lines.append("Courier %s  state %s  pos %s  vel %.1f  stamina %d/%d  hp %d  scent pts %d  sheltered %s" % [Game.courier.full_name, Courier.State.keys()[c.state], str(c.global_position.snapped(Vector3.ONE * 0.1)), Vector2(c.velocity.x, c.velocity.z).length(), int(c.stamina), int(c.max_stamina), int(Game.courier.hp), c.scent.size(), c.is_sheltered()])
	var enemies: Array = []
	for n in get_tree().get_nodes_in_group("enemy") + get_tree().get_nodes_in_group("watchtower"):
		if c:
			enemies.append([(n as Node3D).global_position.distance_to(c.global_position), n])
	enemies.sort_custom(func(a, b): return a[0] < b[0])
	lines.append("Enemies loaded: %d" % enemies.size())
	for i in mini(enemies.size(), 10):
		var e: Node = enemies[i][1]
		lines.append("  %-12s %-14s %5.1f m" % [e.get_class() if e.get_script() == null else String(e.get_script().get_global_name()), e.state_name(), enemies[i][0]])
	lines.append("F3 overlay  F5 god  F6 spawn (%s next)  F7 storm  F8 teleport  F9 next zone" % SPAWN_TYPES[_spawn_idx % SPAWN_TYPES.size()])
	_text.text = "\n".join(lines)
	_scent_timer -= delta
	if _scent_timer <= 0.0 and c:
		_scent_timer = 0.2
		_draw_scent(c)


func _draw_scent(c: Courier) -> void:
	if _scent_mm == null or not is_instance_valid(_scent_mm):
		_scent_mm = MultiMeshInstance3D.new()
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		var sm := SphereMesh.new()
		sm.radius = 0.15
		sm.height = 0.3
		sm.radial_segments = 6
		sm.rings = 3
		mm.mesh = sm
		mm.instance_count = 60
		_scent_mm.multimesh = mm
		var mat := StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo = true
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_scent_mm.material_override = mat
		var parent: Node = get_tree().get_first_node_in_group("transient")
		if parent == null:
			parent = get_tree().current_scene
		parent.add_child(_scent_mm)
		_scent_mm.top_level = true
	_scent_mm.visible = true
	var pts := c.scent.points()
	var mm := _scent_mm.multimesh
	mm.visible_instance_count = pts.size()
	for i in pts.size():
		var p: Dictionary = pts[i]
		var s := clampf(float(p.strength), 1.0, 3.0)
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * s), (p.pos as Vector3) + Vector3.UP * 0.3))
		var age := float(i) / maxf(pts.size(), 1)
		mm.set_instance_color(i, Color(1.0, 0.4 + 0.5 * age, 0.1, 1.0))
