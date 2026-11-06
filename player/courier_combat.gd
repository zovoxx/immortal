class_name CourierCombat
extends Node
## Blade (light tap / charged hold), sling aiming and throwing (stones, noise-makers, smoke pots,
## caltrops, fire pots). The dodge roll lives in Courier (it's movement).

@export var charge_time: float = 0.65
@export var light_cooldown: float = 0.45
@export var charged_cooldown: float = 0.8
@export var throw_cooldown: float = 0.6
@export var throw_speed: float = 30.0
@export var fist_damage: float = 6.0
@export var combat_noise: float = 14.0
@export var melee_cone_dot: float = 0.35

@onready var courier: Courier = get_parent()
@onready var actions: CourierActions = get_parent().get_node("Actions")

var _attack_held: float = -1.0
var _cooldown: float = 0.0
var _swing_pose: float = 0.0


func _process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	_swing_pose = maxf(_swing_pose - delta, 0.0)
	if courier.is_dead() or not courier.input_enabled:
		courier.aiming = false
		_attack_held = -1.0
		return
	var can_act := courier.state == Courier.State.MOVE
	courier.aiming = can_act and Input.is_action_pressed("aim")
	if courier.aiming:
		_attack_held = -1.0
		if Input.is_action_just_pressed("attack") and _cooldown <= 0.0:
			throw_selected()
		return
	if Input.is_action_just_pressed("attack") and can_act:
		_attack_held = 0.0
	if _attack_held >= 0.0:
		_attack_held += delta
		if not Input.is_action_pressed("attack"):
			var charged := _attack_held >= charge_time
			_attack_held = -1.0
			if _cooldown <= 0.0 and can_act:
				melee(charged)


func charge_ratio() -> float:
	return clampf(_attack_held / charge_time, 0.0, 1.0) if _attack_held >= 0.0 else 0.0


func weapon_def() -> ItemDef:
	var inv := Game.courier.inventory
	var chosen := String(courier.get_meta("weapon", ""))
	if chosen != "" and inv.has(chosen):
		return ItemDB.get_def(chosen)
	var best: ItemDef = null
	for e in inv.entries:
		var d := ItemDB.get_def(e.id)
		if d and d.kind == ItemDef.Kind.MELEE and (best == null or d.light_damage > best.light_damage):
			best = d
	return best


## Swings the current weapon. Returns how many enemies were hit.
func melee(charged: bool) -> int:
	var w := weapon_def()
	var dmg := fist_damage
	var reach := 1.2
	var speed := 1.0
	if w:
		dmg = w.charged_damage if charged else w.light_damage
		reach = w.reach
		speed = w.swing_speed
	elif charged:
		dmg *= 2.0
	dmg *= Game.courier.melee_damage_mult()
	_cooldown = (charged_cooldown if charged else light_cooldown) / maxf(speed, 0.1)
	_swing_pose = 0.25
	Audio.play_at("swing", courier.global_position, -6.0)
	courier.emit_noise(combat_noise, "combat")
	var hits := 0
	var origin := courier.global_position + Vector3.UP * 1.0
	var fwd := courier.facing
	for n in courier.get_tree().get_nodes_in_group("enemy"):
		var e := n as Enemy
		if e == null or e.is_dead():
			continue
		var to := e.global_position + Vector3.UP * 0.6 - origin
		var flat := Vector3(to.x, 0, to.z)
		if flat.length() > reach + e.body_radius + 0.3 or absf(to.y) > 2.0:
			continue
		if flat.length() > 0.4 and fwd.dot(flat.normalized()) < melee_cone_dot:
			continue
		e.take_damage(dmg, courier.global_position, "blade")
		if charged:
			e.stun(0.6)
		hits += 1
	if hits > 0:
		courier.camera_rig.shake(0.15 if not charged else 0.3)
	return hits


## The throwable used by the sling: the selected slot if it's throwable, else sling stones.
func current_throwable() -> String:
	var e := actions.selected_entry()
	if not e.is_empty():
		var d := ItemDB.get_def(e.id)
		if d and d.kind == ItemDef.Kind.THROWABLE:
			return e.id
	if Game.courier.inventory.has("sling_stones"):
		return "sling_stones"
	return ""


func throw_selected() -> bool:
	var id := current_throwable()
	if id == "":
		Events.notify.emit("Nothing to throw")
		return false
	var target := courier.camera_rig.aim_point(courier.get_world_3d().direct_space_state, [courier.get_rid()])
	return throw_item(id, target)


func throw_item(id: String, target: Vector3) -> bool:
	var d := ItemDB.get_def(id)
	if d == null or Game.courier.inventory.remove_id(id, 1) <= 0:
		return false
	Events.inventory_changed.emit()
	_cooldown = throw_cooldown
	var from := courier.global_position + Vector3.UP * 1.5 + courier.facing * 0.4
	var p := Projectile.new()
	p.kind = d.throw_kind
	p.damage = d.throw_damage
	p.thrower = courier
	var parent: Node = courier.get_tree().get_first_node_in_group("drop_parent")
	if parent == null:
		parent = courier.get_parent()
	parent.add_child(p)
	p.global_position = from
	var dir := (target - from)
	var dist := dir.length()
	dir = dir.normalized()
	# compensate gravity a little for long throws
	var t := dist / throw_speed
	p.velocity = dir * throw_speed + Vector3.UP * (0.5 * Projectile.GRAVITY * t)
	Audio.play_at("throw", from, -6.0)
	courier.emit_noise(4.0, "throw")
	return true


func is_swinging() -> bool:
	return _swing_pose > 0.0
