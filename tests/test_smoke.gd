extends TestBase
## Smoke tests: load full scenes headless, simulate frames, and require zero engine/script errors.

var _errors: Array


func _logger() -> Object:
	return runner.get("error_logger")


func _run_scene(path: String, frame_count: int, drive_input: bool) -> Array:
	var log: Object = _logger()
	log.errors.clear()
	var scene: Node = load(path).instantiate()
	runner.root.add_child(scene)
	runner.current_scene = scene
	if drive_input:
		Input.action_press("move_forward")
	for i in frame_count:
		if drive_input and i % 90 == 0:
			Input.action_press("sprint") if i % 180 == 0 else Input.action_release("sprint")
		if drive_input and i % 50 == 0:
			Input.action_press("jump")
		elif drive_input and i % 50 == 3:
			Input.action_release("jump")
		await runner.process_frame
	release_all_inputs()
	runner.paused = false
	scene.queue_free()
	runner.current_scene = null
	await frames(3)
	return log.errors.duplicate()


func test_smoke_test_course() -> void:
	var errs := await _run_scene("res://world/test_course.tscn", 600, true)
	check(errs.is_empty(), "test course produced errors: %s" % str(errs.slice(0, 3)))


func test_death_flow_spawns_corpse_and_respawns() -> void:
	Game.new_road(55)
	var log: Object = _logger()
	log.errors.clear()
	var scene: Node = load("res://world/test_course.tscn").instantiate()
	runner.root.add_child(scene)
	runner.current_scene = scene
	await frames(10)
	var old: Courier = scene.courier
	var old_index := Game.courier.index
	Game.courier.inventory.add("cloth", 2)
	old.take_damage(500.0, "tested to death")
	await frames(5)
	var corpses := runner.get_nodes_in_group("corpse")
	eq(corpses.size(), 1, "a corpse node is spawned where the courier fell")
	if corpses.size() > 0:
		check((corpses[0] as Corpse).data.inventory.has("cloth"), "corpse node holds the items")
	var flow: DeathFlow = scene.find_children("*", "DeathFlow", true, false)[0]
	await runner.create_timer(1.6, true, false, true).timeout
	flow.death_card.force_continue()
	await frames(5)
	var nc: Courier = scene.courier
	check(nc != old and is_instance_valid(nc) and not nc.is_dead(), "a new courier is spawned")
	eq(Game.courier.index, old_index + 1, "the new courier is the next in the lineage")
	check(nc.global_position.distance_to(scene.station.spawn_transform().origin) < 1.5, "respawned at the station")
	check(Engine.time_scale == 1.0, "slow motion ended")
	check(log.errors.is_empty(), "no errors: %s" % str(log.errors.slice(0, 3)))
	scene.queue_free()
	runner.current_scene = null
	await frames(3)


func test_smoke_game_world() -> void:
	Game.new_road(4242)
	var errs := await _run_scene("res://world/game_world.tscn", 600, true)
	check(errs.is_empty(), "game world produced errors: %s" % str(errs.slice(0, 5)))


func test_station_menu_rest_and_stash() -> void:
	Game.new_road(77)
	var scene: Node = load("res://world/test_course.tscn").instantiate()
	runner.root.add_child(scene)
	runner.current_scene = scene
	await frames(5)
	Game.courier.hp = 10.0
	var menu: Node = runner.get_first_node_in_group("station_menu")
	check(menu != null, "station menu exists")
	scene.station.open_menu("rest")
	await frames(2)
	check(menu.visible_modal, "menu opens")
	menu.rest()
	eq(Game.courier.hp, Game.courier.max_hp, "rest heals fully")
	menu.close_modal()
	Game.global_upgrades.append("kennel")
	Game.courier.inventory.add("feathers", 2, true)
	Game.courier.inventory.remove_id("sling_stones", 3)
	menu.buy_noise_maker()
	check(Game.courier.inventory.has("noise_maker") and Game.courier.kennel_used, "kennel noise-maker bought")
	menu.buy_noise_maker()
	eq(Game.courier.inventory.count_of("noise_maker"), 1, "only one per life")
	menu.close_modal()
	scene.queue_free()
	runner.current_scene = null
	await frames(3)
