extends ModalLayer
## Relay station menu: Rest (heal fully, time passes, a storm may move in), the shared Stash,
## the Upgrade bench (Bed, Forge, Kennel, Signal Mirror) and the kennel noise-maker.

const UPGRADES := [
	["bed", "Bed", "New couriers spawn at THIS station with +20 HP."],
	["forge", "Forge", "New couriers spawn with a Fine Blade instead of a Short Blade (everywhere)."],
	["kennel", "Kennel", "Each courier may buy one noise-maker per life at any station."],
	["mirror", "Signal Mirror", "THIS station shows the next zone's storm forecast."],
]

var station: Node
var _title: Label
var _tabs: HBoxContainer
var _body: VBoxContainer
var _tab: String = "rest"


func _ready() -> void:
	super._ready()
	add_to_group("station_menu")
	_make(Vector2(860, 520))
	_title = UITheme.title("RELAY", 34)
	_vb.add_child(_title)
	_tabs = HBoxContainer.new()
	_tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	_vb.add_child(_tabs)
	for t in [["rest", "Rest"], ["stash", "Stash"], ["bench", "Upgrade bench"]]:
		var id: String = t[0]
		_tabs.add_child(UITheme.button(t[1], func(): show_tab(id), 200))
	_vb.add_child(HSeparator.new())
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 8)
	_body.custom_minimum_size = Vector2(820, 340)
	_vb.add_child(_body)
	_vb.add_child(UITheme.button("Leave", close_modal))
	Events.open_station_menu.connect(_on_open)


func _on_open(st: Node) -> void:
	station = st
	_title.text = "RELAY %d" % int(st.get("station_index"))
	open_modal()
	show_tab(_tab)


func station_index() -> int:
	return int(station.get("station_index")) if station else Game.last_station


func show_tab(kind: String) -> void:
	_tab = kind
	if kind == "stash":
		close_modal()
		var c := ItemContainer.new("Relay stash (shared by all couriers)", Game.stash, true)
		c.on_changed = func(): Events.stash_changed.emit()
		Events.open_container.emit(c, c.title)
		return
	if not visible_modal:
		open_modal()
	_clear(_body)
	match kind:
		"rest": _build_rest()
		"bench": _build_bench()
	var b := _root.find_children("*", "Button", true, false)
	if b.size() > 3:
		(b[3] as Button).grab_focus()


func _build_rest() -> void:
	var d := Game.courier
	_body.add_child(UITheme.label("%s  ·  %d / %d HP" % [d.full_name, roundi(d.hp), roundi(d.max_hp)], 22))
	_body.add_child(UITheme.label("Resting heals you fully, but time passes and the storm may move.", 17, UITheme.DIM, true))
	_body.add_child(UITheme.button("Rest by the fire", rest))
	if Game.has_upgrade("kennel"):
		var cost: Dictionary = Game.config.kennel_price
		var b := UITheme.button("Kennel: buy a noise-maker (%s)" % _cost_text(cost), buy_noise_maker)
		b.disabled = d.kennel_used or not Game.can_afford(cost)
		if d.kennel_used:
			b.text = "Kennel: already bought one this life"
		_body.add_child(b)
	if Game.has_upgrade("mirror", station_index()):
		_body.add_child(UITheme.label("Signal Mirror — Zone %d: %s" % [Game.current_zone + 2, forecast_text()], 20, UITheme.ACCENT))
	_body.add_child(HSeparator.new())
	_body.add_child(UITheme.label("Momentum %d / %d" % [Game.momentum, Game.config.momentum_max], 18, UITheme.ACCENT))
	_body.add_child(UITheme.label("2: +5% speed   ·   3: better loot   ·   5: Fast Courier (shortcuts revealed, par-time bonus)", 16, UITheme.DIM, true))


func forecast_text() -> String:
	var w := get_tree().get_first_node_in_group("weather")
	if w and w.has_method("forecast"):
		return w.forecast(Game.current_zone + 1)
	return "unknown"


func _cost_text(cost: Dictionary) -> String:
	var parts: PackedStringArray = []
	for k in cost:
		parts.append("%d %s (have %d)" % [int(cost[k]), ItemDB.display_name(String(k)), Game.material_count(String(k))])
	return ", ".join(parts)


func _build_bench() -> void:
	_body.add_child(UITheme.label("Materials (pouch + stash): " + ", ".join(ItemDB.MATERIALS.map(func(m): return "%s %d" % [ItemDB.display_name(m), Game.material_count(m)])), 17, UITheme.DIM, true))
	for u in UPGRADES:
		var id: String = u[0]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var info := VBoxContainer.new()
		info.custom_minimum_size = Vector2(520, 0)
		var scope := "global" if Game.is_global_upgrade(id) else "this station"
		info.add_child(UITheme.label("%s  (%s)" % [u[1], scope], 20, UITheme.ACCENT))
		info.add_child(UITheme.label(u[2], 15, UITheme.DIM, true))
		row.add_child(info)
		var cost: Dictionary = Game.config.upgrade_costs.get(id, {})
		var built := Game.has_upgrade(id, station_index())
		var b := UITheme.button("Built" if built else "Build: " + _short_cost(cost), func(): build(id), 260)
		b.disabled = built or not Game.can_afford(cost)
		row.add_child(b)
		_body.add_child(row)


func _short_cost(cost: Dictionary) -> String:
	var parts: PackedStringArray = []
	for k in cost:
		parts.append("%d %s" % [int(cost[k]), ItemDB.display_name(String(k))])
	return ", ".join(parts)


func rest() -> void:
	var c := get_tree().get_first_node_in_group("player") as Courier
	if c:
		c.heal(Game.courier.max_hp)
	else:
		Game.courier.hp = Game.courier.max_hp
	Game.time_of_day = fposmod(Game.time_of_day + Game.config.rest_time_cost, 1.0)
	var w := get_tree().get_first_node_in_group("weather")
	if w and w.has_method("on_rest"):
		w.on_rest()
	Audio.play("fire", -6.0)
	Events.notify.emit("You rest by the fire. Hours pass.")
	Save.save_game()
	show_tab("rest")


func buy_noise_maker() -> void:
	var d := Game.courier
	if d.kennel_used or not Game.has_upgrade("kennel"):
		return
	if d.inventory.can_add("noise_maker", 1) <= 0:
		Events.notify.emit("No free carry slot")
		return
	if Game.spend(Game.config.kennel_price):
		d.inventory.add("noise_maker", 1)
		d.kennel_used = true
		Events.inventory_changed.emit()
		Events.notify.emit("The kennel master hands you a noise-maker.")
	show_tab("rest")


func build(id: String) -> void:
	if Game.build_upgrade(id, station_index()):
		Audio.play("toll_slam", -8.0)
		Events.notify.emit("Built: %s" % id.capitalize())
		Save.save_game()
	show_tab("bench")
