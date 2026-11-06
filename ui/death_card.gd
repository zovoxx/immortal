extends CanvasLayer
## Death card shown after the slow-motion fade: "Mira the Third fell in Zone 14 — struck by lightning."

signal continued()

var _root: Control
var _fade: ColorRect
var _card: VBoxContainer
var _text: Label
var _sub: Label
var _ready_to_continue: bool = false


func _ready() -> void:
	layer = 18
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = UITheme.get_theme()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_fade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)
	_card = VBoxContainer.new()
	_card.add_theme_constant_override("separation", 18)
	center.add_child(_card)
	_text = UITheme.title("", 40)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(1000, 0)
	_card.add_child(_text)
	_sub = UITheme.label("", 20, UITheme.DIM)
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card.add_child(_sub)
	_card.modulate.a = 0.0
	_root.visible = false


func show_death(courier_name: String, zone_index: int, cause: String, lived: float, next_station: int) -> void:
	_root.visible = true
	_ready_to_continue = false
	_text.text = "%s fell in Zone %d — %s." % [courier_name, zone_index + 1, cause]
	_sub.text = "Carried the Message for %s.\nTheir body and everything they carried lie where they fell.\nA new courier waits at Relay %d.\n\n[press any key]" % [_fmt(lived), next_station]
	var tw := create_tween().set_ignore_time_scale(true)
	tw.tween_property(_fade, "color:a", 0.92, 1.4)
	tw.tween_property(_card, "modulate:a", 1.0, 0.6)
	tw.tween_callback(func(): _ready_to_continue = true)


func hide_card() -> void:
	var tw := create_tween().set_ignore_time_scale(true)
	tw.tween_property(_card, "modulate:a", 0.0, 0.3)
	tw.tween_property(_fade, "color:a", 0.0, 0.8)
	tw.tween_callback(func(): _root.visible = false)


func _input(event: InputEvent) -> void:
	if not _ready_to_continue or not _root.visible:
		return
	if (event is InputEventKey or event is InputEventJoypadButton or event is InputEventMouseButton) and event.is_pressed():
		_ready_to_continue = false
		get_viewport().set_input_as_handled()
		continued.emit()


## For tests/automation.
func force_continue() -> void:
	_ready_to_continue = false
	continued.emit()


static func _fmt(sec: float) -> String:
	var s := int(sec)
	if s < 60:
		return "%d seconds" % s
	if s < 3600:
		return "%d min %d s" % [s / 60, s % 60]
	return "%d h %d min" % [s / 3600, (s % 3600) / 60]
