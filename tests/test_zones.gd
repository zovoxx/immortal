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
	for z in 60:
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



func test_biomes_cycle_and_loop() -> void:
	eq(BiomeDB.count(), 5, "five biomes")
	var ids := []
	for i in 5:
		var b := BiomeDB.get_biome(i)
		check(b != null and b.modules.size() >= 6, "biome %d has 6+ modules" % i)
		check(b.station_module != "", "biome %d has a station module" % i)
		ids.append(b.id)
		var tags := {}
		for p in b.modules:
			for t in ModuleLibrary.info(p).tags:
				tags[t] = true
		check(tags.has("shelter") and tags.has("climb"), "biome %s has shelter + climb modules" % b.id)
		var has_l := false
		var has_r := false
		for p in b.modules:
			var inf := ModuleLibrary.info(p)
			has_l = has_l or int(inf.exit_dir) == ZoneModule.Exit.LEFT
			has_r = has_r or int(inf.exit_dir) == ZoneModule.Exit.RIGHT
		check(has_l and has_r, "biome %s has left and right bends" % b.id)
	eq(ids, ["greywood", "highway", "plains", "floating", "desert"], "biome order")
	eq(BiomeDB.for_zone(0).id, "greywood", "zones 0-9: Greywood")
	eq(BiomeDB.for_zone(10).id, "highway", "zones 10-19: Highway")
	eq(BiomeDB.for_zone(49).id, "desert", "zone 49: Salt Desert")
	eq(BiomeDB.for_zone(50).id, "greywood", "zone 50 loops back to Greywood")
	eq(Game.loop_index(49), 0, "no loop before zone 50")
	eq(Game.loop_index(50), 1, "Long Road +1 from zone 50")
	var colors := {}
	for i in 5:
		colors[BiomeDB.get_biome(i).ground_color.to_html()] = true
	eq(colors.size(), 5, "each biome has a distinct palette")


func test_difficulty_increases() -> void:
	var prev_g := 0
	var prev_hp := 0.0
	var prev_storm := 0.0
	var prev_toll := 0
	var prev_loot := 99.0
	for z in [0, 5, 10, 20, 30, 49]:
		var g := Difficulty.enemy_groups(z)
		var hp := Difficulty.enemy_hp_mult(z)
		var toll := Difficulty.toll_price(z)
		check(g >= prev_g, "enemy groups never decrease (zone %d)" % z)
		check(hp >= prev_hp, "enemy HP never decreases (zone %d)" % z)
		check(toll >= prev_toll, "toll price never decreases (zone %d)" % z)
		prev_g = g
		prev_hp = hp
		prev_toll = toll
	check(Difficulty.enemy_groups(40) > Difficulty.enemy_groups(0), "more enemy groups later")
	check(Difficulty.enemy_hp_mult(40) > Difficulty.enemy_hp_mult(0), "tougher enemies later")
	check(Difficulty.toll_price(45) > Difficulty.toll_price(0), "tolls cost more later")
	# storm chance is biome-weighted, compare within the same biome
	check(Difficulty.storm_chance(9) > Difficulty.storm_chance(0), "storms more likely deeper in a biome")
	check(Difficulty.storm_chance(55) > Difficulty.storm_chance(5), "Long Road +1: more storms")
	check(Difficulty.loot_mult(55) < Difficulty.loot_mult(5), "Long Road +1: less loot")
	check(Difficulty.enemy_groups(55) > Difficulty.enemy_groups(5), "Long Road +1: more enemies")
	check(Difficulty.storm_chance(25) > Difficulty.storm_chance(15), "Storm Plains storm more than the Highway")


func test_all_biome_zones_build() -> void:
	ZoneGenerator.clear_cache()
	Game.new_road(3)
	for z in [12, 25, 33, 44, 51]:
		var l := ZoneGenerator.layout(3, z)
		var inst := ZoneInstance.create(l)
		await add(inst)
		check(inst.end_station() != null, "zone %d (%s) builds with a station" % [z, inst.biome.id])
		inst.queue_free()
		await frames(1)
