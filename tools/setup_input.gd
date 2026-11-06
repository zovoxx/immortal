extends SceneTree
## Writes InputDefaults.ACTIONS into project.godot so the editor's Input Map shows them.
## Run: godot --headless --path . --script res://tools/setup_input.gd

func _init() -> void:
	for action in InputDefaults.ACTIONS:
		var events: Array = []
		for spec in InputDefaults.ACTIONS[action]:
			events.append(InputDefaults.make_event(spec))
		ProjectSettings.set_setting("input/" + action, {"deadzone": 0.25, "events": events})
	var err := ProjectSettings.save()
	print("setup_input: saved project.godot (", error_string(err), ")")
	quit(0 if err == OK else 1)
