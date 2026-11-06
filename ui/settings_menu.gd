extends CanvasLayer
## Settings: mouse/pad sensitivity, invert Y, FOV, graphics quality, volumes, fullscreen and key
## rebinding (keyboard/mouse and gamepad columns). Saved to user://relay_settings.json on close.

var _root: Control
var _bind_buttons: Dictionary = {}  # "action|pad" -> Button
var _waiting_action: String = ""
var _waiting_pad: bool = false
var _hint: Label


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	var m := UITheme.modal(self, Vector2(1000, 600))
	_root = m[0]
	var vb: VBoxContainer = m[1]
	vb.add_child(UITheme.title("SETTINGS"))
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(960, 460)
	vb.add_child(sc)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(list)

	list.add_child(UITheme.label("CONTROLS", 18, UITheme.ACCENT))
	_slider(list, "Mouse sensitivity", 0.05, 1.0, 0.01, Settings.mouse_sensitivity, func(v): Settings.mouse_sensitivity = v)
	_slider(list, "Gamepad look speed", 1.0, 6.0, 0.1, Settings.gamepad_sensitivity, func(v): Settings.gamepad_sensitivity = v)
	_check(list, "Invert Y", Settings.invert_y, func(v): Settings.invert_y = v)
	list.add_child(UITheme.label("VIDEO", 18, UITheme.ACCENT))
	_slider(list, "Field of view", 60.0, 100.0, 1.0, Settings.fov, func(v): Settings.fov = v)
	var row := _row(list, "Graphics quality")
	var ob := OptionButton.new()
	for q in ["Low (no shadows/SSAO/fog, 60% scale)", "Medium", "High"]:
		ob.add_item(q)
	ob.selected = Settings.quality
	ob.custom_minimum_size = Vector2(380, 40)
	ob.item_selected.connect(func(i): Settings.quality = i; Settings.save_settings())
	row.add_child(ob)
	_check(list, "Fullscreen", Settings.fullscreen, func(v): Settings.fullscreen = v; Settings.apply_window())
	list.add_child(UITheme.label("AUDIO", 18, UITheme.ACCENT))
	_slider(list, "Master volume", 0.0, 1.0, 0.01, Settings.master_volume, func(v): Settings.master_volume = v; Settings.apply_audio())
	_slider(list, "Music volume", 0.0, 1.0, 0.01, Settings.music_volume, func(v): Settings.music_volume = v; Settings.apply_audio())
	_slider(list, "SFX volume", 0.0, 1.0, 0.01, Settings.sfx_volume, func(v): Settings.sfx_volume = v; Settings.apply_audio())

	list.add_child(UITheme.label("KEY BINDINGS  (click, then press a key / button — Esc cancels)", 18, UITheme.ACCENT))
	var head := _row(list, "")
	head.add_child(UITheme.label("Keyboard / mouse", 15, UITheme.DIM))
	var pad_head := UITheme.label("Gamepad", 15, UITheme.DIM)
	pad_head.custom_minimum_size = Vector2(220, 0)
	head.add_child(pad_head)
	for entry in InputDefaults.REBINDABLE:
		var action: String = entry[0]
		var r := _row(list, entry[1])
		for pad in [false, true]:
			var b := Button.new()
			b.custom_minimum_size = Vector2(220, 36)
			var is_pad: bool = pad
			b.pressed.connect(func(): _start_rebind(action, is_pad))
			r.add_child(b)
			_bind_buttons["%s|%s" % [action, pad]] = b
	_hint = UITheme.label("", 16, UITheme.DIM)
	vb.add_child(_hint)
	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(bottom)
	bottom.add_child(UITheme.button("Reset bindings", func(): Settings.reset_bindings(); _refresh_bindings(), 220))
	var close := UITheme.button("Save & close", _close, 220)
	bottom.add_child(close)
	_refresh_bindings()
	close.grab_focus()


func _row(parent: Container, text: String) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 14)
	var l := UITheme.label(text, 18)
	l.custom_minimum_size = Vector2(280, 0)
	r.add_child(l)
	parent.add_child(r)
	return r


func _slider(parent: Container, text: String, lo: float, hi: float, step: float, value: float, cb: Callable) -> void:
	var r := _row(parent, text)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = value
	s.custom_minimum_size = Vector2(380, 30)
	var vl := UITheme.label(_fmt(value, step), 16, UITheme.DIM)
	s.value_changed.connect(func(v): cb.call(v); vl.text = _fmt(v, step))
	r.add_child(s)
	r.add_child(vl)


func _fmt(v: float, step: float) -> String:
	return ("%d" % int(v)) if step >= 1.0 else ("%.2f" % v)


func _check(parent: Container, text: String, value: bool, cb: Callable) -> void:
	var r := _row(parent, text)
	var c := CheckBox.new()
	c.button_pressed = value
	c.toggled.connect(cb)
	r.add_child(c)


func _refresh_bindings() -> void:
	for key in _bind_buttons:
		var parts: PackedStringArray = String(key).split("|")
		(_bind_buttons[key] as Button).text = Settings.binding_label(parts[0], parts[1] == "true")


func _start_rebind(action: String, pad: bool) -> void:
	_waiting_action = action
	_waiting_pad = pad
	(_bind_buttons["%s|%s" % [action, pad]] as Button).text = "press a button..." if pad else "press a key..."
	_hint.text = "Rebinding '%s' — Esc to cancel" % action


func _input(event: InputEvent) -> void:
	if _waiting_action == "":
		if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			_close()
		return
	if event is InputEventKey and event.pressed and (event as InputEventKey).physical_keycode == KEY_ESCAPE:
		_finish_rebind()
		get_viewport().set_input_as_handled()
		return
	var accept := false
	if _waiting_pad:
		accept = (event is InputEventJoypadButton and event.pressed) or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.6)
	else:
		accept = (event is InputEventKey and event.pressed and not event.echo) or (event is InputEventMouseButton and event.pressed)
	if accept:
		get_viewport().set_input_as_handled()
		Settings.rebind(_waiting_action, event)
		_finish_rebind()


func _finish_rebind() -> void:
	_waiting_action = ""
	_hint.text = ""
	_refresh_bindings()


func _close() -> void:
	Settings.save_settings()
	queue_free()
