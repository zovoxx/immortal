extends Node
## User settings (camera, graphics, audio, window, key bindings) persisted to user://relay_settings.json.

signal changed()

enum Quality { LOW, MEDIUM, HIGH }

const PATH := "user://relay_settings.json"

var mouse_sensitivity: float = 0.25
var gamepad_sensitivity: float = 3.0
var invert_y: bool = false
var fov: float = 72.0
var quality: int = Quality.MEDIUM
var master_volume: float = 0.8
var music_volume: float = 0.6
var sfx_volume: float = 0.9
var fullscreen: bool = false
## action -> Array of specs (see InputDefaults). Only actions the user changed.
var bindings: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	InputDefaults.ensure_actions()
	load_settings()
	apply_window()
	call_deferred("apply_audio")


func load_settings() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not d is Dictionary:
		return
	mouse_sensitivity = float(d.get("mouse_sensitivity", mouse_sensitivity))
	gamepad_sensitivity = float(d.get("gamepad_sensitivity", gamepad_sensitivity))
	invert_y = bool(d.get("invert_y", invert_y))
	fov = float(d.get("fov", fov))
	quality = int(d.get("quality", quality))
	master_volume = float(d.get("master_volume", master_volume))
	music_volume = float(d.get("music_volume", music_volume))
	sfx_volume = float(d.get("sfx_volume", sfx_volume))
	fullscreen = bool(d.get("fullscreen", fullscreen))
	bindings = d.get("bindings", {})
	for action in bindings:
		_apply_binding(String(action), bindings[action])


func save_settings() -> void:
	var d := {
		"mouse_sensitivity": mouse_sensitivity, "gamepad_sensitivity": gamepad_sensitivity,
		"invert_y": invert_y, "fov": fov, "quality": quality,
		"master_volume": master_volume, "music_volume": music_volume, "sfx_volume": sfx_volume,
		"fullscreen": fullscreen, "bindings": bindings,
	}
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d, "\t"))
	changed.emit()


# ---------------------------------------------------------------- bindings

func _apply_binding(action: String, specs: Array) -> void:
	if not InputMap.has_action(action):
		return
	InputMap.action_erase_events(action)
	for s in specs:
		if s is Array and s.size() >= 2:
			var ev := InputDefaults.make_event(s)
			if ev:
				InputMap.action_add_event(action, ev)


## Rebinds the keyboard/mouse (pad=false) or gamepad (pad=true) binding of an action.
func rebind(action: String, event: InputEvent) -> void:
	var is_pad := event is InputEventJoypadButton or event is InputEventJoypadMotion
	var specs: Array = []
	for e in InputMap.action_get_events(action):
		var e_pad := e is InputEventJoypadButton or e is InputEventJoypadMotion
		if e_pad != is_pad:
			specs.append(InputDefaults.event_to_spec(e))
	specs.push_front(InputDefaults.event_to_spec(event))
	bindings[action] = specs
	_apply_binding(action, specs)
	save_settings()


func reset_bindings() -> void:
	bindings = {}
	for action in InputDefaults.ACTIONS:
		InputDefaults.reset_action(action)
	save_settings()


func binding_label(action: String, pad: bool) -> String:
	for e in InputMap.action_get_events(action):
		var e_pad := e is InputEventJoypadButton or e is InputEventJoypadMotion
		if e_pad == pad:
			return InputDefaults.spec_label(InputDefaults.event_to_spec(e))
	return "-"


# ---------------------------------------------------------------- apply

func apply_window() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


func apply_audio() -> void:
	_set_bus("Master", master_volume)
	_set_bus("Music", music_volume)
	_set_bus("SFX", sfx_volume)


func _set_bus(bus_name: String, v: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.0001)))
		AudioServer.set_bus_mute(idx, v <= 0.001)


## Applies the graphics preset to a world environment, sun and viewport.
func apply_graphics(env: Environment, sun: DirectionalLight3D, viewport: Viewport) -> void:
	match quality:
		Quality.LOW:
			if sun: sun.shadow_enabled = false
			if env:
				env.ssao_enabled = false
				env.volumetric_fog_enabled = false
				env.glow_enabled = false
				env.ssr_enabled = false
				env.sdfgi_enabled = false
			if viewport:
				viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
				viewport.scaling_3d_scale = 0.6
				viewport.msaa_3d = Viewport.MSAA_DISABLED
		Quality.MEDIUM:
			if sun:
				sun.shadow_enabled = true
				sun.directional_shadow_max_distance = 60.0
			if env:
				env.ssao_enabled = false
				env.volumetric_fog_enabled = false
				env.glow_enabled = true
			if viewport:
				viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
				viewport.scaling_3d_scale = 0.85
				viewport.msaa_3d = Viewport.MSAA_DISABLED
		Quality.HIGH:
			if sun:
				sun.shadow_enabled = true
				sun.directional_shadow_max_distance = 120.0
			if env:
				env.ssao_enabled = true
				env.volumetric_fog_enabled = true
				env.glow_enabled = true
			if viewport:
				viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
				viewport.scaling_3d_scale = 1.0
				viewport.msaa_3d = Viewport.MSAA_2X


func quality_name(q: int = -1) -> String:
	if q < 0:
		q = quality
	return ["Low", "Medium", "High"][clampi(q, 0, 2)]
