extends SceneTree
## Dev tool: screenshot a UI scene. godot --path . --script res://tools/menu_shot.gd -- scene=... out=...
func _initialize() -> void:
	await process_frame
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	var g: Node = root.get_node("/root/Game")
	g.call("new_road", 5)
	g.call("handle_death", "struck by lightning", 13, Vector3.ZERO)
	g.call("respawn")
	g.set("fragments", [0, 1] as Array[int])
	var n: Node = load(args.get("scene", "res://ui/main_menu.tscn")).instantiate()
	root.add_child(n)
	for i in 20:
		await process_frame
	if args.has("call"):
		n.call(args.call)
		for i in 10:
			await process_frame
	root.get_viewport().get_texture().get_image().save_png(args.get("out", "/tmp/menu.png"))
	quit(0)
