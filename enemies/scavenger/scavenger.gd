class_name Scavenger
extends Enemy
## Crow-folk scavenger. Walks to the nearest corpse with loot and steals one item every
## Game.config.scavenger_steal_interval seconds. Cowardly: flees from the courier, fights only when
## cornered. Killing it drops everything it stole.

@export var flee_radius: float = 9.0
@export var cornered_radius: float = 2.0
@export var loot_reach: float = 1.8

var stolen: Array = []  # [{id, count}]
var corpse_target: Corpse
var _steal_timer: float = 0.0
var _corpse_scan: float = 0.0
var _flee_stuck: float = 0.0


func _init() -> void:
	max_hp = 28.0
	walk_speed = 3.2
	run_speed = 6.8
	sight_range = 14.0
	sight_angle_deg = 160.0
	attack_range = 1.6
	attack_damage = 6.0
	attack_cooldown = 1.0
	attack_windup = 0.25
	body_radius = 0.3
	body_height = 1.3
	eye_height = 1.15
	model_scene = preload("res://enemies/scavenger/scavenger_model.tscn")


func _on_ready() -> void:
	add_to_group("scavenger")
	_steal_timer = Game.config.scavenger_steal_interval


func _death_cause() -> String:
	return "pecked to death by a scavenger"


func _on_spotted() -> void:
	_enter(State.FLEE)


func _on_damaged() -> void:
	_enter(State.FLEE)


func _on_sound(pos: Vector3, radius: float, kind: String) -> void:
	if state == State.DEAD:
		return
	if global_position.distance_to(pos) <= radius and kind in ["combat", "land", "footstep", "noise_maker"]:
		if target and global_position.distance_to(target.global_position) < flee_radius * 1.5:
			_enter(State.FLEE)


func _think(delta: float) -> void:
	match state:
		State.FLEE:
			_flee(delta)
			return
		State.ATTACK:
			super._attack(delta)
			return
		State.DEAD, State.STUNNED:
			super._think(delta)
			return
	# not fleeing: is the courier close and visible?
	if target and not target.is_dead() and sees_player and global_position.distance_to(target.global_position) < flee_radius:
		_enter(State.FLEE)
		return
	_corpse_scan -= delta
	if _corpse_scan <= 0.0:
		_corpse_scan = 3.0
		if corpse_target == null or not is_instance_valid(corpse_target) or not corpse_target.has_loot():
			corpse_target = _nearest_corpse()
	if corpse_target and is_instance_valid(corpse_target) and corpse_target.has_loot():
		if state != State.LOOT:
			_enter(State.LOOT)
		_loot(delta)
	elif state == State.LOOT:
		_enter(State.PATROL)
	else:
		super._think(delta)


func _nearest_corpse() -> Corpse:
	var best: Corpse = null
	var best_d := INF
	for n in get_tree().get_nodes_in_group("corpse"):
		var c := n as Corpse
		if c == null or not c.has_loot():
			continue
		var d := global_position.distance_to(c.global_position)
		if d < best_d:
			best = c
			best_d = d
	return best


func _loot(delta: float) -> void:
	var p := corpse_target.global_position
	if global_position.distance_to(p) > loot_reach:
		set_move_target(p)
		return
	_stop()
	face_towards(p, delta)
	_steal_timer -= delta
	if _steal_timer <= 0.0:
		_steal_timer = Game.config.scavenger_steal_interval
		steal_now()


## Takes one item from the current corpse (also used by tests).
func steal_now() -> Dictionary:
	if corpse_target == null or not is_instance_valid(corpse_target):
		return {}
	var item := Game.steal_from_corpse(corpse_target.corpse_id())
	if not item.is_empty():
		stolen.append(item)
		Audio.play_at("scav_caw", global_position, -6.0)
		Events.inventory_changed.emit()
	return item


func current_speed() -> float:
	return (run_speed if state == State.FLEE else walk_speed) * speed_mult


func _flee(delta: float) -> void:
	if target == null or target.is_dead():
		_enter(State.RETURN)
		return
	var away := global_position - target.global_position
	away.y = 0
	var d := away.length()
	if d > flee_radius * 2.2 and _state_time > 3.0:
		_enter(State.LOOT if corpse_target else State.RETURN)
		return
	# cornered: can't get away and the courier is on top of it
	if d < cornered_radius or _stuck_time > 1.2:
		_flee_stuck += delta
		if d < attack_range + 0.6 and _attack_cd <= 0.0:
			_enter(State.ATTACK)
			return
	else:
		_flee_stuck = 0.0
	var dir := away.normalized() if d > 0.1 else Vector3.FORWARD
	# veer sideways when stuck
	if _stuck_time > 0.6:
		dir = dir.rotated(Vector3.UP, PI * 0.5 * (1.0 if int(_state_time) % 2 == 0 else -1.0))
	set_move_target(global_position + dir * 6.0)


func _attack(delta: float) -> void:
	super._attack(delta)


func _strike() -> void:
	super._strike()
	_attack_cd = attack_cooldown


func _on_state_entered(s: State) -> void:
	if s == State.CHASE:
		# scavengers never chase: they flee
		call_deferred("_enter", State.FLEE)


func _on_died() -> void:
	var items := stolen.duplicate()
	if randf() < 0.6:
		items.append({"id": "feathers", "count": randi_range(1, 2)})
	if items.is_empty():
		return
	var bag := LootBag.new()
	var parent := get_parent()
	parent.add_child(bag)
	bag.global_position = global_position
	bag.set_items(items)
	stolen.clear()
