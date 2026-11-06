class_name Enemy
extends CharacterBody3D
## Base enemy: state machine IDLE / PATROL / SUSPICIOUS / CHASE / ATTACK / SEARCH / RETURN
## (+ FLEE / LOOT / STUNNED / DEAD for specific types), sight-cone + line-of-sight detection,
## sound detection, NavigationAgent3D pathing (direct steering until the zone navmesh is baked).

enum State { IDLE, PATROL, SUSPICIOUS, CHASE, ATTACK, SEARCH, RETURN, FLEE, LOOT, STUNNED, DEAD }
const STATE_NAMES := ["IDLE", "PATROL", "SUSPICIOUS", "CHASE", "ATTACK", "SEARCH", "RETURN", "FLEE", "LOOT", "STUNNED", "DEAD"]

@export_group("Body")
@export var max_hp: float = 40.0
@export var walk_speed: float = 3.0
@export var run_speed: float = 7.0
@export var turn_speed: float = 8.0
@export var gravity: float = 22.0
@export var body_radius: float = 0.4
@export var body_height: float = 1.6
@export var model_scene: PackedScene

@export_group("Senses")
@export var sight_range: float = 16.0
@export var sight_angle_deg: float = 120.0
@export var close_sense_range: float = 2.5
@export var eye_height: float = 1.4
@export var hearing_mult: float = 1.0
@export var awareness_rate: float = 1.6
@export var awareness_decay: float = 0.35
@export var lose_sight_time: float = 2.5
@export var search_time: float = 8.0
@export var patrol_radius: float = 7.0
## Hunters answer watchtower alarms and are pushed by caltrops.
@export var is_hunter: bool = false

@export_group("Attack")
@export var attack_range: float = 1.8
@export var attack_damage: float = 10.0
@export var attack_cooldown: float = 1.2
@export var attack_windup: float = 0.4

var state: State = State.IDLE
var hp: float = 40.0
var zone_index: int = 0
var damage_mult: float = 1.0
var awareness: float = 0.0
var home_local: Vector3
var last_known: Vector3
var investigate_pos: Vector3
var sees_player: bool = false
var target: Courier
var model: Node3D
var agent: NavigationAgent3D
var speed_mult: float = 1.0  # caltrops etc.
var group_id: String = ""

var _state_time: float = 0.0
var _sense_timer: float = 0.0
var _lost_sight_time: float = 0.0
var _attack_cd: float = 0.0
var _hesitate: float = -1.0
var _repath: float = 0.0
var _move_target: Vector3
var _has_move_target: bool = false
var _stuck_time: float = 0.0
var _label: Label3D
var _flash: float = 0.0


func _ready() -> void:
	add_to_group("enemy")
	if is_hunter:
		add_to_group("hunter")
	collision_layer = Geo.LAYER_ENEMY
	collision_mask = Geo.LAYER_WORLD | Geo.LAYER_ENEMY | Geo.LAYER_PLAYER
	floor_snap_length = 0.4
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = body_radius
	cap.height = maxf(body_height, body_radius * 2.0)
	cs.shape = cap
	cs.position.y = cap.height * 0.5
	add_child(cs)
	if model_scene:
		model = model_scene.instantiate()
		add_child(model)
	agent = NavigationAgent3D.new()
	agent.path_desired_distance = 0.7
	agent.target_desired_distance = 0.9
	agent.radius = body_radius
	agent.height = body_height
	agent.path_max_distance = 4.0
	add_child(agent)
	hp = max_hp * Difficulty.enemy_hp_mult(zone_index)
	damage_mult = Difficulty.enemy_damage_mult(zone_index)
	home_local = position
	_sense_timer = randf() * 0.2
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position = Vector3(0, body_height + 0.7, 0)
	_label.font_size = 40
	_label.pixel_size = 0.01
	_label.no_depth_test = true
	_label.visible = false
	add_child(_label)
	Events.sound_emitted.connect(_on_sound)
	Events.alarm_raised.connect(_on_alarm)
	Events.origin_shifted.connect(_on_origin_shifted)
	_on_ready()


## Subclass hook.
func _on_ready() -> void:
	pass


func home_global() -> Vector3:
	var p := get_parent() as Node3D
	return p.to_global(home_local) if p else home_local


func _on_origin_shifted(delta: Vector3) -> void:
	last_known += delta
	investigate_pos += delta
	_move_target += delta


# =====================================================================
# Main loop
# =====================================================================

func _physics_process(delta: float) -> void:
	_state_time += delta
	_attack_cd = maxf(_attack_cd - delta, 0.0)
	_flash = maxf(_flash - delta * 3.0, 0.0)
	if state == State.DEAD:
		velocity.y -= gravity * delta
		velocity.x *= 0.9
		velocity.z *= 0.9
		move_and_slide()
		return
	target = Perception.courier()
	_sense_timer -= delta
	if _sense_timer <= 0.0:
		_sense_timer = 0.1
		_sense(0.1)
	_think(delta)
	_move(delta)
	_update_label()


func _enter(s: State) -> void:
	if s == state:
		return
	state = s
	_state_time = 0.0
	_has_move_target = false
	if s == State.CHASE:
		_hesitate = -1.0
	Events.enemy_state_changed.emit(self, STATE_NAMES[s])
	_on_state_entered(s)


func _on_state_entered(_s: State) -> void:
	pass


func state_name() -> String:
	return STATE_NAMES[state]


# =====================================================================
# Perception
# =====================================================================

func eye_position() -> Vector3:
	return global_position + Vector3.UP * eye_height


func forward() -> Vector3:
	if model:
		return -model.global_transform.basis.z.normalized()
	return -global_transform.basis.z


func can_see_courier() -> bool:
	var c := target
	if c == null or c.is_dead():
		return false
	var range_ := sight_range * Perception.sight_mult(c)
	var to := c.global_position + Vector3.UP * 1.0 - eye_position()
	var dist := to.length()
	if dist > maxf(range_, 0.0) and dist > close_sense_range * Perception.sight_mult(c):
		return false
	if dist > close_sense_range:
		var flat := Vector3(to.x, 0, to.z).normalized()
		var fwd := forward()
		fwd.y = 0
		if fwd.normalized().dot(flat) < cos(deg_to_rad(sight_angle_deg * 0.5)):
			return false
	return Perception.has_los(get_world_3d().direct_space_state, eye_position(), c.global_position + Vector3.UP * 1.0, [get_rid()])


func _sense(dt: float) -> void:
	sees_player = can_see_courier()
	if sees_player:
		var d := global_position.distance_to(target.global_position)
		var closeness := clampf(1.5 - d / maxf(sight_range, 1.0), 0.3, 1.5)
		awareness = minf(awareness + awareness_rate * closeness * dt * 2.0, 1.2)
		last_known = target.global_position
		_lost_sight_time = 0.0
		if awareness >= 1.0 and state in [State.IDLE, State.PATROL, State.SUSPICIOUS, State.SEARCH, State.RETURN]:
			_on_spotted()
		elif awareness >= 0.35 and state in [State.IDLE, State.PATROL, State.RETURN]:
			investigate_pos = target.global_position
			_enter(State.SUSPICIOUS)
	else:
		awareness = maxf(awareness - awareness_decay * dt, 0.0)
		_lost_sight_time += dt


## Called when awareness fills. Default: chase.
func _on_spotted() -> void:
	_enter(State.CHASE)


func _on_sound(pos: Vector3, radius: float, kind: String) -> void:
	if state in [State.DEAD, State.STUNNED]:
		return
	var d := global_position.distance_to(pos)
	if d > radius * hearing_mult:
		return
	if state in [State.CHASE, State.ATTACK]:
		if kind != "noise_maker":
			return
	if kind == "noise_maker" or kind == "impact":
		investigate_pos = pos
		_enter(State.SUSPICIOUS)
		return
	investigate_pos = pos
	awareness = maxf(awareness, 0.5 if kind in ["combat", "land"] else 0.4)
	if state in [State.IDLE, State.PATROL, State.RETURN, State.SEARCH]:
		_enter(State.SUSPICIOUS)


func _on_alarm(pos: Vector3, radius: float) -> void:
	if not is_hunter or state == State.DEAD:
		return
	if global_position.distance_to(pos) <= radius and target:
		last_known = target.global_position
		awareness = 1.2
		_enter(State.CHASE)


# =====================================================================
# Behaviour (override _think in subclasses, call super for defaults)
# =====================================================================

func _think(delta: float) -> void:
	match state:
		State.IDLE:
			_stop()
			if _state_time > randf_range(2.0, 4.0):
				_enter(State.PATROL)
		State.PATROL:
			if not _has_move_target or _reached():
				if _has_move_target and _state_time < 2.0:
					return
				var r := randf_range(2.0, patrol_radius)
				var a := randf() * TAU
				set_move_target(home_global() + Vector3(cos(a) * r, 0, sin(a) * r))
				_state_time = 0.0
			if _state_time > 6.0:
				_enter(State.IDLE)
		State.SUSPICIOUS:
			_stop()
			face_towards(investigate_pos, delta)
			if _state_time > 0.9:
				set_move_target(investigate_pos)
				if _reached() or _state_time > 8.0:
					_enter(State.SEARCH)
		State.CHASE:
			_chase(delta)
		State.ATTACK:
			_attack(delta)
		State.SEARCH:
			if not _has_move_target or _reached():
				var a := randf() * TAU
				set_move_target(last_known + Vector3(cos(a), 0, sin(a)) * randf_range(2.0, 6.0))
			if _state_time > search_time:
				_enter(State.RETURN)
		State.RETURN:
			set_move_target(home_global())
			if _reached() or _state_time > 20.0:
				_enter(State.IDLE)
		State.STUNNED:
			_stop()
			if _state_time > 2.0:
				_enter(State.CHASE if awareness > 0.5 else State.SEARCH)


func _chase(delta: float) -> void:
	if target == null or target.is_dead() or target.in_volume("station"):
		_enter(State.SEARCH)
		return
	if sees_player:
		set_move_target(target.global_position)
		var d := global_position.distance_to(target.global_position)
		if d <= attack_range and _attack_cd <= 0.0:
			if _hesitate < 0.0:
				_hesitate = target.data.attack_hesitation() if target.data else 0.0
			if _hesitate > 0.0:
				_hesitate -= delta
				face_towards(target.global_position, delta)
				_stop()
				return
			_enter(State.ATTACK)
	else:
		set_move_target(last_known)
		if _lost_sight_time > lose_sight_time:
			_enter(State.SEARCH)


## Default melee attack: wind-up, strike in a short cone, cooldown.
func _attack(delta: float) -> void:
	_stop()
	if target == null:
		_enter(State.SEARCH)
		return
	if _state_time < attack_windup:
		face_towards(target.global_position, delta)
		return
	if not has_meta("_struck"):
		set_meta("_struck", true)
		_strike()
	if _state_time > attack_windup + 0.35:
		remove_meta("_struck")
		_attack_cd = attack_cooldown
		_enter(State.CHASE)


func _strike() -> void:
	if target and global_position.distance_to(target.global_position) <= attack_range + 0.4:
		var to := (target.global_position - global_position).normalized()
		if forward().dot(to) > 0.3:
			target.take_damage(attack_damage * damage_mult, _death_cause(), global_position)
	Events.sound_emitted.emit(global_position, 12.0, "combat")


func _death_cause() -> String:
	return "killed by an enemy"


# =====================================================================
# Movement
# =====================================================================

func set_move_target(p: Vector3) -> void:
	if _has_move_target and p.distance_to(_move_target) < 0.5:
		return
	_move_target = p
	_has_move_target = true
	_repath = 0.0


func _stop() -> void:
	_has_move_target = false


func _reached() -> bool:
	if not _has_move_target:
		return true
	var d := _move_target - global_position
	d.y = 0
	return d.length() < 1.0


func current_speed() -> float:
	var s := walk_speed
	if state in [State.CHASE, State.FLEE]:
		s = run_speed
	return s * speed_mult


func _nav_ready() -> bool:
	var z := get_parent()
	while z and not z is ZoneInstance:
		z = z.get_parent()
	return z != null and (z as ZoneInstance).nav_ready


func _next_waypoint() -> Vector3:
	if _nav_ready():
		_repath -= get_physics_process_delta_time()
		if _repath <= 0.0:
			_repath = 0.3
			agent.target_position = _move_target
		var n := agent.get_next_path_position()
		if agent.is_navigation_finished() or n.distance_to(global_position) < 0.05:
			return _move_target
		return n
	return _move_target


func _move(delta: float) -> void:
	var hv := Vector3.ZERO
	if _has_move_target and not _reached():
		var wp := _next_waypoint()
		var dir := wp - global_position
		dir.y = 0
		if dir.length() > 0.05:
			dir = dir.normalized()
			hv = dir * current_speed()
			face_dir(dir, delta)
			if is_on_floor() and not _ground_ahead(dir):
				hv = Vector3.ZERO
				if state in [State.PATROL, State.SEARCH, State.FLEE]:
					_has_move_target = false
	_custom_velocity(delta, hv)
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = -0.5
	var before := global_position
	move_and_slide()
	if hv.length() > 0.5 and before.distance_to(global_position) < hv.length() * delta * 0.2:
		_stuck_time += delta
	else:
		_stuck_time = maxf(_stuck_time - delta, 0.0)


## Never walk off ledges into the void or a chasm (drops deeper than 3 m).
func _ground_ahead(dir: Vector3) -> bool:
	var from := global_position + dir * (body_radius + 0.6) + Vector3.UP * 0.6
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 3.6, Geo.LAYER_WORLD, [get_rid()])
	return not get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## Subclasses can override to blend (e.g. lunges, riders' inertia).
func _custom_velocity(delta: float, hv: Vector3) -> void:
	velocity.x = move_toward(velocity.x, hv.x, 30.0 * delta)
	velocity.z = move_toward(velocity.z, hv.z, 30.0 * delta)


func face_dir(dir: Vector3, delta: float) -> void:
	if model == null or dir.length_squared() < 0.001:
		return
	var yaw := atan2(-dir.x, -dir.z)
	model.rotation.y = lerp_angle(model.rotation.y, yaw, clampf(turn_speed * delta, 0.0, 1.0))


func face_towards(p: Vector3, delta: float) -> void:
	var d := p - global_position
	d.y = 0
	face_dir(d.normalized(), delta)


# =====================================================================
# Damage
# =====================================================================

func take_damage(amount: float, from_pos: Vector3 = Vector3.INF, _source: String = "") -> void:
	if state == State.DEAD:
		return
	hp -= amount
	_flash = 1.0
	Audio.play_at("hit", global_position, -4.0)
	if from_pos != Vector3.INF:
		var push := (global_position - from_pos)
		push.y = 0
		velocity += push.normalized() * 3.0
	if hp <= 0.0:
		die()
		return
	if target:
		last_known = target.global_position
	awareness = 1.2
	_on_damaged()


func _on_damaged() -> void:
	if state != State.ATTACK:
		_enter(State.CHASE)


func stun(seconds: float = 2.0) -> void:
	if state != State.DEAD:
		_enter(State.STUNNED)
		_state_time = 2.0 - seconds


func die(_cause: String = "") -> void:
	if state == State.DEAD:
		return
	_enter(State.DEAD)
	collision_layer = 0
	collision_mask = Geo.LAYER_WORLD
	remove_from_group("enemy")
	remove_from_group("hunter")
	if model:
		var tw := create_tween()
		tw.tween_property(model, "rotation:z", PI * 0.5, 0.4)
	_on_died()
	var t := get_tree().create_timer(10.0)
	t.timeout.connect(func(): if is_instance_valid(self): queue_free())


func _on_died() -> void:
	pass


func is_dead() -> bool:
	return state == State.DEAD


func _update_label() -> void:
	_label.visible = Game.debug_overlay
	if _label.visible:
		_label.text = "%s %d%%\nhp %d" % [state_name(), int(awareness * 100.0), int(hp)]
		_label.modulate = Color(1, 0.3, 0.2) if state in [State.CHASE, State.ATTACK] else (Color(1, 0.85, 0.3) if state in [State.SUSPICIOUS, State.SEARCH] else Color.WHITE)
