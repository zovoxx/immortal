class_name UITheme
extends RefCounted
## Shared look for all menus (placeholder parchment/ink style).

const INK := Color(0.93, 0.88, 0.78)
const DIM := Color(0.65, 0.6, 0.52)
const ACCENT := Color(0.91, 0.64, 0.24)
const DANGER := Color(0.9, 0.3, 0.22)
const PANEL := Color(0.08, 0.07, 0.06, 0.88)

static var _theme: Theme


static func get_theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font_size = 20
	var panel := StyleBoxFlat.new()
	panel.bg_color = PANEL
	panel.border_color = Color(0.45, 0.38, 0.28)
	panel.set_border_width_all(2)
	panel.set_corner_radius_all(4)
	panel.set_content_margin_all(14)
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "Panel", panel)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(3)
		sb.set_content_margin_all(8)
		sb.content_margin_left = 16
		sb.content_margin_right = 16
		match state:
			"normal": sb.bg_color = Color(0.18, 0.15, 0.12, 0.95)
			"hover": sb.bg_color = Color(0.32, 0.25, 0.16, 0.95)
			"pressed": sb.bg_color = Color(0.45, 0.32, 0.15, 0.95)
			"focus":
				sb.bg_color = Color(0, 0, 0, 0)
				sb.border_color = ACCENT
				sb.set_border_width_all(2)
			"disabled": sb.bg_color = Color(0.12, 0.11, 0.1, 0.8)
		t.set_stylebox(state, "Button", sb)
	t.set_color("font_color", "Button", INK)
	t.set_color("font_hover_color", "Button", Color(1, 0.95, 0.8))
	t.set_color("font_disabled_color", "Button", Color(0.45, 0.42, 0.38))
	t.set_color("font_color", "Label", INK)
	t.set_color("default_color", "RichTextLabel", INK)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.1, 0.09, 0.08, 0.8)
	bg.set_corner_radius_all(2)
	var fill := StyleBoxFlat.new()
	fill.bg_color = ACCENT
	fill.set_corner_radius_all(2)
	t.set_stylebox("background", "ProgressBar", bg)
	t.set_stylebox("fill", "ProgressBar", fill)
	_theme = t
	return t


static func title(text: String, size: int = 40) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", ACCENT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


static func label(text: String, size: int = 20, color: Color = INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func button(text: String, cb: Callable, min_width: float = 280.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_width, 44)
	b.pressed.connect(func():
		Audio.play("ui_click", -8.0, 0.0)
		cb.call())
	return b


static func bar(color: Color, w: float = 260.0, h: float = 14.0) -> ProgressBar:
	var p := ProgressBar.new()
	p.custom_minimum_size = Vector2(w, h)
	p.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(2)
	p.add_theme_stylebox_override("fill", fill)
	return p


## A full-screen dim backdrop with a centred panel. Returns [root, vbox].
static func modal(parent: Node, min_size: Vector2 = Vector2(560, 400)) -> Array:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.theme = get_theme()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = min_size
	center.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	panel.add_child(vb)
	parent.add_child(root)
	return [root, vb]
