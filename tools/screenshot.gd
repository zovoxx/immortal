extends SceneTree
## Dev tool: loads a scene, waits, saves screenshots. Needs a display (e.g. xvfb-run).
## godot --path . --rendering-method gl_compatibility --script res://tools/screenshot.gd -- scene=res://world/game_world.tscn out=/tmp/shot.png frames=90 [yaw=deg] [pitch=deg] [zone=N]

func _initialize() -> void:
	await process_frame
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	var game: Node = root.get_node("/root/Game")
	game.call("new_road", int(args.get("seed", "4242")))
	if args.has("zone"):
		game.set("last_station", int(args.zone))
	if args.has("time"):
		game.set("time_of_day", float(args.time))
	var scene: Node = load(args.get("scene", "res://world/game_world.tscn")).instantiate()
	root.add_child(scene)
	current_scene = scene
	for i in int(args.get("frames", "60")):
		await process_frame
	var courier: Node = get_first_node_in_group("player")
	if courier:
		if args.has("tp"):
			var p: PackedStringArray = String(args.tp).split(",")
			courier.global_position = Vector3(float(p[0]), float(p[1]), float(p[2]))
		var rig: Node = courier.get("camera_rig")
		if args.has("yaw"):
			rig.get("yaw_node").rotation.y = deg_to_rad(float(args.yaw))
		if args.has("pitch"):
			rig.get("pitch_node").rotation.x = deg_to_rad(float(args.pitch))
		if args.has("arm"):
			rig.set("arm_length", float(args.arm))
	for i in 30:
		await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(args.get("out", "/tmp/shot.png"))
	print("saved ", args.get("out", "/tmp/shot.png"))
	quit(0)
