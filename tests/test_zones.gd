extends TestBase
## Phase 3: zone generation determinism, connectivity, guarantees.


func test_same_seed_same_layout() -> void:
	ZoneGenerator.clear_cache()
	for z in [0, 3, 17, 42]:
		var a := ZoneGenerator.generate(1234, z).signature()
		ZoneGenerator.clear_cache()
		ModuleLibrary.clear_cache()
		var b := ZoneGenerator.generate(1234, z).signature()
		eq(a, b, "zone %d regenerates identically" % z)
	check(ZoneGenerator.generate(1234, 5).signature() != ZoneGenerator.generate(999, 5).signature(), "a different seed gives a different layout")


func test_twenty_zones_connected_no_overlap() -> void:
	ZoneGenerator.clear_cache()
	var world_seed := 777
	var all_cells: Dictionary = {}
	var prev_exit_world := Vector3.INF
	for z in 20:
		var l := ZoneGenerator.layout(world_seed, z)
		var origin := l.origin_world()
		check(l.modules.size() >= 6, "zone %d has enough modules (%d)" % [z, l.modules.size()])
		check(l.length_m >= 180.0 and l.length_m <= 340.0, "zone %d length ~200-300 m (%.0f)" % [z, l.length_m])
		for mi in l.modules.size():
			var m: Dictionary = l.modules[mi]
			var entry_world: Vector3 = origin + (m.entry_pos as Vector3)
			if prev_exit_world != Vector3.INF:
				check(entry_world.distance_to(prev_exit_world) < 0.01, "zone %d module %d entry socket meets previous exit (%s vs %s)" % [z, mi, entry_world, prev_exit_world])
			prev_exit_world = origin + (m.exit_pos as Vector3)
			# the module's Entry marker in world space must match the computed entry
			var entry_x: Transform3D = (m.xform as Transform3D) * (m.info.entry as Transform3D)
			check(entry_x.origin.distance_to(m.entry_pos) < 0.01, "entry marker matches socket")
			for c in m.cells:
				var g: Vector2i = c + l.start_cell
				check(not all_cells.has(g), "cell %s used twice (zone %d)" % [g, z])
				all_cells[g] = z
				# every cell of a module lies on the grid inside its footprint
				var center := ZoneGenerator.cell_center(c)
				var local: Vector3 = (m.xform as Transform3D).affine_inverse() * center
				check(absf(local.x) < 10.01 and local.z > 0.0 and local.z < 20.0 * m.length + 0.01, "cell %s inside module %s footprint" % [c, m.id])
		check(l.end_heading == Vector2i(0, 1), "zone %d ends heading +Z" % z)
	check(all_cells.size() > 200, "20 zones produced %d cells" % all_cells.size())


func test_zone_guarantees() -> void:
	ZoneGenerator.clear_cache()
	for z in 40:
		var l := ZoneGenerator.layout(31337, z)
		check(not l.end_station().is_empty(), "zone %d has an end station" % z)
		check(l.shelters.size() >= 1, "zone %d has a shelter" % z)
		check(l.loot.size() >= 1, "zone %d has a loot cache" % z)
		check(l.enemies.size() >= 1, "zone %d has an enemy spawn" % z)
		var has_climb := false
		for m in l.modules:
			has_climb = has_climb or m.tags.has("climb")
		check(has_climb, "zone %d has an alternate (climb) route" % z)
		if z == 0:
			var has0 := false
			for s in l.stations:
				has0 = has0 or int(s.index) == 0
			check(has0, "zone 0 starts with station 0")


func test_zone_instance_builds_and_bakes() -> void:
	ZoneGenerator.clear_cache()
	Game.new_road(2024)
	var l := ZoneGenerator.layout(2024, 1)
	var inst := ZoneInstance.create(l)
	await add(inst)
	check(inst.end_station() != null, "built zone has its RelayStation node")
	eq(inst.end_station().station_index, 2, "end station of zone 1 is station 2")
	check(inst.nav.get_child_count() > l.modules.size(), "modules + edges under the nav region")
	inst.bake_navigation()
	var t := 0
	while not inst.nav_ready and t < 600:
		await frames(1)
		t += 1
	check(inst.nav_ready, "navmesh baked within 10 s")
	check(inst.nav.navigation_mesh.get_polygon_count() > 50, "navmesh has polygons (%d)" % inst.nav.navigation_mesh.get_polygon_count())
	inst.queue_free()
	await frames(2)


func test_streaming_and_rebase() -> void:
	ZoneGenerator.clear_cache()
	Game.new_road(5150)
	Save.save_path = "user://test_save.json"
	var world: GameWorld = load("res://world/game_world.tscn").instantiate()
	runner.root.add_child(world)
	runner.current_scene = world
	await frames(5)
	eq(world.streamer.loaded.keys().size(), 2, "zones 0 and 1 loaded at start")
	for target in [1, 2, 3]:
		# teleport to the end station of zone target-1, which activates station `target`
		var st := world.station_node(target)
		check(st != null, "station %d is loaded before reaching it" % target)
		if st == null:
			break
		world.courier.global_position = st.spawn_transform().origin + Vector3(0, 0.2, 0)
		await frames(20)
		eq(Game.last_station, target, "walking into station %d activates it" % target)
		# step into the next zone
		var l := world.streamer.layout(target)
		var p: Vector3 = world.streamer.to_world(target, ZoneGenerator.cell_center(l.modules[1].cells[0]))
		world.courier.global_position = p + Vector3(0, 0.5, 0)
		await frames(30)
		eq(Game.current_zone, target, "entering zone %d updates current zone" % target)
		var keys: Array = world.streamer.loaded.keys()
		keys.sort()
		eq(keys, [target - 1, target, target + 1], "prev/current/next loaded around zone %d" % target)
	check(world.courier.global_position.length() < 200.0, "floating origin keeps the courier near the origin (%.0f m)" % world.courier.global_position.length())
	check(Save.has_save(), "station activation autosaved")
	world.queue_free()
	runner.current_scene = null
	await frames(3)
