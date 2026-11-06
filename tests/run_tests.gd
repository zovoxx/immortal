extends SceneTree
## RELAY automated tests.
## Run: godot --headless --path . --script res://tests/run_tests.gd
## Prints PASS/FAIL per test; exits with code 1 on any failure.
## Optional filter: -- --only=<substring>

const SUITES: Array[String] = [
	"res://tests/test_data.gd",
	"res://tests/test_movement.gd",
	"res://tests/test_zones.gd",
	"res://tests/test_ai.gd",
	"res://tests/test_smoke.gd",
]

var passed := 0
var failed := 0
var failures: Array[String] = []
var error_logger: TestLogger


func _initialize() -> void:
	await process_frame
	error_logger = TestLogger.new()
	OS.add_logger(error_logger)
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.substr(7)
	# isolate save files from the player's real saves
	root.get_node("/root/Save").set("save_path", "user://test_save.json")
	print("=== RELAY tests ===")
	for path in SUITES:
		if not ResourceLoader.exists(path):
			continue
		var script: Script = load(path)
		if script == null or not script.can_instantiate():
			failed += 1
			failures.append("%s: failed to load" % path)
			print("FAIL  ", path, " — script failed to load")
			continue
		var suite: Object = script.new()
		suite.set("runner", self)
		for m in suite.get_method_list():
			var mname: String = m.name
			if not mname.begins_with("test_"):
				continue
			if only != "" and not mname.contains(only) and not path.contains(only):
				continue
			await _run_one(suite, mname)
		if suite is Node:
			(suite as Node).queue_free()
	root.get_node("/root/Save").call("delete_save")
	print("=== %d passed, %d failed ===" % [passed, failed])
	for f in failures:
		print("  FAILED: ", f)
	OS.remove_logger(error_logger)
	quit(1 if failed > 0 else 0)


func _run_one(suite: Object, mname: String) -> void:
	suite.set("_fail_msg", "")
	error_logger.errors.clear()
	var result: Variant = await suite.call(mname)
	var msg: String = suite.get("_fail_msg")
	if msg == "" and result is String and result != "":
		msg = result
	if msg == "":
		passed += 1
		print("PASS  ", mname)
	else:
		failed += 1
		failures.append("%s: %s" % [mname, msg])
		print("FAIL  ", mname, " — ", msg)


class TestLogger extends Logger:
	var errors: Array[String] = []
	var _mutex := Mutex.new()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		_mutex.lock()
		errors.append("%s (%s:%d %s) %s" % [rationale if rationale != "" else code, file, line, function, code])
		_mutex.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass
