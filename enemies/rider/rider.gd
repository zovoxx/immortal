class_name Rider
extends Enemy
## Mounted hunter of the open plains. Very fast in a straight line, slow to turn. Predicts the
## courier's path to cut them off. Crashing into trees/walls at speed stuns it — narrow terrain
## and trees beat it.

@export var gallop_speed: float = 14.0
@export var trot_speed: float = 4.0
@export var accel: float = 7.0
## Turn rate (rad/s) at full gallop; slower speeds turn faster.
@export var turn_rate_fast: float = 1.1
@export var turn_rate_slow: float = 2.8
@export var predict_max: float = 1.6
@export var crash_speed: float = 8.0
@export var crash_stun: float = 2.5
@export var pass_strike_range: float = 2.6

var heading: float = 0.0
var speed: float = 0.0
var feature_id: String = ""
var _strike_cd: float = 0.0


func _init() -> void:
	max_hp = 90.0
	walk_speed = 4.0
	run_speed = 14.0
	sight_range = 34.0
	sight_angle_deg = 130.0
	attack_damage = 25.0
	attack_cooldown = 2.0
	body_radius = 0.75
	body_height = 2.6
	eye_height = 2.8
	is_hunter = true
	patrol_radius = 16.0
	lose_sight_time = 4.0
	model_scene = preload("res://enemies/rider/rider_model.tscn")


func set_initial_yaw(yaw: float) -> void:
	heading = yaw


func _on_ready() -> void:
	model.rotation.y = heading


func _death_cause() -> String:
	return "ridden down by a rider"


func forward() -> Vector3:
	return Vector3(-sin(heading), 0, -cos(heading))


## Riders steer themselves (no navmesh): heading turns toward the goal at a limited rate.
func _move(delta: float) -> void:
	_strike_cd = maxf(_strike_cd - delta, 0.0)
	var goal_speed := 0.0
	var goal := Vector3.INF
	if state == State.CHASE and target and not target.is_dead():
		var tv := target.velocity
		tv.y = 0
		var dist := global_position.distance_to(target.global_position)
		var t := clampf(dist / maxf(gallop_speed, 1.0), 0.0, predict_max)
		goal = target.global_position + tv * t
		goal_speed = gallop_speed * speed_mult
	elif _has_move_target and not _reached():
		goal = _move_target
		goal_speed = trot_speed * speed_mult if state != State.SEARCH else trot_speed * 1.5
	var turn_amount := 0.0
	if goal != Vector3.INF:
		var to := goal - global_position
		to.y = 0
		if to.length() > 0.5:
			var want := atan2(-to.x, -to.z)
			var diff := wrapf(want - heading, -PI, PI)
			var rate := lerpf(turn_rate_slow, turn_rate_fast, clampf(speed / gallop_speed, 0.0, 1.0))
			turn_amount = clampf(diff, -rate * delta, rate * delta)
			heading += turn_amount
			# slow down for sharp turns
			if absf(diff) > PI * 0.5:
				goal_speed *= 0.55
	speed = move_toward(speed, goal_speed, accel * delta)
	var f := forward()
	velocity.x = f.x * speed
	velocity.z = f.z * speed
	velocity.y = -0.5 if is_on_floor() else velocity.y - gravity * delta
	model.rotation.y = heading
	model.rotation.z = lerpf(model.rotation.z, -turn_amount * 8.0, clampf(delta * 5.0, 0.0, 1.0))
	var pre_speed := speed
	move_and_slide()
	# crash into obstacles at speed
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var n := col.get_normal()
		if absf(n.y) < 0.5 and n.dot(f) < -0.6 and pre_speed > crash_speed and not (col.get_collider() is Courier):
			speed = 0.0
			Audio.play_at("toll_slam", global_position, -2.0)
			stun(crash_stun)
			break
	# hoofbeats
	if speed > 3.0 and int(_state_time * speed * 0.5) % 2 == 0 and randf() < delta * 6.0:
		Audio.play_at("horse", global_position, -6.0, 60.0, 0.2)
		if speed > 10.0:
			Events.sound_emitted.emit(global_position, 18.0, "footstep")


func _think(delta: float) -> void:
	match state:
		State.CHASE:
			if target == null or target.is_dead() or target.in_volume("station"):
				_enter(State.SEARCH)
				return
			if sees_player:
				last_known = target.global_position
			elif _lost_sight_time > lose_sight_time:
				_enter(State.SEARCH)
				return
			# pass-by strike
			var d := global_position.distance_to(target.global_position)
			if d < pass_strike_range and speed > 6.0 and _strike_cd <= 0.0:
				if _hesitate < 0.0:
					_hesitate = target.data.attack_hesitation() if target.data else 0.0
				if _hesitate > 0.0:
					_hesitate -= delta
					return
				_strike_cd = attack_cooldown
				target.take_damage(attack_damage * damage_mult, _death_cause(), global_position)
				Audio.play_at("swing", global_position, 0.0)
				Events.sound_emitted.emit(global_position, 16.0, "combat")
		State.ATTACK:
			_enter(State.CHASE)
		_:
			super._think(delta)


func state_name() -> String:
	return "%s %.0fm/s" % [super.state_name(), speed]
