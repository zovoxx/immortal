extends TestBase
## Phase 1: courier movement in a minimal physics scene, driven by simulated input.

const COURIER := preload("res://player/courier.tscn")


func _make_arena() -> Node3D:
	var arena := Node3D.new()
	arena.name = "MoveArena"
	Geo.box(arena, Vector3(0, -0.5, 0), Vector3(80, 1, 120), Color.GRAY)
	return arena


func _spawn(arena: Node3D, pos: Vector3) -> Courier:
	Game.new_road(42)
	Game.courier.traits.clear()  # neutral courier
	Game.courier.apply_base_stats(100.0, 4)
	Game.courier.inventory.entries.clear()
	var c: Courier = COURIER.instantiate()
	c.data = Game.courier
	arena.add_child(c)
	c.global_position = pos
	c.camera_rig.face_direction(Vector3(0, 0, 1))
	return c


func _cleanup(arena: Node) -> void:
	release_all_inputs()
	arena.queue_free()
	await frames(2)


func test_run_speed() -> void:
	var arena := _make_arena()
	await add(arena)
	var c := _spawn(arena, Vector3(0, 0.05, -40))
	await frames(10)
	var start := c.global_position
	Input.action_press("move_forward")
	await frames(60)
	var hs := Vector2(c.velocity.x, c.velocity.z).length()
	check(absf(hs - 7.0) < 0.6, "run speed should be ~7 m/s, got %.2f" % hs)
	check(c.global_position.z > start.z + 4.0, "courier should move forward (+Z)")
	Input.action_press("sprint")
	await frames(40)
	hs = Vector2(c.velocity.x, c.velocity.z).length()
	check(absf(hs - 10.0) < 0.8, "sprint speed should be ~10 m/s, got %.2f" % hs)
	check(c.stamina < c.max_stamina, "sprinting drains stamina")
	await _cleanup(arena)


func test_jump_height() -> void:
	var arena := _make_arena()
	await add(arena)
	var c := _spawn(arena, Vector3(0, 0.05, 0))
	await frames(15)
	var base_y := c.global_position.y
	Input.action_press("jump")
	await frames(2)
	Input.action_release("jump")
	var peak := base_y
	for i in 60:
		await frames(1)
		peak = maxf(peak, c.global_position.y)
	var h := peak - base_y
	check(absf(h - 1.4) < 0.2, "jump height should be ~1.4 m, got %.2f" % h)
	await _cleanup(arena)


func test_vault_low_box() -> void:
	var arena := _make_arena()
	Geo.box(arena, Vector3(0, 0.45, 0), Vector3(4, 0.9, 0.6), Color.BROWN)
	await add(arena)
	var c := _spawn(arena, Vector3(0, 0.05, -6))
	await frames(10)
	Input.action_press("move_forward")
	var vaulted := false
	for i in 120:
		await frames(1)
		if c.state == Courier.State.VAULT:
			vaulted = true
		if c.global_position.z > 2.0:
			break
	check(vaulted, "courier should enter VAULT on a 0.9 m box")
	check(c.global_position.z > 1.0, "courier should end up past the box (z=%.2f)" % c.global_position.z)
	await _cleanup(arena)


func test_too_tall_no_vault() -> void:
	var arena := _make_arena()
	Geo.box(arena, Vector3(0, 0.8, 0), Vector3(4, 1.6, 0.6), Color.BROWN)
	await add(arena)
	var c := _spawn(arena, Vector3(0, 0.05, -5))
	await frames(10)
	Input.action_press("move_forward")
	var vaulted := false
	for i in 80:
		await frames(1)
		vaulted = vaulted or c.state == Courier.State.VAULT
	check(not vaulted, "1.6 m (non-climbable) wall must not be vaulted")
	check(c.global_position.z < 0.0, "courier stays in front of the wall")
	await _cleanup(arena)


func test_climb_ledge() -> void:
	var arena := _make_arena()
	Geo.box(arena, Vector3(0, 1.7, 2), Vector3(6, 3.4, 2), Color.TAN, ["climbable"])
	await add(arena)
	var c := _spawn(arena, Vector3(0, 0.05, -1.5))
	await frames(10)
	Input.action_press("move_forward")
	await frames(10)
	Input.action_press("jump")
	await frames(3)
	Input.action_release("jump")
	var hung := false
	for i in 60:
		await frames(1)
		if c.state == Courier.State.HANG:
			hung = true
			break
	check(hung, "courier should grab the 3.4 m climbable ledge")
	Input.action_press("jump")
	await frames(3)
	Input.action_release("jump")
	await frames(60)
	check(c.global_position.y > 3.0, "courier should pull up onto the ledge (y=%.2f)" % c.global_position.y)
	await _cleanup(arena)


func test_slide() -> void:
	var arena := _make_arena()
	await add(arena)
	var c := _spawn(arena, Vector3(0, 0.05, -40))
	await frames(10)
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await frames(45)
	Input.action_press("crouch")
	await frames(3)
	check(c.state == Courier.State.SLIDE, "sprint + crouch should slide (state=%d)" % c.state)
	check(c.crouching, "sliding uses the crouched capsule")
	await _cleanup(arena)


func test_wallrun() -> void:
	var arena := _make_arena()
	Geo.box(arena, Vector3(-1.4, 3, 6), Vector3(0.5, 6, 14), Color.STEEL_BLUE, ["runnable"])
	await add(arena)
	var c := _spawn(arena, Vector3(-0.6, 0.05, -8))
	await frames(10)
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await frames(50)
	Input.action_press("jump")
	await frames(3)
	Input.action_release("jump")
	var ran := false
	for i in 40:
		await frames(1)
		ran = ran or c.state == Courier.State.WALLRUN
	check(ran, "jumping along a runnable wall while sprinting starts a wall-run")
	await _cleanup(arena)


func test_fall_damage() -> void:
	var arena := _make_arena()
	await add(arena)
	var c := _spawn(arena, Vector3(0, 10.0, 0))
	await frames(80)
	check(c.data.hp < c.data.max_hp and c.data.hp > 0.0, "10 m fall hurts but doesn't kill (hp=%.1f)" % c.data.hp)
	c.queue_free()
	await frames(2)
	var c2 := _spawn(arena, Vector3(5, 17.0, 0))
	await frames(100)
	check(c2.is_dead(), "17 m fall kills")
	var c3 := _spawn(arena, Vector3(-5, 4.0, 0))
	await frames(60)
	check(is_equal_approx(c3.data.hp, c3.data.max_hp), "4 m fall is safe")
	await _cleanup(arena)


func test_coyote_and_buffer_numbers() -> void:
	var t: MovementTuning = load("res://player/movement_tuning.tres")
	check(is_equal_approx(t.coyote_time, 0.12) and is_equal_approx(t.jump_buffer, 0.12), "coyote & buffer are 0.12 s")
	check(is_equal_approx(t.walk_speed, 4.0) and is_equal_approx(t.run_speed, 7.0) and is_equal_approx(t.sprint_speed, 10.0), "walk/run/sprint = 4/7/10")
