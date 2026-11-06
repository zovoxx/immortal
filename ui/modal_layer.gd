class_name ModalLayer
extends CanvasLayer
## Base for in-game modal windows: frees the mouse, disables courier input while open.

var _root: Control
var _vb: VBoxContainer
var visible_modal: bool = false


func _ready() -> void:
	layer = 15
	add_to_group("modal_ui")


func _make(min_size: Vector2) -> void:
	var m := UITheme.modal(self, min_size)
	_root = m[0]
	_vb = m[1]
	_root.visible = false


func open_modal() -> void:
	_root.visible = true
	visible_modal = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_set_courier_input(false)
	Events.ui_modal_changed.emit(true)


func close_modal() -> void:
	_root.visible = false
	visible_modal = false
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_set_courier_input(true)
	Events.ui_modal_changed.emit(false)


func _set_courier_input(on: bool) -> void:
	for c in get_tree().get_nodes_in_group("player"):
		if c is Courier and not (c as Courier).is_dead():
			(c as Courier).input_enabled = on


func _unhandled_input(event: InputEvent) -> void:
	if visible_modal and (event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel")):
		close_modal()
		get_viewport().set_input_as_handled()


func _clear(box: Container) -> void:
	for c in box.get_children():
		c.queue_free()

