extends SceneTree
## Dev tool: a bot courier walks every module of every biome from Entry to Exit and reports the
## modules it couldn't cross. Run: godot --headless --path . --script res://tools/traverse_check.gd [-- --only=<biome id>]

func _initialize() -> void:
	await process_frame
	var w: Object = load("res://tools/traverse_worker.gd").new()
	var code: int = await w.run(self)
	quit(code)
