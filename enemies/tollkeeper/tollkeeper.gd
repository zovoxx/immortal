class_name Tollkeeper
extends Enemy
## Warden at bridges and passes. Heavy, slow, telegraphed slams. Three ways past:
##   PAY   — interact while it demands the toll (price rises with zone), it steps aside for good.
##   SNEAK — it turns to watch the bridge now and then; slip behind it unseen.
##   FIGHT — high HP; dodge the wind-up.

@export var demand_radius: float = 8.0
@export var block_radius: float = 3.0
## It glances back over the bridge for `look_away_time` every `look_cycle` seconds.
@export var look_cycle: float = 11.0
@export var look_away_time: float = 4.0
@export var slam_radius: float = 2.6

var feature_id: String = ""
var hostile: bool = false
var paid: bool = false
var demanding: bool = false
var base_yaw: float = 0.0
var _price: int = 1
var _sign: Label3D
var _prompt: TollPrompt
var _mace: MeshInstance3D
var _arm: Node3D
var _look_t: float = 0.0
var _seen_courier: bool = false


func _init() -> void:
	max_hp = 220.0
	walk_speed = 2.2
	run_speed = 3.9
	sight_range = 12.0
	sight_angle_deg = 100.0
	attack_range = 2.4
	attack_damage = 30.0
	attack_cooldown = 1.7
	attack_windup = 1.0
	body_radius = 0.6
	body_height = 2.4
	eye_height = 2.3
	turn_speed = 3.0
	patrol_radius = 0.0
	model_scene = preload("res://enemies/tollkeeper/tollkeeper_model.tscn")


func set_initial_yaw(yaw: float) -> void:
	base_yaw = yaw
	if model:
		model.rotation.y = yaw


func _on_ready() -> void:
	add_to_group("tollkeeper")
	model.rotation.y = base_yaw
	_price = Difficulty.toll_price(zone_index)
	paid = Game.is_toll_paid(zone_index, feature_id) if feature_id != "" else false
	_sign = Label3D.new()
	_sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sign.position = Vector3(0, 3.3, 0)
	_sign.font_size = 44
	_sign.pixel_size = 0.01
	_sign.outline_size = 10
	add_child(_sign)
	_prompt = TollPrompt.new()
	_prompt.keeper = self
	_prompt.interact_radius = 3.5
	add_child(_prompt)
	_arm = model.get_node_or_null("WeaponArm")
	if _arm:
		_mace = _arm.get_node_or_null("Mace")
	_look_t = randf() * look_cycle
	if paid:
		_step_aside()
	_update_sign()


func _death_cause() -> String:
	return "crushed by a toll-keeper"


func price() -> int:
	return _price


func _update_sign() -> void:
	if hostile:
		_sign.text = ""
	elif paid:
		_sign.text = "Safe travels."
		_sign.modulate = Color(0.7, 0.9, 0.7)
	elif demanding:
		_sign.text = "TOLL: %d item%s" % [_price, "s" if _price > 1 else ""]
		_sign.modulate = UITheme.ACCENT
	else:
		_sign.text = ""


func _guard_yaw() -> float:
	_look_t += get_physics_process_delta_time()
	var phase := fmod(_look_t, look_cycle)
	return base_yaw + (PI if phase > look_cycle - look_away_time else 0.0)


func _think(delta: float) -> void:
	if hostile or state in [State.DEAD, State.STUNNED]:
		if hostile and state in [State.IDLE, State.PATROL]:
			_enter(State.RETURN)
		if hostile and state == State.RETURN and _reached():
			hostile = target != null and global_position.distance_to(target.global_position) < 20.0
			_enter(State.IDLE)
			_update_sign()
		super._think(delta)
		return
	# peaceful guard (a paid keeper just walks to its spot beside the road)
	if paid:
		set_move_target(home_global())
	else:
		_stop()
	if not paid:
		var yaw := _guard_yaw()
		model.rotation.y = lerp_angle(model.rotation.y, yaw, clampf(delta * turn_speed, 0.0, 1.0))
	if target == null or target.is_dead() or paid:
		demanding = false
		_update_sign()
		return
	var d := global_position.distance_to(target.global_position)
	if sees_player and d < demand_radius:
		_seen_courier = true
		demanding = true
	elif d > demand_radius * 1.5:
		demanding = false
		_seen_courier = false
	# the courier slipped past while it was watching: that's an insult
	if demanding and _seen_courier and d < block_radius + 3.0:
		var to := target.global_position - global_position
		to.y = 0
		var fwd := Vector3(-sin(base_yaw), 0, -cos(base_yaw))
		if fwd.dot(to) < -0.3:
			become_hostile()
	_update_sign()


## Peaceful wardens don't chase on sight; they demand.
func _on_spotted() -> void:
	if hostile:
		_enter(State.CHASE)


func _sense(dt: float) -> void:
	super._sense(dt)
	if not hostile and state == State.SUSPICIOUS:
		_enter(State.IDLE)


func _on_sound(pos: Vector3, radius: float, kind: String) -> void:
	if hostile:
		super._on_sound(pos, radius, kind)


func become_hostile() -> void:
	if hostile or state == State.DEAD:
		return
	hostile = true
	demanding = false
	awareness = 1.2
	if target:
		last_known = target.global_position
	_update_sign()
	Audio.play_at("toll_slam", global_position, 0.0)
	_enter(State.CHASE)


func _on_damaged() -> void:
	become_hostile()
	if state != State.ATTACK:
		_enter(State.CHASE)


func can_pay() -> bool:
	return _payable_units() >= _price


func _payable_units() -> int:
	var n := 0
	for e in Game.courier.inventory.droppable_entries():
		n += int(e.count)
	return n


## Pays the toll: takes the least valuable items first.
func pay() -> bool:
	if paid or hostile or not can_pay():
		return false
	var inv := Game.courier.inventory
	var remaining := _price
	var entries := inv.droppable_entries()
	entries.sort_custom(func(a, b): return ItemDB.get_def(a.id).value < ItemDB.get_def(b.id).value)
	var taken: PackedStringArray = []
	for e in entries:
		if remaining <= 0:
			break
		var n := inv.remove_id(e.id, mini(remaining, int(e.count)))
		remaining -= n
		taken.append("%s x%d" % [ItemDB.display_name(e.id), n])
	paid = true
	demanding = false
	if feature_id != "":
		Game.mark_toll_paid(zone_index, feature_id)
	Events.inventory_changed.emit()
	Events.notify.emit("Toll paid: " + ", ".join(taken))
	_step_aside()
	_update_sign()
	return true


func _step_aside() -> void:
	var side := Vector3(cos(base_yaw), 0, -sin(base_yaw)) * 3.2
	home_local = home_local + side
	set_move_target(home_global())
	_enter(State.RETURN)


# --- telegraphed slam
func _attack(delta: float) -> void:
	_stop()
	if target == null:
		_enter(State.SEARCH)
		return
	var t := _state_time / attack_windup
	if _arm:
		_arm.rotation.x = lerpf(0.0, -2.6, clampf(t, 0.0, 1.0)) if t < 1.0 else lerpf(-2.6, 0.4, clampf((t - 1.0) * 6.0, 0.0, 1.0))
	if _mace:
		_mace.material_override = Geo.mat(Color(1.0, 0.2, 0.1), 0.6, 3.0 * clampf(t, 0.0, 1.0)) if t < 1.0 else null
	if _state_time < attack_windup * 0.7:
		face_towards(target.global_position, delta)
	if _state_time >= attack_windup and not has_meta("_struck"):
		set_meta("_struck", true)
		Audio.play_at("toll_slam", global_position, 2.0)
		Events.sound_emitted.emit(global_position, 18.0, "combat")
		var to := target.global_position - global_position
		to.y = 0
		if to.length() < slam_radius + 0.5 and forward().dot(to.normalized()) > 0.2:
			target.take_damage(attack_damage * damage_mult, _death_cause(), global_position)
		var c := target.camera_rig
		if c and to.length() < 8.0:
			c.shake(0.5)
	if _state_time > attack_windup + 0.6:
		remove_meta("_struck")
		if _arm:
			_arm.rotation.x = 0.0
		if _mace:
			_mace.material_override = null
		_attack_cd = attack_cooldown
		_enter(State.CHASE)


func _on_died() -> void:
	_sign.text = ""
	for i in 3:
		var id: String = ["scrap", "cloth", "oil", "bandage"][randi() % 4]
		CourierActions.spawn_pickup(self, id, 1 + (randi() % 2 if id != "bandage" else 0), global_position + Vector3(randf_range(-1, 1), 0.3, randf_range(-1, 1)))


func state_name() -> String:
	if not hostile and state != State.DEAD:
		return "PAID" if paid else ("DEMAND" if demanding else "GUARD")
	return super.state_name()


class TollPrompt extends Interactable:
	var keeper: Tollkeeper

	func get_prompt(_c: Node) -> String:
		if keeper == null or keeper.paid or keeper.hostile or keeper.is_dead():
			return ""
		if not keeper.can_pay():
			return "Toll: %d items (you can't pay)" % keeper.price()
		return "Pay the toll (%d item%s)" % [keeper.price(), "s" if keeper.price() > 1 else ""]

	func interact(_c: Node) -> void:
		if keeper.can_pay():
			keeper.pay()
		else:
			Events.notify.emit("You don't carry enough to pay.")
