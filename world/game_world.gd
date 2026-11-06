class_name GameWorld
extends Node3D
## The Long Road: streams zones around the courier, owns the courier/HUD/menus, handles respawn,
## floating-origin rebasing and compass targets.

const COURIER_SCENE := preload("res://player/courier.tscn")
## Rebase the floating origin when the courier is this far from it (metres).
@export var rebase_distance: float = 300.0

var streamer: ZoneStreamer
var courier: Courier
var hud: Node
var env_ctrl: EnvironmentController
var transient: Node3D
var death_flow: DeathFlow
var weather: Node
var enemy_spawner: EnemySpawner
var _zone_check_timer: float = 0.0


func _ready() -> void:
	add_to_group("world")
	Game.is_running = true
	get_tree().paused = false
	Engine.time_scale = 1.0
	env_ctrl = EnvironmentController.new()
	env_ctrl.name = "Environment"
	add_child(env_ctrl)
	streamer = ZoneStreamer.new()
	streamer.name = "Zones"
	streamer.world_seed = Game.world_seed
	add_child(streamer)
	enemy_spawner = EnemySpawner.new()
	enemy_spawner.name = "EnemySpawner"
	add_child(enemy_spawner)
	streamer.on_zone_added.append(enemy_spawner.populate_zone)
	transient = Node3D.new()
	transient.name = "Transient"
	transient.add_to_group("drop_parent")
	transient.add_to_group("transient")
	add_child(transient)
	_add_optional("res://world/weather/weather_manager.gd", "Weather")
	hud = preload("res://ui/hud.tscn").instantiate()
	hud.world = self
	add_child(hud)
	add_child(preload("res://ui/pause_menu.tscn").instantiate())
	add_child(preload("res://ui/loot_window.tscn").instantiate())
	for p in ["res://ui/station_menu.tscn", "res://ui/message_popup.tscn", "res://ui/debug_overlay.tscn"]:
		if ResourceLoader.exists(p):
			add_child(load(p).instantiate())
	death_flow = DeathFlow.new()
	death_flow.world = self
	add_child(death_flow)
	# start at the last station
	var zone := ZoneStreamer.station_zone(Game.last_station)
	streamer.origin_cell = ZoneGenerator.start_cell(Game.world_seed, zone)
	streamer.ensure(zone)
	Game.current_zone = zone
	Game.highest_zone = maxi(Game.highest_zone, zone)
	Game.zone_enter_time = Game.play_time
	respawn_courier()
	env_ctrl.set_biome(BiomeDB.for_zone(zone), true)
	Events.zone_entered.emit(zone)
	Audio.set_loop_volume(Audio.music_player, 0.3)
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _add_optional(path: String, node_name: String) -> void:
	if ResourceLoader.exists(path):
		var n: Node = load(path).new()
		n.name = node_name
		add_child(n)
		if node_name == "Weather":
			weather = n


func _physics_process(delta: float) -> void:
	if courier == null or not is_instance_valid(courier) or courier.is_dead():
		return
	_zone_check_timer -= delta
	if _zone_check_timer > 0.0:
		return
	_zone_check_timer = 0.2
	var z := streamer.zone_at(courier.global_position)
	if z >= 0 and z != Game.current_zone:
		Game.set_current_zone(z)
		env_ctrl.set_biome(BiomeDB.for_zone(z))
		call_deferred("_after_zone_change", z)
	elif courier.global_position.length() > rebase_distance:
		call_deferred("_rebase")


func _after_zone_change(z: int) -> void:
	streamer.ensure(z)
	_rebase()


## Moves the floating origin to the courier's current grid cell.
func _rebase() -> void:
	if courier == null or not is_instance_valid(courier):
		return
	var local_cell := ZoneGenerator.cell_of(courier.global_position)
	var delta := streamer.set_origin(streamer.origin_cell + local_cell)
	if delta == Vector3.ZERO:
		return
	if is_instance_valid(courier):
		courier.shift_origin(delta)
	for n in transient.get_children():
		if n is Node3D:
			(n as Node3D).global_position += delta
	Events.origin_shifted.emit(delta)


# ------------------------------------------------------------- DeathFlow interface

func zone_of_position(pos: Vector3) -> int:
	var z := streamer.zone_at(pos)
	return z if z >= 0 else Game.current_zone


func to_zone_local(zone: int, pos: Vector3) -> Vector3:
	return streamer.to_zone_local(zone, pos)


func spawn_corpse_node(data: CorpseData) -> void:
	var inst := streamer.zone_instance(data.zone)
	if inst:
		inst.spawn_corpse(data)


func respawn_courier() -> void:
	if courier and is_instance_valid(courier):
		courier.remove_from_group("player")
		courier.queue_free()
	var zone := ZoneStreamer.station_zone(Game.last_station)
	streamer.ensure(zone)
	Game.current_zone = zone
	courier = COURIER_SCENE.instantiate()
	courier.data = Game.courier
	add_child(courier)
	var st := station_node(Game.last_station)
	if st:
		courier.global_transform = st.spawn_transform()
	else:
		courier.global_position = streamer.zone_offset(zone) + Vector3(0, 0.5, 4)
	courier.rotation = Vector3.ZERO
	courier.camera_rig.face_direction(Vector3.BACK)
	_rebase()
	env_ctrl.camera = courier.camera_rig.camera
	env_ctrl.courier = courier


func station_node(index: int) -> RelayStation:
	var inst := streamer.zone_instance(ZoneStreamer.station_zone(index))
	return inst.station_node(index) if inst else null


func current_zone_instance() -> ZoneInstance:
	return streamer.zone_instance(Game.current_zone)


func save_now() -> void:
	Save.save_game()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and Game.is_running:
		Save.save_game()


## World position of a corpse even if its zone isn't loaded.
func corpse_world_position(c: CorpseData) -> Vector3:
	return streamer.to_world(c.zone, c.local_pos)


func compass_targets() -> Array:
	var out: Array = []
	var st := station_node(Game.current_zone + 1)
	if st:
		out.append({"pos": st.global_position, "label": "[R]", "color": UITheme.ACCENT, "dist": true})
	else:
		var l := streamer.layout(Game.current_zone)
		var s := l.end_station()
		if not s.is_empty():
			out.append({"pos": streamer.to_world(Game.current_zone, s.xform.origin), "label": "[R]", "color": UITheme.ACCENT, "dist": true})
	var c := Game.most_recent_corpse()
	if c:
		out.append({"pos": corpse_world_position(c), "label": "[+]", "color": Color(0.85, 0.85, 0.95), "dist": true})
	return out
