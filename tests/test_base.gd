class_name TestBase
extends RefCounted
## Base for test suites. Methods named test_* are run by tests/run_tests.gd.

var runner: SceneTree
var _fail_msg: String = ""


func check(cond: bool, msg: String) -> bool:
	if not cond and _fail_msg == "":
		_fail_msg = msg
	return cond


func eq(a: Variant, b: Variant, msg: String) -> bool:
	return check(a == b, "%s (got %s, expected %s)" % [msg, str(a), str(b)])


func frames(n: int) -> void:
	for i in n:
		await runner.physics_frame


func root() -> Window:
	return runner.root


## Adds a node to the root and waits a frame.
func add(n: Node) -> Node:
	runner.root.add_child(n)
	await runner.process_frame
	return n


func release_all_inputs() -> void:
	for a in InputMap.get_actions():
		if Input.is_action_pressed(a):
			Input.action_release(a)
