class_name RelayStation
extends Node3D
## Relay station: stone hut + signal fire at the end of every zone. Walking into its area lights the
## fire, makes it the active checkpoint and autosaves. Inside: rest bedroll, shared stash, upgrade bench.
## Visuals live in station_model.tscn (markers FirePoint/RestPoint/StashPoint/BenchPoint/SpawnPoint).

@export var station_index: int = 0
@export var area_size: Vector3 = Vector3(16, 5, 16)

@onready var model: Node3D = $Model

var lit: bool = false
var _fire_light: OmniLight3D
var _flames: CPUParticles3D
var _flame_mesh: MeshInstance3D
var _area: VolumeArea
var _label: Label3D


func _ready() -> void:
	add_to_group("station")
	_area = VolumeArea.new()
	_area.kind = "station"
	_area.size = area_size
	_area.position = Vector3(2, 0, 0)
	add_child(_area)
	_area.body_entered.connect(_on_body_entered)
	_build_fire()
	for spec in [["RestPoint", "rest"], ["StashPoint", "stash"], ["BenchPoint", "bench"]]:
		var marker := model.get_node_or_null(spec[0]) as Node3D
		if marker:
			var p := StationPoint.new()
			p.station = self
			p.kind = spec[1]
			p.position = marker.position
			add_child(p)
	_label = Geo.label(self, Vector3(-3.0, 2.4, -6.0), "RELAY %d" % station_index, 56)
	_set_lit(Game.activated_stations.has(station_index))


func spawn_transform() -> Transform3D:
	var m := model.get_node_or_null("SpawnPoint") as Node3D
	var p := m.global_position if m else global_position + Vector3.UP * 0.1
	return Transform3D(global_transform.basis, p)


func _build_fire() -> void:
	var fp := model.get_node_or_null("FirePoint") as Node3D
	var pos := fp.position if fp else Vector3(2, 1.5, -4)
	_fire_light = OmniLight3D.new()
	_fire_light.light_color = Color(1.0, 0.6, 0.25)
	_fire_light.omni_range = 14.0
	_fire_light.light_energy = 2.5
	_fire_light.position = pos + Vector3.UP * 0.6
	add_child(_fire_light)
	_flame_mesh = Geo.deco_cone(self, pos + Vector3.UP * 0.45, 0.45, 0.9, Color(1.0, 0.55, 0.15))
	_flame_mesh.material_override = Geo.mat(Color(1.0, 0.55, 0.15), 1.0, 3.0)
	_flames = CPUParticles3D.new()
	_flames.amount = 24
	_flames.lifetime = 0.9
	_flames.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_flames.emission_sphere_radius = 0.35
	_flames.direction = Vector3.UP
	_flames.spread = 15.0
	_flames.initial_velocity_min = 1.0
	_flames.initial_velocity_max = 2.2
	_flames.gravity = Vector3(0, 1.0, 0)
	_flames.scale_amount_min = 0.15
	_flames.scale_amount_max = 0.3
	var qm := BoxMesh.new()
	qm.size = Vector3(0.4, 0.4, 0.4)
	_flames.mesh = qm
	_flames.material_override = Geo.mat(Color(1.0, 0.7, 0.2), 1.0, 4.0)
	_flames.position = pos + Vector3.UP * 0.5
	add_child(_flames)


func _set_lit(on: bool) -> void:
	lit = on
	_fire_light.visible = on
	_flames.emitting = on
	_flame_mesh.visible = on
	_label.modulate = UITheme.ACCENT if on else Color(0.7, 0.7, 0.7)


func _process(_delta: float) -> void:
	if lit:
		_fire_light.light_energy = 2.3 + sin(Time.get_ticks_msec() * 0.013) * 0.3 + sin(Time.get_ticks_msec() * 0.031) * 0.2


func _on_body_entered(body: Node3D) -> void:
	if body is Courier and not (body as Courier).is_dead():
		activate()
		var hud := get_tree().get_first_node_in_group("hud")
		if hud and Game.has_upgrade("mirror", station_index):
			var w := get_tree().get_first_node_in_group("weather")
			if w and w.has_method("forecast"):
				hud.set_forecast("Signal Mirror: Zone %d — %s" % [station_index + 1, w.forecast(station_index)])
		elif hud:
			hud.set_forecast("")


func activate() -> void:
	var was_lit := lit
	_set_lit(true)
	if Game.activate_station(station_index):
		if not was_lit:
			Audio.play_at("fire", global_position, -2.0)
			Events.notify.emit("Relay %d lit — checkpoint saved" % station_index)
		Save.save_game()


func open_menu(kind: String) -> void:
	Events.open_station_menu.emit(self)
	var menu := get_tree().get_first_node_in_group("station_menu")
	if menu and menu.has_method("show_tab"):
		menu.show_tab(kind)


class StationPoint extends Interactable:
	var station: RelayStation
	var kind: String = "rest"

	func get_prompt(_courier: Node) -> String:
		match kind:
			"rest": return "Rest at the fire"
			"stash": return "Open the relay stash"
			"bench": return "Use the upgrade bench"
		return ""

	func interact(_courier: Node) -> void:
		station.open_menu(kind)
