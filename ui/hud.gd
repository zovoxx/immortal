extends CanvasLayer
## In-game HUD: health, stamina (fades when unchanged), carry slots, compass, momentum pips,
## zone + biome, storm warning, interaction prompt, crosshair, notifications, damage vignette.

var courier: Node3D
var world: Node

var _root: Control
var _health: ProgressBar
var _health_label: Label
var _stamina: ProgressBar
var _stamina_alpha: float = 0.0
var _name_label: Label
var _zone_label: Label
var _biome_label: Label
var _momentum_box: HBoxContainer
var _storm_icon: Label
var _slots_box: HBoxContainer
var _pouch_label: Label
var _prompt: Label
var _crosshair: Label
var _notify_box: VBoxContainer
var _vignette: ColorRect
var _flash: ColorRect
var _flash_alpha: float = 0.0
var _compass: CompassStrip
var _selected_slot: int = 0
var _heartbeat_timer: float = 0.0
var _forecast_label: Label
var _aim_label: Label
var _charge: ProgressBar


func _ready() -> void:
	layer = 5
	add_to_group("hud")
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UITheme.get_theme()
	add_child(_root)
	_build()
	Events.courier_spawned.connect(_on_courier_spawned)
	Events.health_changed.connect(_on_health)
	Events.stamina_changed.connect(_on_stamina)
	Events.inventory_changed.connect(_refresh_slots)
	Events.selected_slot_changed.connect(func(i): _selected_slot = i; _refresh_slots())
	Events.momentum_changed.connect(func(_v): _refresh_momentum())
	Events.zone_entered.connect(func(_z): _refresh_zone())
	Events.notify.connect(notify)
	Events.courier_damaged.connect(func(a, _c): _flash_alpha = clampf(a / 50.0, 0.2, 0.6))
	Events.storm_started.connect(func(k): _storm_icon.visible = true; _storm_icon.text = "! DUST STORM" if k == "dust" else "! STORM")
	Events.storm_ended.connect(func(): _storm_icon.visible = false)
	Events.lightning_warning.connect(func(_p): _storm_icon.modulate = Color(2, 2, 2))
	_refresh_zone()
	_refresh_momentum()


func _build() -> void:
	# --- vignette & damage flash
	_vignette = ColorRect.new()
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.color = Color(0.5, 0, 0, 0)
	_root.add_child(_vignette)
	_flash = ColorRect.new()
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.color = Color(0.8, 0.1, 0.05, 0)
	_root.add_child(_flash)

	# --- compass (top centre)
	_compass = CompassStrip.new()
	_compass.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_compass.position = Vector2(-320, 10)
	_compass.size = Vector2(640, 36)
	_root.add_child(_compass)

	# --- zone info (top left)
	var tl := VBoxContainer.new()
	tl.position = Vector2(20, 14)
	_root.add_child(tl)
	_zone_label = UITheme.label("ZONE 1", 26, UITheme.ACCENT)
	tl.add_child(_zone_label)
	_biome_label = UITheme.label("Greywood Forest", 18, UITheme.DIM)
	tl.add_child(_biome_label)
	_momentum_box = HBoxContainer.new()
	_momentum_box.add_theme_constant_override("separation", 6)
	tl.add_child(_momentum_box)
	_storm_icon = UITheme.label("! STORM", 20, Color(0.6, 0.75, 1.0))
	_storm_icon.visible = false
	tl.add_child(_storm_icon)
	_forecast_label = UITheme.label("", 15, UITheme.DIM)
	tl.add_child(_forecast_label)

	# --- health / stamina (bottom left)
	var bl := VBoxContainer.new()
	bl.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	bl.position = Vector2(20, -130)
	bl.add_theme_constant_override("separation", 4)
	_root.add_child(bl)
	_name_label = UITheme.label("", 18, UITheme.INK)
	bl.add_child(_name_label)
	var hrow := HBoxContainer.new()
	bl.add_child(hrow)
	_health = UITheme.bar(Color(0.75, 0.18, 0.15), 300, 18)
	hrow.add_child(_health)
	_health_label = UITheme.label("100", 16)
	hrow.add_child(_health_label)
	_stamina = UITheme.bar(Color(0.85, 0.75, 0.3), 300, 10)
	bl.add_child(_stamina)

	# --- carry slots (bottom centre)
	var bc := VBoxContainer.new()
	bc.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bc.position = Vector2(-260, -96)
	bc.custom_minimum_size = Vector2(520, 0)
	bc.alignment = BoxContainer.ALIGNMENT_CENTER
	_root.add_child(bc)
	_slots_box = HBoxContainer.new()
	_slots_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_slots_box.add_theme_constant_override("separation", 4)
	bc.add_child(_slots_box)
	_pouch_label = UITheme.label("", 15, UITheme.DIM)
	_pouch_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bc.add_child(_pouch_label)

	# --- prompt & crosshair (centre)
	_crosshair = UITheme.label("+", 28, Color(1, 1, 1, 0.85))
	_crosshair.set_anchors_preset(Control.PRESET_CENTER)
	_crosshair.position = Vector2(-8, -20)
	_crosshair.visible = false
	_root.add_child(_crosshair)
	_aim_label = UITheme.label("", 16, Color(1, 1, 1, 0.85))
	_aim_label.set_anchors_preset(Control.PRESET_CENTER)
	_aim_label.position = Vector2(20, 10)
	_root.add_child(_aim_label)
	_charge = UITheme.bar(UITheme.ACCENT, 80, 6)
	_charge.set_anchors_preset(Control.PRESET_CENTER)
	_charge.position = Vector2(-40, 30)
	_charge.visible = false
	_root.add_child(_charge)
	_prompt = UITheme.label("", 22, UITheme.INK)
	_prompt.set_anchors_preset(Control.PRESET_CENTER)
	_prompt.position = Vector2(-300, 80)
	_prompt.custom_minimum_size = Vector2(600, 0)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_prompt)

	# --- notifications (right)
	_notify_box = VBoxContainer.new()
	_notify_box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_notify_box.position = Vector2(-420, 70)
	_notify_box.custom_minimum_size = Vector2(400, 0)
	_root.add_child(_notify_box)


func _on_courier_spawned(c: Node) -> void:
	courier = c as Node3D
	_compass.courier = courier
	var d: CourierData = c.get("data")
	if d:
		var traits := d.trait_names()
		_name_label.text = "Courier #%d  %s%s" % [d.index, d.full_name, ("  ·  " + traits) if traits != "" else ""]
		_on_health(d.hp, d.max_hp)
	_refresh_slots()
	_refresh_momentum()
	_refresh_zone()


func _on_health(v: float, m: float) -> void:
	_health.max_value = m
	_health.value = v
	_health_label.text = " %d/%d" % [roundi(v), roundi(m)]


func _on_stamina(v: float, m: float) -> void:
	_stamina.max_value = m
	_stamina.value = v
	_stamina_alpha = 1.0


func _refresh_zone() -> void:
	var z := Game.current_zone
	_zone_label.text = "ZONE %d" % (z + 1)
	var b := BiomeDB.for_zone(z)
	var loop := Game.loop_index(z)
	_biome_label.text = (b.display_name if b else "") + ("   ·   Long Road +%d" % loop if loop > 0 else "")
	if b:
		_biome_label.add_theme_color_override("font_color", b.accent_color)


func _refresh_momentum() -> void:
	for c in _momentum_box.get_children():
		c.queue_free()
	var l := UITheme.label("MOMENTUM", 13, UITheme.DIM)
	_momentum_box.add_child(l)
	for i in Game.config.momentum_max:
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(16, 10)
		pip.color = UITheme.ACCENT if i < Game.momentum else Color(1, 1, 1, 0.15)
		_momentum_box.add_child(pip)
	if Game.momentum >= Game.config.momentum_fast_level:
		_momentum_box.add_child(UITheme.label("FAST COURIER", 13, UITheme.ACCENT))


func _refresh_slots() -> void:
	for c in _slots_box.get_children():
		c.queue_free()
	var d: CourierData = Game.courier
	if d == null:
		return
	var inv := d.inventory
	var slot_idx := inv.slot_indices()
	var used := 0
	for n in slot_idx.size():
		var e: Dictionary = inv.entries[slot_idx[n]]
		var def := ItemDB.get_def(e.id)
		var w := def.weight if def else 1
		used += w
		var p := PanelContainer.new()
		p.custom_minimum_size = Vector2(84 * w + 4 * (w - 1), 54)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.1, 0.09, 0.08, 0.85)
		sb.border_color = UITheme.ACCENT if n == _selected_slot else (def.color if def else Color.GRAY)
		sb.set_border_width_all(3 if n == _selected_slot else 1)
		sb.set_corner_radius_all(3)
		sb.set_content_margin_all(4)
		p.add_theme_stylebox_override("panel", sb)
		var l := UITheme.label("%s%s" % [def.display_name if def else e.id, (" x%d" % e.count) if int(e.count) > 1 else ""], 13)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		p.add_child(l)
		_slots_box.add_child(p)
	for i in maxi(inv.capacity - used, 0):
		var p := PanelContainer.new()
		p.custom_minimum_size = Vector2(84, 54)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.1, 0.09, 0.08, 0.4)
		sb.border_color = Color(1, 1, 1, 0.12)
		sb.set_border_width_all(1)
		p.add_theme_stylebox_override("panel", sb)
		_slots_box.add_child(p)
	var pouch: PackedStringArray = []
	for m in ItemDB.MATERIALS:
		var c := inv.count_of(m)
		if c > 0:
			pouch.append("%s %d" % [ItemDB.display_name(m), c])
	var load_text := "Load %d/%d" % [inv.used_slots(), inv.capacity]
	if inv.used_slots() > Game.config.free_load_slots:
		load_text += "  (-%d%% speed)" % roundi((1.0 - inv.speed_multiplier(Game.config.load_penalty_per_slot, Game.config.free_load_slots)) * 100.0)
	_pouch_label.text = load_text + ("   ·   Pouch: " + ", ".join(pouch) if not pouch.is_empty() else "")


func set_prompt(text: String) -> void:
	_prompt.text = text


func set_forecast(text: String) -> void:
	_forecast_label.text = text


func notify(text: String) -> void:
	var l := UITheme.label(text, 18, UITheme.INK)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_notify_box.add_child(l)
	var tw := create_tween()
	tw.tween_interval(4.0)
	tw.tween_property(l, "modulate:a", 0.0, 1.0)
	tw.tween_callback(l.queue_free)
	while _notify_box.get_child_count() > 6:
		_notify_box.get_child(0).free()


func _process(delta: float) -> void:
	_stamina_alpha = maxf(_stamina_alpha - delta * 0.5, 0.0)
	_stamina.modulate.a = clampf(_stamina_alpha * 2.0, 0.0, 1.0)
	_flash_alpha = maxf(_flash_alpha - delta * 1.5, 0.0)
	_flash.color.a = _flash_alpha
	_storm_icon.modulate = _storm_icon.modulate.lerp(Color.WHITE, clampf(delta * 3.0, 0.0, 1.0))
	if courier and is_instance_valid(courier):
		_crosshair.visible = bool(courier.get("aiming"))
		var combat: Node = courier.get("combat")
		if _crosshair.visible and combat:
			var t: String = combat.current_throwable()
			_aim_label.text = ("Throw: %s x%d" % [ItemDB.display_name(t), Game.courier.inventory.count_of(t)]) if t != "" else "Nothing to throw"
		else:
			_aim_label.text = ""
		var ch: float = combat.charge_ratio() if combat else 0.0
		_charge.visible = ch > 0.25
		_charge.value = ch * 100.0
		_charge.modulate = Color(1.4, 1.2, 0.6) if ch >= 1.0 else Color.WHITE
		var d: CourierData = Game.courier
		if d and d.max_hp > 0.0:
			var low := clampf(1.0 - d.hp / (d.max_hp * 0.3), 0.0, 1.0) if d.hp > 0.0 else 0.0
			_vignette.color.a = low * (0.25 + 0.1 * sin(Time.get_ticks_msec() * 0.006))
			if low > 0.0:
				_heartbeat_timer -= delta
				if _heartbeat_timer <= 0.0:
					_heartbeat_timer = lerpf(1.2, 0.7, low)
					Audio.play("heartbeat", lerpf(-14.0, -4.0, low), 0.0)
		if world and world.has_method("compass_targets"):
			_compass.targets = world.compass_targets()
