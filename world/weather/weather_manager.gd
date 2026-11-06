class_name WeatherManager
extends Node
## Storms: a STORM FRONT rolls along the zone path from behind the courier, pushing them forward.
## Inside or near it: rain + low visibility, lightning that targets the highest exposed point near
## the courier (1.5 s warning flash + crackle first), wind gusts that push the courier mid-air,
## flash floods in flood biomes. Salt Desert storms are dust storms (very low visibility, no scent).
## Shelters (rock overhangs, huts, relay stations) protect from lightning and wind.

@export var front_speed: float = 1.8
@export var front_start_behind: float = 70.0
## Intensity falls off over this distance ahead of the front.
@export var front_reach: float = 45.0
@export var lightning_warning_time: float = 1.5
@export var lightning_radius: float = 3.5
@export var lightning_damage: float = 65.0
@export var lightning_search_radius: float = 16.0
@export var lightning_interval_inside: Vector2 = Vector2(5.0, 10.0)
@export var lightning_interval_near: Vector2 = Vector2(14.0, 24.0)
@export var gust_interval: Vector2 = Vector2(4.0, 9.0)
@export var gust_strength: float = 18.0
@export var gust_duration: float = 1.4
@export var flood_intensity: float = 0.6

var active: bool = false
var kind: String = "rain"
var storm_zone: int = -1
var front_progress: float = 0.0
var intensity: float = 0.0  # at the courier, 0..1
var forced: bool = false

var _pending_zone: int = -1
var _pending_time: float = -1.0
var _lightning_timer: float = 8.0
var _gust_timer: float = 6.0
var _gust_time: float = 0.0
var _gust_dir: Vector3 = Vector3.ZERO
var _ambient_gust_timer: float = 10.0
var _flooding: bool = false
var _front: StormFront
var _rain: CPUParticles3D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group("weather")
	_rng.randomize()
	Events.zone_entered.connect(_on_zone_entered)
	Events.courier_spawned.connect(_attach_particles)
	_front = preload("res://world/weather/storm_front.tscn").instantiate()
	_front.visible = false
	add_child(_front)


func world() -> Node:
	return get_parent()


func courier() -> Courier:
	return Perception.courier()


# =====================================================================
# Public queries (used by Perception, HUD, stations)
# =====================================================================

func visibility_mult() -> float:
	if not active:
		return 1.0
	return lerpf(1.0, 0.35 if kind == "dust" else 0.72, intensity)


func scent_disabled() -> bool:
	return active and kind == "dust" and intensity > 0.4


func storm_kind_for(zone: int) -> String:
	var b := BiomeDB.for_zone(zone)
	return b.storm_kind if b else "rain"


## Signal Mirror forecast for a zone.
func forecast(zone: int) -> String:
	var w: GameWorld = world() as GameWorld
	if w == null:
		return "unknown"
	var l := w.streamer.layout(zone)
	if not l.storm:
		return "Clear skies"
	return "Dust storm coming" if storm_kind_for(zone) == "dust" else "Storm coming"


# =====================================================================
# Storm lifecycle
# =====================================================================

func _on_zone_entered(zone: int) -> void:
	if active and storm_zone != zone and not forced:
		end_storm()
	var w: GameWorld = world() as GameWorld
	if w == null:
		return
	var l := w.streamer.layout(zone)
	if l.storm and not active:
		_pending_zone = zone
		_pending_time = l.storm_delay
	var b := BiomeDB.for_zone(zone)
	if b and b.ambient_gusts_per_min > 0.0:
		_ambient_gust_timer = 60.0 / b.ambient_gusts_per_min


func start_storm(storm_kind: String = "", is_forced: bool = false) -> void:
	var w: GameWorld = world() as GameWorld
	var c := courier()
	if w == null or c == null:
		return
	active = true
	forced = is_forced
	storm_zone = Game.current_zone
	kind = storm_kind if storm_kind != "" else storm_kind_for(storm_zone)
	var l := w.streamer.layout(storm_zone)
	var prog := l.progress_of(w.streamer.to_zone_local(storm_zone, c.global_position))
	front_progress = maxf(prog - front_start_behind, -20.0)
	_lightning_timer = _rng.randf_range(lightning_interval_near.x, lightning_interval_near.y)
	_gust_timer = _rng.randf_range(gust_interval.x, gust_interval.y)
	_front.visible = true
	_pending_time = -1.0
	Events.storm_started.emit(kind)
	Events.notify.emit("A dust storm rolls in from behind." if kind == "dust" else "A storm front is coming up the road behind you.")


func end_storm() -> void:
	if not active:
		return
	active = false
	forced = false
	intensity = 0.0
	_front.visible = false
	_set_flood(false)
	var w := world()
	if w and w.get("env_ctrl"):
		w.env_ctrl.storm_intensity = 0.0
		w.env_ctrl.dust_intensity = 0.0
	Events.storm_ended.emit()


## A rest at a station lets time pass: the storm may move in.
func on_rest() -> void:
	if not active and _rng.randf() < 0.35:
		start_storm()


func _process(delta: float) -> void:
	var w: GameWorld = world() as GameWorld
	var c := courier()
	if _pending_time >= 0.0 and _pending_zone == Game.current_zone:
		_pending_time -= delta
		if _pending_time <= 0.0:
			_pending_time = -1.0
			start_storm()
	_update_audio_and_fx(delta, c)
	if c == null or c.is_dead():
		return
	_ambient_gusts(delta, c)
	if not active or w == null:
		return
	var l := w.streamer.layout(storm_zone)
	front_progress += front_speed * delta
	if front_progress > l.length_m + 30.0 and not forced:
		end_storm()
		return
	var prog := l.progress_of(w.streamer.to_zone_local(storm_zone, c.global_position)) if storm_zone == Game.current_zone else l.length_m
	var ahead := prog - front_progress
	intensity = 1.0 if ahead <= 0.0 else clampf(1.0 - ahead / front_reach, 0.12, 1.0)
	if forced:
		intensity = maxf(intensity, 0.8)
	var pt: Array = l.point_at(clampf(front_progress, 0.0, l.length_m))
	_front.place(w.streamer.to_world(storm_zone, pt[0]), pt[1], kind == "dust")
	w.env_ctrl.storm_intensity = intensity if kind == "rain" else 0.0
	w.env_ctrl.dust_intensity = intensity if kind == "dust" else 0.0
	# lightning
	if kind == "rain":
		_lightning_timer -= delta
		if _lightning_timer <= 0.0:
			var inside := intensity >= 0.95
			var iv := lightning_interval_inside if inside else lightning_interval_near
			_lightning_timer = _rng.randf_range(iv.x, iv.y)
			if intensity > 0.3:
				strike_near(c)
	# gusts
	_gust_timer -= delta
	if _gust_timer <= 0.0 and intensity > 0.4:
		_gust_timer = _rng.randf_range(gust_interval.x, gust_interval.y)
		var fwd: Vector3 = pt[1]
		gust(fwd.rotated(Vector3.UP, _rng.randf_range(-1.2, 1.2)))
	_apply_gust(delta, c)
	# flash floods
	var b := BiomeDB.for_zone(storm_zone)
	if b and b.hazard == "flood":
		_set_flood(intensity >= flood_intensity)


func _ambient_gusts(delta: float, c: Courier) -> void:
	var b := BiomeDB.for_zone(Game.current_zone)
	if b == null or b.ambient_gusts_per_min <= 0.0:
		if not active:
			_apply_gust(delta, c)
		return
	_ambient_gust_timer -= delta
	if _ambient_gust_timer <= 0.0:
		_ambient_gust_timer = 60.0 / b.ambient_gusts_per_min * _rng.randf_range(0.6, 1.4)
		var a := _rng.randf() * TAU
		gust(Vector3(cos(a), 0, sin(a)))
	if not active:
		_apply_gust(delta, c)


func gust(dir: Vector3) -> void:
	_gust_dir = dir.normalized()
	_gust_time = gust_duration
	Audio.play("slide", -4.0, 0.3)


func _apply_gust(delta: float, c: Courier) -> void:
	if _gust_time > 0.0 and not c.is_sheltered():
		_gust_time -= delta
		var k := sin(clampf(_gust_time / gust_duration, 0.0, 1.0) * PI)
		c.wind_force = _gust_dir * gust_strength * k
	else:
		c.wind_force = Vector3.ZERO


func _set_flood(on: bool) -> void:
	if on == _flooding:
		return
	_flooding = on
	var w: GameWorld = world() as GameWorld
	if w == null:
		return
	var inst := w.streamer.zone_instance(storm_zone)
	if inst:
		for n in inst.find_children("*", "WaterVolume", true, false):
			(n as WaterVolume).set_flooded(on)
	if on:
		Events.notify.emit("Flash flood! Get to high ground.")


# =====================================================================
# Lightning
# =====================================================================

## True if nothing is above the point (open sky) and it's not inside a shelter.
func is_exposed(p: Vector3, c: Courier = null) -> bool:
	if c and p.distance_to(c.global_position) < 2.5 and c.is_sheltered():
		return false
	for s in get_tree().get_nodes_in_group("shelter") + get_tree().get_nodes_in_group("station"):
		if s.has_method("contains_point") and s.contains_point(p):
			return false
	var vp := get_viewport()
	var w3d := vp.find_world_3d() if vp else null
	var space := w3d.direct_space_state if w3d else null
	if space == null:
		return true
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 0.3, p + Vector3.UP * 40.0, Geo.LAYER_WORLD)
	return space.intersect_ray(q).is_empty()


## Picks the highest exposed point near the courier (the courier's head counts).
func pick_lightning_target(c: Courier) -> Vector3:
	var space := c.get_world_3d().direct_space_state
	var best := Vector3.INF
	var best_y := -INF
	var head := c.global_position + Vector3.UP * 1.8
	if is_exposed(head, c):
		best = head
		best_y = head.y
	for i in 10:
		var a := _rng.randf() * TAU
		var r := _rng.randf_range(4.0, lightning_search_radius)
		var p := c.global_position + Vector3(cos(a) * r, 40.0, sin(a) * r)
		var q := PhysicsRayQueryParameters3D.create(p, p + Vector3.DOWN * 80.0, Geo.LAYER_WORLD)
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			continue
		var hp: Vector3 = hit.position
		if hp.y > best_y and is_exposed(hp):
			best = hp
			best_y = hp.y
	return best


func strike_near(c: Courier) -> void:
	var p := pick_lightning_target(c)
	if p == Vector3.INF:
		return
	strike_at(p)


## Warning flash + crackle now, strike after lightning_warning_time.
func strike_at(p: Vector3) -> void:
	Events.lightning_warning.emit(p)
	var warn := OmniLight3D.new()
	warn.light_color = Color(0.7, 0.8, 1.0)
	warn.omni_range = 6.0
	warn.light_energy = 3.0
	var parent: Node = get_tree().get_first_node_in_group("transient")
	if parent == null:
		parent = get_tree().current_scene
	parent.add_child(warn)
	warn.global_position = p + Vector3.UP * 0.5
	var glow := Geo.deco_box(warn, Vector3(0, 0.0, 0), Vector3(0.3, 0.3, 0.3), Color(0.8, 0.9, 1.0))
	glow.material_override = Geo.mat(Color(0.8, 0.9, 1.0), 0.5, 4.0)
	Audio.play_at("thunder_warning", p, 4.0, 60.0, 0.0)
	var tw := warn.create_tween().set_loops(int(lightning_warning_time / 0.15))
	tw.tween_property(warn, "light_energy", 0.5, 0.075)
	tw.tween_property(warn, "light_energy", 4.0, 0.075)
	await get_tree().create_timer(lightning_warning_time, false).timeout
	if not is_instance_valid(warn):
		return
	var strike_pos := warn.global_position - Vector3.UP * 0.5
	warn.queue_free()
	_do_strike(strike_pos)


func _do_strike(p: Vector3) -> void:
	Events.lightning_strike.emit(p)
	Events.compass_alert.emit(p, "lightning")
	var bolt := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.25, 60.0, 0.25)
	bolt.mesh = bm
	bolt.material_override = Geo.mat(Color(0.85, 0.9, 1.0), 0.2, 8.0)
	var parent: Node = get_tree().get_first_node_in_group("transient")
	if parent == null:
		parent = get_tree().current_scene
	parent.add_child(bolt)
	bolt.global_position = p + Vector3.UP * 30.0
	get_tree().create_timer(0.18).timeout.connect(bolt.queue_free)
	Audio.play_at("thunder", p, 8.0, 200.0, 0.1)
	Events.sound_emitted.emit(p, 30.0, "thunder")
	var c := courier()
	if c and not c.is_dead():
		var d := (c.global_position + Vector3.UP).distance_to(p)
		if d < 40.0:
			c.camera_rig.shake(clampf(1.0 - d / 40.0, 0.2, 1.0))
		if d < lightning_radius and not c.is_sheltered():
			c.take_damage(lightning_damage, "struck by lightning")
	for n in get_tree().get_nodes_in_group("enemy"):
		var e := n as Enemy
		if e and e.global_position.distance_to(p) < lightning_radius:
			e.take_damage(lightning_damage, p, "lightning")


# =====================================================================
# FX
# =====================================================================

func _attach_particles(c: Node) -> void:
	if _rain and is_instance_valid(_rain):
		_rain.queue_free()
	_rain = CPUParticles3D.new()
	_rain.amount = 120 if Settings.quality == Settings.Quality.LOW else 420
	_rain.lifetime = 1.0
	_rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_rain.emission_box_extents = Vector3(16, 0.5, 16)
	_rain.direction = Vector3.DOWN
	_rain.spread = 4.0
	_rain.initial_velocity_min = 22.0
	_rain.initial_velocity_max = 26.0
	_rain.gravity = Vector3.ZERO
	_rain.local_coords = false
	var bm := BoxMesh.new()
	bm.size = Vector3(0.025, 0.6, 0.025)
	_rain.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.7, 0.75, 0.85, 0.45)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_rain.material_override = m
	_rain.position = Vector3(0, 12, 0)
	_rain.emitting = false
	var rig: Node = c.get("camera_rig")
	if rig:
		rig.add_child(_rain)


func _update_audio_and_fx(_delta: float, c: Courier) -> void:
	var speed := 0.0
	if c and is_instance_valid(c):
		speed = Vector2(c.velocity.x, c.velocity.z).length()
	var storm_wind := intensity if active else 0.0
	Audio.set_loop_volume(Audio.wind_player, clampf(0.08 + speed / 14.0 * 0.5 + storm_wind * 0.5, 0.0, 1.0))
	Audio.set_loop_volume(Audio.rain_player, intensity * 0.8 if active and kind == "rain" else 0.0)
	if _rain and is_instance_valid(_rain):
		_rain.emitting = active and intensity > 0.2
		if active:
			var m := _rain.material_override as StandardMaterial3D
			if kind == "dust":
				m.albedo_color = Color(0.75, 0.62, 0.45, 0.35)
				_rain.direction = Vector3(1, -0.15, 0).normalized()
				_rain.initial_velocity_min = 10.0
				_rain.initial_velocity_max = 16.0
			else:
				m.albedo_color = Color(0.7, 0.75, 0.85, 0.45)
				_rain.direction = Vector3.DOWN
				_rain.initial_velocity_min = 22.0
				_rain.initial_velocity_max = 26.0
