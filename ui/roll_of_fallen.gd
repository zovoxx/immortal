extends CanvasLayer
## THE ROLL OF THE FALLEN: every dead courier with name, traits, zone reached, cause and time lived.

func _ready() -> void:
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS
	var m := UITheme.modal(self, Vector2(980, 600))
	var vb: VBoxContainer = m[1]
	vb.add_child(UITheme.title("THE ROLL OF THE FALLEN"))
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(940, 460)
	vb.add_child(sc)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(list)
	if Game.fallen.is_empty():
		list.add_child(UITheme.label("No courier has fallen yet. The road is patient.", 20, UITheme.DIM))
	var entries := Game.fallen.duplicate()
	entries.reverse()
	for f in entries:
		var traits: PackedStringArray = []
		for t in f.get("traits", []):
			var tr := TraitDB.get_trait(String(t))
			traits.append(tr.display_name if tr else String(t))
		var row := VBoxContainer.new()
		row.add_child(UITheme.label("Courier #%d  —  %s" % [int(f.get("index", 0)), f.get("name", "?")], 22, UITheme.ACCENT))
		row.add_child(UITheme.label("%s   ·   reached Zone %d   ·   %s   ·   lived %s" % [
			", ".join(traits) if not traits.is_empty() else "no traits", int(f.get("zone", 0)) + 1,
			f.get("cause", "unknown"), _fmt(float(f.get("lived", 0.0)))], 17, UITheme.INK, true))
		list.add_child(row)
		list.add_child(HSeparator.new())
	var b := UITheme.button("Close", queue_free)
	vb.add_child(b)
	b.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		queue_free()


static func _fmt(sec: float) -> String:
	var s := int(sec)
	if s < 60:
		return "%ds" % s
	if s < 3600:
		return "%dm %ds" % [s / 60, s % 60]
	return "%dh %dm" % [s / 3600, (s % 3600) / 60]
