extends RefCounted
## Worker for tools/traverse_check.gd. A bot courier walks every module of every biome from Entry to Exit (navmesh path when
## available, straight line + jumps otherwise) and reports modules it couldn't cross.
## Run: godot --headless --path . --script res://tools/traverse_check.gd [-- --only=<biome id>]

const COURIER := preload("res://player/courier.tscn")
const TIME_LIMIT := 30.0

var results: Array = []


var tree: SceneTree
var root: Window


func run(t: SceneTree) -> int:
	tree = t
	root = t.root
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.substr(7)
	var game: Node = root.get_node("/root/Game")
	for i in 5:
		var b: Biome = BiomeDB.get_biome(i)
		if only != "" and b.id != only:
			continue
		for p in b.modules + [b.station_module]:
			if OS.get_environment("TRMOD") != "" and not p.contains(OS.get_environment("TRMOD")):
				continue
			game.call("new_road", 1)
			game.set("god_mode", true)
			var ok: Array = await _run_module(p)
			results.append([p.get_file(), ok[0], ok[1]])
			print(("OK    " if ok[0] else "STUCK ") + p.get_file() + "  " + ok[1])
	var fails := results.filter(func(r): return not r[1])
	print("traverse_check: %d/%d modules crossed" % [results.size() - fails.size(), results.size()])
	return 1 if not fails.is_empty() else 0


func _run_module(path: String) -> Array:
	var arena := Node3D.new()
	root.add_child(arena)
	var nav := NavigationRegion3D.new()
	var nm := NavigationMesh.new()
	nm.agent_radius = 0.45
	nm.agent_height = 1.6
	nm.agent_max_climb = 0.4
	nm.cell_size = 0.3
	nm.cell_height = 0.25
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = 1
	nav.navigation_mesh = nm
	arena.add_child(nav)
	var inst: Node3D = (load(path) as PackedScene).instantiate()
	nav.add_child(inst)
	var info := ModuleLibrary.info(path)
	var exit_p: Vector3 = (info.exit as Transform3D).origin
	await tree.physics_frame
	nav.bake_navigation_mesh(false)
	for i in 3:
		await tree.physics_frame
	var c: Courier = COURIER.instantiate()
	c.data = root.get_node("/root/Game").get("courier")
	arena.add_child(c)
	c.global_position = Vector3(0, 0.3, 0.6)
	c.camera_rig.face_direction(Vector3.BACK)
	await tree.physics_frame
	var map := arena.get_world_3d().navigation_map
	var target := exit_p - (info.exit as Transform3D).basis.z * -0.0
	var pts := NavigationServer3D.map_get_path(map, c.global_position, exit_p, true)
	var waypoints: Array = []
	var route := inst.get_node_or_null("Route")
	if route:
		for mk in route.get_children():
			waypoints.append((mk as Node3D).global_position)
	elif pts.size() >= 2 and pts[pts.size() - 1].distance_to(exit_p) < 2.0:
		for p in pts:
			waypoints.append(p)
		waypoints.remove_at(0)
	else:
		for k in range(1, 5):
			waypoints.append(Vector3(0, 0, 0.6).lerp(exit_p, k / 4.0))
	waypoints.append(exit_p + (exit_p - Vector3(0, 0, exit_p.z * 0.5 if info.exit_dir == 0 else 10.0)).normalized() * 0.0)
	var t := 0.0
	var stuck := 0.0
	var wi := 0
	var ok := false
	var last_pos := c.global_position
	Input.action_press("move_forward")
	while t < TIME_LIMIT:
		await tree.physics_frame
		var dt := 1.0 / 60.0
		t += dt
		if c.global_position.y < -5.0 or c.is_dead():
			break
		var flat_exit := Vector2(c.global_position.x - exit_p.x, c.global_position.z - exit_p.z).length()
		if flat_exit < 1.6 and c.global_position.y > exit_p.y - 1.0:
			ok = true
			break
		var wp: Vector3 = waypoints[mini(wi, waypoints.size() - 1)]
		var to := wp - c.global_position
		to.y = 0
		if to.length() < 1.0 and wi < waypoints.size() - 1:
			wi += 1
			continue
		c.camera_rig.face_direction(to.normalized())
		var moved := c.global_position.distance_to(last_pos)
		last_pos = c.global_position
		stuck = stuck + dt if moved < 0.02 else maxf(stuck - dt, 0.0)
		var edge := c.is_on_floor() and _edge_ahead(c, to.normalized())
		if OS.get_environment("TRDBG") != "" and int(t * 60) % 6 == 0:
			print("  t=%.1f pos=%s st=%s edge=%s stuck=%.2f floor=%s wi=%d" % [t, str(c.global_position.snapped(Vector3.ONE * 0.1)), c.state, edge, stuck, c.is_on_floor(), wi])
		var want_jump := ((stuck > 0.35 or edge) and c.is_on_floor()) or c.state == Courier.State.HANG
		if want_jump and not Input.is_action_pressed("jump"):
			Input.action_press("jump")
		else:
			Input.action_release("jump")
	for a in ["move_forward", "jump", "sprint"]:
		Input.action_release(a)
	var where := "end %s exit %s" % [str(c.global_position.snapped(Vector3.ONE * 0.1)), str(exit_p)]
	arena.queue_free()
	await tree.physics_frame
	return [ok, "" if ok else where]


func _edge_ahead(c: Courier, dir: Vector3) -> bool:
	var from := c.global_position + dir * 1.2 + Vector3.UP * 0.5
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 2.5, 1, [c.get_rid()])
	return c.get_world_3d().direct_space_state.intersect_ray(q).is_empty()
