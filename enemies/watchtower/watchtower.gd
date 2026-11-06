class_name Watchtower
extends Node3D
## Static tower with a sweeping spotlight. If the light rests on the courier for `alarm_time`
## seconds it rings a bell: every hunter within `alarm_radius` enters CHASE.
## A sling stone to the lantern disables it for `disable_time` seconds.

const MODEL := preload("res://enemies/watchtower/watchtower_model.tscn")

@export var alarm_time: float = 1.0
@export var alarm_radius: float = 60.0
@export var disable_time: float = 30.0
@export var light_range: float = 42.0
@export var cone_half_angle_deg: float = 13.0
@export var sweep_half_angle_deg: float = 60.0
@export var sweep_period: float = 7.0
## Where the beam meets the ground (metres from the tower) — sets the pitch.
@export var beam_ground_distance: float = 17.0
@export var alarm_cooldown: float = 8.0

var zone_index: int = 0
var feature_id: String = ""
var base_yaw: float = 0.0
var exposure: float = 0.0
var disabled_time: float = 0.0
var alarm_timer: float = 0.0
var model: Node3D
var lantern: Node3D
var spot: SpotLight3D
var _cone: MeshInstance3D
var _lamp: MeshInstance3D
var _t: float = 0.0
var _tracking: float = 0.0
var _label: Label3D


func set_initial_yaw(yaw: float) -> void:
	base_yaw = yaw


func _ready() -> void:
	add_to_group("watchtower")
	model = MODEL.instantiate()
	add_child(model)
	var lp := model.get_node_or_null("LanternPoint") as Node3D
	lantern = Node3D.new()
	lantern.name = "Lantern"
	lantern.position = lp.position if lp else Vector3(0, 8.9, 0)
	add_child(lantern)
	_lamp = Geo.deco_box(lantern, Vector3.ZERO, Vector3(0.6, 0.6, 0.6), Color(1.0, 0.9, 0.6))
	_lamp.material_override = Geo.mat(Color(1.0, 0.9, 0.6), 0.4, 3.0)
	var hit := Area3D.new()
	hit.name = "LanternHitbox"
	hit.collision_layer = Geo.LAYER_HITBOX
	hit.collision_mask = 0
	hit.monitoring = false
	hit.add_to_group("lantern")
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 0.75
	cs.shape = sph
	hit.add_child(cs)
	lantern.add_child(hit)
	hit.set_meta("tower", self)
	spot = SpotLight3D.new()
	spot.spot_range = light_range
	spot.spot_angle = cone_half_angle_deg
	spot.light_energy = 8.0
	spot.light_color = Color(1.0, 0.95, 0.8)
	spot.shadow_enabled = false
	lantern.add_child(spot)
	_cone = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.25
	cm.bottom_radius = tan(deg_to_rad(cone_half_angle_deg)) * light_range
	cm.height = light_range
	cm.radial_segments = 16
	cm.rings = 1
	cm.cap_top = false
	cm.cap_bottom = false
	_cone.mesh = cm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.95, 0.75, 0.07)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_cone.material_override = m
	_cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cone.rotation.x = -PI * 0.5
	_cone.position = Vector3(0, 0, -light_range * 0.5)
	spot.add_child(_cone)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position = Vector3(0, 11.5, 0)
	_label.font_size = 48
	_label.pixel_size = 0.01
	_label.no_depth_test = true
	add_child(_label)
	_t = randf() * sweep_period


## Called by a sling stone hitting the lantern hitbox.
func on_lantern_hit() -> void:
	if disabled_time > 0.0:
		return
	disabled_time = disable_time
	exposure = 0.0
	Audio.play_at("impact", lantern.global_position, 2.0)
	Events.notify.emit("Watchtower lantern shattered")


func is_disabled() -> bool:
	return disabled_time > 0.0


func state_name() -> String:
	if disabled_time > 0.0:
		return "DARK %ds" % ceili(disabled_time)
	if alarm_timer > 0.0:
		return "ALARM"
	return "SWEEP %d%%" % int(exposure * 100.0)


func _physics_process(delta: float) -> void:
	_t += delta
	alarm_timer = maxf(alarm_timer - delta, 0.0)
	var c := Perception.courier()
	_label.visible = Game.debug_overlay
	_label.text = state_name()
	if disabled_time > 0.0:
		disabled_time -= delta
		spot.visible = false
		_lamp.visible = false
		if disabled_time <= 0.0:
			spot.visible = true
			_lamp.visible = true
		return
	var pitch := -atan2(lantern.position.y, beam_ground_distance)
	if _tracking > 0.0 and c and not c.is_dead():
		_tracking -= delta
		var to := c.global_position + Vector3.UP - lantern.global_position
		var yaw_t := atan2(-to.x, -to.z)
		var pitch_t := atan2(to.y, Vector2(to.x, to.z).length())
		lantern.global_rotation = Vector3(lerp_angle(lantern.global_rotation.x, pitch_t, delta * 6.0), lerp_angle(lantern.global_rotation.y, yaw_t, delta * 6.0), 0)
	else:
		var yaw := base_yaw + sin(_t / sweep_period * TAU) * deg_to_rad(sweep_half_angle_deg)
		lantern.global_rotation = Vector3(pitch, yaw, 0)
	spot.light_color = Color(1.0, 0.3, 0.2) if alarm_timer > 0.0 else Color(1.0, 0.95, 0.8)
	(_cone.material_override as StandardMaterial3D).albedo_color = Color(1.0, 0.3, 0.2, 0.09) if alarm_timer > 0.0 else Color(1.0, 0.95, 0.75, 0.07)
	if c and in_light(c):
		exposure += delta
		if exposure >= alarm_time and alarm_timer <= 0.0:
			ring_bell()
	else:
		exposure = maxf(exposure - delta * 0.5, 0.0)


## Is the courier inside the beam with clear line of sight?
func in_light(c: Courier) -> bool:
	if c.is_dead() or c.in_volume("station") or c.is_hidden_in_grass():
		return false
	var from := lantern.global_position
	var to := c.global_position + Vector3.UP * 1.0 - from
	if to.length() > light_range:
		return false
	var fwd := -lantern.global_transform.basis.z
	if fwd.angle_to(to.normalized()) > deg_to_rad(cone_half_angle_deg):
		return false
	var ex: Array[RID] = []
	for b in model.find_children("*", "StaticBody3D", true, false):
		ex.append((b as StaticBody3D).get_rid())
	return Perception.has_los(get_world_3d().direct_space_state, from + fwd * 0.6, c.global_position + Vector3.UP * 1.0, ex)


func ring_bell() -> void:
	alarm_timer = alarm_cooldown
	_tracking = 6.0
	exposure = 0.0
	var bp := model.get_node_or_null("BellPoint") as Node3D
	var pos := bp.global_position if bp else global_position
	Audio.play_at("bell", pos, 6.0, 140.0, 0.0)
	Events.alarm_raised.emit(global_position, alarm_radius)
	Events.compass_alert.emit(global_position, "bell")
	Events.sound_emitted.emit(global_position, 25.0, "bell")
	Events.notify.emit("The watchtower bell rings!")
