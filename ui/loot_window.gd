extends ModalLayer
## Transfer items between a container (corpse, cache, sack, stash) and the courier's carry slots.

var container: ItemContainer
var _title: Label
var _left: VBoxContainer
var _right: VBoxContainer
var _info: Label


func _ready() -> void:
	super._ready()
	_make(Vector2(820, 460))
	_title = UITheme.title("Container", 30)
	_vb.add_child(_title)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 30)
	_vb.add_child(cols)
	var lcol := VBoxContainer.new()
	lcol.custom_minimum_size = Vector2(380, 300)
	cols.add_child(lcol)
	lcol.add_child(UITheme.label("CONTENTS", 16, UITheme.DIM))
	_left = VBoxContainer.new()
	lcol.add_child(_left)
	var rcol := VBoxContainer.new()
	rcol.custom_minimum_size = Vector2(380, 300)
	cols.add_child(rcol)
	rcol.add_child(UITheme.label("YOU CARRY", 16, UITheme.DIM))
	_right = VBoxContainer.new()
	rcol.add_child(_right)
	_info = UITheme.label("", 16, UITheme.DIM)
	_vb.add_child(_info)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_vb.add_child(row)
	row.add_child(UITheme.button("Take all", _take_all, 200))
	row.add_child(UITheme.button("Close", close_modal, 200))
	Events.open_container.connect(_on_open)


func _on_open(c: Object, title: String) -> void:
	container = c as ItemContainer
	_title.text = title
	_refresh()
	open_modal()
	var b := _root.find_children("*", "Button", true, false)
	if not b.is_empty():
		(b[0] as Button).grab_focus()


func _refresh() -> void:
	_clear(_left)
	_clear(_right)
	if container == null:
		return
	var inv := Game.courier.inventory
	if container.inventory.entries.is_empty():
		_left.add_child(UITheme.label("(empty)", 18, UITheme.DIM))
	for i in container.inventory.entries.size():
		var e: Dictionary = container.inventory.entries[i]
		var d := ItemDB.get_def(e.id)
		var idx := i
		var b := UITheme.button("Take  %s x%d  (%s)" % [d.display_name, e.count, _w(d)], func(): _take(idx), 360)
		b.disabled = inv.can_add(e.id, 1) <= 0
		_left.add_child(b)
	for i in inv.entries.size():
		var e: Dictionary = inv.entries[i]
		var d := ItemDB.get_def(e.id)
		var idx := i
		if container.allow_put and d.droppable:
			_right.add_child(UITheme.button("Store  %s x%d" % [d.display_name, e.count], func(): _put(idx), 360))
		else:
			_right.add_child(UITheme.label("%s x%d  (%s)" % [d.display_name, e.count, _w(d)], 18))
	_info.text = "Carry slots %d/%d" % [inv.used_slots(), inv.capacity]
	if container.allow_put:
		_info.text += "    ·    Stash slots %d/%d" % [container.inventory.used_slots(), container.inventory.capacity]


func _w(d: ItemDef) -> String:
	return "pouch" if d.weight == 0 else "%d slot%s" % [d.weight, "s" if d.weight > 1 else ""]


func _take(i: int) -> void:
	if i >= container.inventory.entries.size():
		return
	var e: Dictionary = container.inventory.entries[i]
	var n := Game.courier.inventory.add(e.id, int(e.count))
	if n > 0:
		container.inventory.remove_at(i, n)
		Audio.play("pickup", -8.0)
	_changed()


func _take_all() -> void:
	for i in range(container.inventory.entries.size() - 1, -1, -1):
		var e: Dictionary = container.inventory.entries[i]
		var n := Game.courier.inventory.add(e.id, int(e.count))
		if n > 0:
			container.inventory.remove_at(i, n)
	Audio.play("pickup", -8.0)
	_changed()


func _put(i: int) -> void:
	var inv := Game.courier.inventory
	if i >= inv.entries.size():
		return
	var e: Dictionary = inv.entries[i]
	var n := container.inventory.add(e.id, int(e.count))
	if n > 0:
		inv.remove_at(i, n)
	else:
		Events.notify.emit("The stash is full")
	_changed()


func _changed() -> void:
	container.changed()
	Events.inventory_changed.emit()
	_refresh()
