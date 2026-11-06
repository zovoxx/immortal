class_name Hound
extends Enemy
## Hunter. Fast, low HP, hunts in packs of 2-4. Follows the courier's scent trail point by point,
## lunges. Can't climb: getting up high breaks the chase.

@export_group("Scent")
## Radius at which a hound picks up a scent point of strength 1.
@export var sniff_radius: float = 5.0
@export var scent_reach_dist: float = 1.4
@export var give_up_trail_time: float = 2.5
@export_group("Lunge")
@export var lunge_speed: float = 12.0
@export var lunge_time: float = 0.28
@export var unreachable_height: float = 2.2
@export var unreachable_give_up: float = 4.0

var pack: Array = []
var tracking: bool = false
var _scent_time: float = -1.0
var _trail_lost: float = 0.0
var _howled: bool = false
var _lunging: float = 0.0
var _lunge_dir: Vector3
var _lunge_hit: bool = false
var _unreachable: float = 0.0
var _sniff_timer: float = 0.0


func _init() -> void:
	max_hp = 30.0
	walk_speed = 3.5
	run_speed = 8.6
	sight_range = 16.0
	sight_angle_deg = 140.0
	attack_range = 3.4
	attack_damage = 12.0
	attack_cooldown = 1.3
	attack_windup = 0.3
	is_hunter = true
	body_radius = 0.35
	body_height = 0.9
	eye_height = 0.75
	turn_speed = 10.0
	model_scene = preload("res://enemies/hound/hound_model.tscn")


func _death_cause() -> String:
	return "torn apart by hounds"


func _on_spotted() -> void:
	_alert_pack()
	_enter(State.CHASE)


func _alert_pack() -> void:
	if not _howled:
		_howled = true
		Audio.play_at("howl", global_position, 2.0, 90.0)
		Events.compass_alert.emit(global_position, "howl")
	for h in pack:
		if is_instance_valid(h) and h != self and not h.is_dead() and h.state != State.CHASE:
			h.last_known = last_known
			h.awareness = 1.0
			h._howled = true
			h._enter(State.CHASE)


func _on_state_entered(s: State) -> void:
	if s in [State.IDLE, State.RETURN]:
		_howled = false
		tracking = false
		_scent_time = -1.0


func _think(delta: float) -> void:
	# passive sniffing: pick up the trail while idle/patrolling/searching
	if state in [State.IDLE, State.PATROL, State.SEARCH, State.SUSPICIOUS, State.RETURN]:
		_sniff_timer -= delta
		if _sniff_timer <= 0.0:
			_sniff_timer = 0.4
			var p := _find_scent_start()
			if not p.is_empty():
				tracking = true
				_scent_time = float(p.time)
				last_known = p.pos
				_alert_pack()
				_enter(State.CHASE)
				return
	if state == State.CHASE and _check_unreachable(delta):
		return
	super._think(delta)


func _chase(delta: float) -> void:
	if target == null or target.is_dead() or target.in_volume("station"):
		_enter(State.SEARCH)
		return
	if sees_player:
		tracking = false
		super._chase(delta)
		return
	# lost sight: follow the scent trail point by point
	if _lost_sight_time > 0.6:
		_follow_scent(delta)
	else:
		set_move_target(last_known)


## Nearest scent point within (sniff radius x point strength x modifiers), or {}.
func _find_scent_start() -> Dictionary:
	var c := target
	if c == null or c.is_dead() or c.in_volume("station"):
		return {}
	var mult := Perception.scent_mult(c)
	if mult <= 0.0:
		return {}
	var best: Dictionary = {}
	var best_d := INF
	for p in c.scent.points():
		var r := sniff_radius * float(p.strength) * mult
		var d := global_position.distance_to(p.pos)
		if d <= r and d < best_d:
			best = p
			best_d = d
	return best


func _follow_scent(delta: float) -> void:
	var c := target
	var mult := Perception.scent_mult(c)
	var pts: Array = c.scent.points() if mult > 0.0 else []
	if _scent_time < 0.0:
		var start := _find_scent_start()
		if start.is_empty():
			_trail_lost += delta
			set_move_target(last_known)
			if _trail_lost > give_up_trail_time:
				_trail_lost = 0.0
				_enter(State.SEARCH)
			return
		_scent_time = float(start.time)
	tracking = true
	# current target point = first point at or after _scent_time
	var cur: Dictionary = {}
	for p in pts:
		if float(p.time) >= _scent_time - 0.001:
			cur = p
			break
	if cur.is_empty():
		_trail_lost += delta
		if _trail_lost > give_up_trail_time:
			_trail_lost = 0.0
			_scent_time = -1.0
			_enter(State.SEARCH)
		return
	_trail_lost = 0.0
	# trail gaps (erased by water): if the next point is far, the hound must re-find it nearby
	if global_position.distance_to(cur.pos) > 25.0 * mult:
		_scent_time = -1.0
		return
	set_move_target(cur.pos)
	if global_position.distance_to(cur.pos) < scent_reach_dist:
		var next_found := false
		for p in pts:
			if float(p.time) > float(cur.time) + 0.001:
				_scent_time = float(p.time)
				next_found = true
				break
		if not next_found:
			# at the freshest point: the courier is near
			last_known = c.global_position
			set_move_target(c.global_position)
	last_known = cur.pos


func _check_unreachable(delta: float) -> bool:
	if target == null:
		return false
	var dy := target.global_position.y - global_position.y
	var flat := Vector2(target.global_position.x - global_position.x, target.global_position.z - global_position.z).length()
	if dy > unreachable_height and flat < 8.0:
		_unreachable += delta
		face_towards(target.global_position, delta)
		if _unreachable > 1.0:
			_stop()
		if _unreachable > unreachable_give_up:
			_unreachable = 0.0
			_scent_time = -1.0
			tracking = false
			awareness = 0.0
			_enter(State.SEARCH)
		return _unreachable > 1.0
	_unreachable = maxf(_unreachable - delta, 0.0)
	return false


# --- lunge attack
func _attack(delta: float) -> void:
	if target == null:
		_enter(State.SEARCH)
		return
	if _state_time < attack_windup:
		_stop()
		face_towards(target.global_position, delta)
		_lunging = 0.0
		_lunge_hit = false
		var d := target.global_position - global_position
		d.y = 0
		_lunge_dir = d.normalized()
		return
	if _lunging == 0.0 and not _lunge_hit:
		_lunging = lunge_time
		Audio.play_at("hit", global_position, -10.0, 30.0, 0.3)
	if _lunging > 0.0:
		_lunging -= delta
		if not _lunge_hit and global_position.distance_to(target.global_position) < 1.3:
			_lunge_hit = true
			target.take_damage(attack_damage * damage_mult, _death_cause(), global_position)
			Events.sound_emitted.emit(global_position, 12.0, "combat")
		if _lunging <= 0.0:
			_lunging = -1.0
	if _state_time > attack_windup + lunge_time + 0.35:
		_lunging = 0.0
		_attack_cd = attack_cooldown
		_enter(State.CHASE)


func _custom_velocity(delta: float, hv: Vector3) -> void:
	if state == State.ATTACK and _lunging > 0.0:
		velocity.x = _lunge_dir.x * lunge_speed
		velocity.z = _lunge_dir.z * lunge_speed
		return
	super._custom_velocity(delta, hv)


func _on_died() -> void:
	if randf() < 0.35:
		CourierActions.spawn_pickup(self, "dried_meat", 1, global_position + Vector3.UP * 0.3)
