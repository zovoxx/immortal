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
