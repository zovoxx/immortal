class_name CourierActions
extends Node
## Courier interaction (nearest Interactable in reach) and carry-slot actions: select, use, drop.

@onready var courier: Courier = get_parent()

var selected_slot: int = 0
var focus: Node3D = null
var _hud: Node


func _ready() -> void:
	Events.inventory_changed.connect(_clamp_selection)


func _process(_delta: float) -> void:
	if courier.is_dead():
		_set_prompt("")
		return
	_update_focus()
	if not courier.input_enabled:
		return
	if Input.is_action_just_pressed("interact") and focus and is_instance_valid(focus):
		courier.interrupt_use()
		focus.interact(courier)
	if Input.is_action_just_pressed("item_next"):
		_select(selected_slot + 1)
	if Input.is_action_just_pressed("item_prev"):
		_select(selected_slot - 1)
	if Input.is_action_just_pressed("use_item"):
		use_selected()
	if Input.is_action_just_pressed("drop_item"):
		drop_selected()


func _update_focus() -> void:
	var best: Node3D = null
	var best_d := INF
	var origin := courier.global_position + Vector3.UP * 0.9
	for n in get_tree().get_nodes_in_group("interactable"):
		var i := n as Node3D
		if i == null or not i.is_visible_in_tree():
			continue
		var r: float = i.get("interact_radius") if i.get("interact_radius") != null else 2.2
		var d := origin.distance_to(i.global_position + Vector3.UP * 0.5)
		if d > r + 0.6 or d >= best_d:
			continue
		if i.get_prompt(courier) == "":
			continue
		best = i
		best_d = d
	focus = best
	if focus and courier.input_enabled:
		_set_prompt("[%s] %s" % [_key("interact"), focus.get_prompt(courier)])
	else:
		_set_prompt("")


func _key(action: String) -> String:
	return Settings.binding_label(action, Input.get_connected_joypads().size() > 0 and _last_pad())


func _last_pad() -> bool:
	return Input.get_connected_joypads().size() > 0


func _set_prompt(t: String) -> void:
	if _hud == null or not is_instance_valid(_hud):
		_hud = get_tree().get_first_node_in_group("hud")
	if _hud:
		_hud.set_prompt(t)


func _slots() -> Array[int]:
	return Game.courier.inventory.slot_indices()


func _clamp_selection() -> void:
	var n := _slots().size()
	selected_slot = clampi(selected_slot, 0, maxi(n - 1, 0))
	Events.selected_slot_changed.emit(selected_slot)


func _select(i: int) -> void:
	var n := _slots().size()
	if n == 0:
		return
	selected_slot = posmod(i, n)
	Events.selected_slot_changed.emit(selected_slot)
	Audio.play("ui_click", -14.0)


## The entry dictionary for the selected slot ({} if none).
func selected_entry() -> Dictionary:
	var s := _slots()
	if selected_slot < 0 or selected_slot >= s.size():
		return {}
	return Game.courier.inventory.entries[s[selected_slot]]


func use_selected() -> void:
	var e := selected_entry()
	if e.is_empty():
		return
	var d := ItemDB.get_def(e.id)
	match d.kind:
		ItemDef.Kind.CONSUMABLE:
			if Game.courier.hp >= Game.courier.max_hp:
				Events.notify.emit("Already at full health")
				return
			var id: String = e.id
			var amount := d.heal_amount
			if courier.begin_use(d.use_time, func():
				if Game.courier.inventory.remove_id(id, 1) > 0:
					courier.heal(amount)
					Events.inventory_changed.emit()
					Events.notify.emit("Used %s (+%d HP)" % [d.display_name, int(amount)])):
				Events.notify.emit("Using %s..." % d.display_name)
		ItemDef.Kind.THROWABLE:
			Events.notify.emit("%s ready — aim [%s], throw [%s]" % [d.display_name, _key("aim"), _key("attack")])
		ItemDef.Kind.MELEE:
			courier.set_meta("weapon", e.id)
			Events.notify.emit("Wielding %s" % d.display_name)
		ItemDef.Kind.MESSAGE:
			Events.notify.emit("The Message is sealed. It must reach the End of the Road.")


func drop_selected() -> void:
	var e := selected_entry()
	if e.is_empty():
		return
	var d := ItemDB.get_def(e.id)
	if not d.droppable:
		Events.notify.emit("The Message cannot be dropped.")
		return
	var s := _slots()
	var removed := Game.courier.inventory.remove_at(s[selected_slot])
	spawn_pickup(courier, removed.id, removed.count, courier.global_position + courier.facing * 1.0)
	Events.inventory_changed.emit()


static func spawn_pickup(context: Node, id: String, count: int, pos: Vector3) -> Pickup:
	var p := Pickup.new()
	p.item_id = id
	p.count = count
	var parent: Node = context.get_tree().get_first_node_in_group("drop_parent")
	if parent == null:
		parent = context.get_tree().current_scene
	parent.add_child(p)
	p.global_position = pos
	return p
