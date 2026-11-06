class_name InputDefaults
extends RefCounted
## Default bindings for every Input Map action. The same table is written into project.godot
## (tools/setup_input.gd) and used by Settings for "reset to defaults" and rebinding.
## Entry format: ["key", KEY_*] ["mouse", MOUSE_BUTTON_*] ["joy", JOY_BUTTON_*] ["axis", JOY_AXIS_*, sign]

const ACTIONS: Dictionary = {
	"move_forward": [["key", KEY_W], ["key", KEY_UP], ["axis", JOY_AXIS_LEFT_Y, -1.0]],
	"move_back": [["key", KEY_S], ["key", KEY_DOWN], ["axis", JOY_AXIS_LEFT_Y, 1.0]],
	"move_left": [["key", KEY_A], ["key", KEY_LEFT], ["axis", JOY_AXIS_LEFT_X, -1.0]],
	"move_right": [["key", KEY_D], ["key", KEY_RIGHT], ["axis", JOY_AXIS_LEFT_X, 1.0]],
	"look_up": [["axis", JOY_AXIS_RIGHT_Y, -1.0]],
	"look_down": [["axis", JOY_AXIS_RIGHT_Y, 1.0]],
	"look_left": [["axis", JOY_AXIS_RIGHT_X, -1.0]],
	"look_right": [["axis", JOY_AXIS_RIGHT_X, 1.0]],
	"jump": [["key", KEY_SPACE], ["joy", JOY_BUTTON_A]],
	"sprint": [["key", KEY_SHIFT], ["joy", JOY_BUTTON_LEFT_STICK], ["joy", JOY_BUTTON_LEFT_SHOULDER]],
	"crouch": [["key", KEY_C], ["key", KEY_CTRL], ["joy", JOY_BUTTON_B]],
	"walk": [["key", KEY_ALT]],
	"interact": [["key", KEY_E], ["joy", JOY_BUTTON_X]],
	"attack": [["mouse", MOUSE_BUTTON_LEFT], ["axis", JOY_AXIS_TRIGGER_RIGHT, 1.0]],
	"aim": [["mouse", MOUSE_BUTTON_RIGHT], ["axis", JOY_AXIS_TRIGGER_LEFT, 1.0]],
	"dodge": [["key", KEY_Q], ["joy", JOY_BUTTON_RIGHT_SHOULDER]],
	"use_item": [["key", KEY_F], ["joy", JOY_BUTTON_Y]],
	"drop_item": [["key", KEY_G], ["joy", JOY_BUTTON_DPAD_DOWN]],
	"item_next": [["mouse", MOUSE_BUTTON_WHEEL_DOWN], ["key", KEY_2], ["joy", JOY_BUTTON_DPAD_RIGHT]],
	"item_prev": [["mouse", MOUSE_BUTTON_WHEEL_UP], ["key", KEY_1], ["joy", JOY_BUTTON_DPAD_LEFT]],
	"pause": [["key", KEY_ESCAPE], ["joy", JOY_BUTTON_START]],
	"debug_overlay": [["key", KEY_F3]],
	"debug_god": [["key", KEY_F5]],
	"debug_spawn": [["key", KEY_F6]],
	"debug_storm": [["key", KEY_F7]],
	"debug_teleport": [["key", KEY_F8]],
	"debug_next_zone": [["key", KEY_F9]],
}

## Actions shown in the rebinding menu (in order) with readable labels.
const REBINDABLE: Array = [
	["move_forward", "Move forward"], ["move_back", "Move back"], ["move_left", "Move left"],
	["move_right", "Move right"], ["jump", "Jump / climb"], ["sprint", "Sprint"],
	["crouch", "Crouch / slide"], ["walk", "Walk"], ["interact", "Interact"],
	["attack", "Attack / throw"], ["aim", "Aim sling"], ["dodge", "Dodge roll"],
	["use_item", "Use item"], ["drop_item", "Drop item"], ["item_next", "Next slot"],
	["item_prev", "Previous slot"], ["pause", "Pause"],
]


static func make_event(spec: Array) -> InputEvent:
	match String(spec[0]):
		"key":
			var e := InputEventKey.new()
			e.physical_keycode = spec[1]
			return e
		"mouse":
			var m := InputEventMouseButton.new()
			m.button_index = spec[1]
			return m
		"joy":
			var j := InputEventJoypadButton.new()
			j.button_index = spec[1]
			return j
		"axis":
			var a := InputEventJoypadMotion.new()
			a.axis = spec[1]
			a.axis_value = spec[2]
			return a
	return null


static func event_to_spec(e: InputEvent) -> Array:
	if e is InputEventKey:
		var code: int = e.physical_keycode if e.physical_keycode != 0 else e.keycode
		return ["key", code]
	if e is InputEventMouseButton:
		return ["mouse", e.button_index]
	if e is InputEventJoypadButton:
		return ["joy", e.button_index]
	if e is InputEventJoypadMotion:
		return ["axis", e.axis, signf(e.axis_value)]
	return []


static func spec_label(spec: Array) -> String:
	if spec.is_empty():
		return "-"
	match String(spec[0]):
		"key":
			return OS.get_keycode_string(int(spec[1]))
		"mouse":
			match int(spec[1]):
				MOUSE_BUTTON_LEFT: return "LMB"
				MOUSE_BUTTON_RIGHT: return "RMB"
				MOUSE_BUTTON_MIDDLE: return "MMB"
				MOUSE_BUTTON_WHEEL_UP: return "Wheel Up"
				MOUSE_BUTTON_WHEEL_DOWN: return "Wheel Down"
			return "Mouse %d" % int(spec[1])
		"joy":
			var names := {0: "A", 1: "B", 2: "X", 3: "Y", 4: "Back", 6: "Start", 7: "L3", 8: "R3",
				9: "LB", 10: "RB", 11: "D-Up", 12: "D-Down", 13: "D-Left", 14: "D-Right"}
			return "Pad " + String(names.get(int(spec[1]), str(spec[1])))
		"axis":
			var axes := {0: "LS X", 1: "LS Y", 2: "RS X", 3: "RS Y", 4: "LT", 5: "RT"}
			return "Pad %s%s" % [axes.get(int(spec[1]), str(spec[1])), "+" if float(spec[2]) > 0 else "-"]
	return "?"


## Installs defaults for any action missing from the InputMap.
static func ensure_actions() -> void:
	for action in ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.25)
			for spec in ACTIONS[action]:
				InputMap.action_add_event(action, make_event(spec))


static func reset_action(action: String) -> void:
	if InputMap.has_action(action):
		InputMap.action_erase_events(action)
	else:
		InputMap.add_action(action, 0.25)
	for spec in ACTIONS.get(action, []):
		InputMap.action_add_event(action, make_event(spec))
