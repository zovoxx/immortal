class_name CompassStrip
extends Control
## Horizontal compass at the top of the HUD: cardinal ticks, station direction, last corpse,
## and short-lived sound alerts (howls, bells, thunder).

const SPAN := PI  # degrees of view covered by the strip

var courier: Node3D
var targets: Array = []  # {pos: Vector3, label: String, color: Color}
var alerts: Array = []   # {pos, label, color, time}


func _ready() -> void:
	custom_minimum_size = Vector2(640, 36)
	Events.compass_alert.connect(_on_alert)


func _on_alert(pos: Vector3, kind: String) -> void:
	var c := UITheme.DANGER
	var l := "!"
	match kind:
		"howl": l = "~"
		"bell": l = "B"
		"lightning": l = "*"; c = Color(0.7, 0.8, 1.0)
		"sound": l = "?"; c = UITheme.DIM
	alerts.append({"pos": pos, "label": l, "color": c, "time": 4.0})


func _process(delta: float) -> void:
	for a in alerts:
		a.time -= delta
	alerts = alerts.filter(func(a): return a.time > 0.0)
	queue_redraw()


func _yaw() -> float:
	if courier and courier.get("camera_rig"):
		return courier.camera_rig.yaw_node.global_rotation.y
	return 0.0


func _x_for(angle: float) -> float:
	return size.x * 0.5 + angle / (SPAN * 0.5) * size.x * 0.5


func _rel_angle_to(pos: Vector3) -> float:
	if courier == null:
		return 0.0
	var d := pos - courier.global_position
	var a := atan2(-d.x, -d.z)
	return wrapf(a - _yaw(), -PI, PI) * -1.0


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.35))
	var font := get_theme_default_font()
	var yaw := _yaw()
	var cardinals := {"N": PI, "E": PI * 0.5, "S": 0.0, "W": -PI * 0.5}
	for k in cardinals:
		var a := wrapf(cardinals[k] - yaw, -PI, PI) * -1.0
		if absf(a) < SPAN * 0.5:
			var x := _x_for(a)
			draw_string(font, Vector2(x - 6, 24), k, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, UITheme.DIM)
	for i in 24:
		var a := wrapf(float(i) / 24.0 * TAU - yaw, -PI, PI)
		if absf(a) < SPAN * 0.5:
			var x := _x_for(-a)
			draw_line(Vector2(x, 30), Vector2(x, 35), Color(1, 1, 1, 0.25), 1.0)
	if courier == null:
		return
	for t in targets + alerts:
		var a := _rel_angle_to(t.pos)
		var clamped := clampf(a, -SPAN * 0.5, SPAN * 0.5)
		var x := _x_for(clamped)
		var col: Color = t.color
		if absf(a) > SPAN * 0.5:
			col.a = 0.5
		var tw := font.get_string_size(t.label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		draw_string(font, Vector2(x - tw * 0.5, 22), t.label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, col)
		if t.has("dist") and t.dist:
			var dist := int(courier.global_position.distance_to(t.pos))
			draw_string(font, Vector2(x - 12, 35), "%dm" % dist, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, col)
	draw_line(Vector2(size.x * 0.5, 0), Vector2(size.x * 0.5, 6), UITheme.ACCENT, 2.0)
