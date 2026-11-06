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
