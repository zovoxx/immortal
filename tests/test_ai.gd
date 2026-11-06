extends TestBase
## Phase 4/5: scent, perception, hounds, scavengers, toll-keeper, watchtower, rider, combat.

const COURIER := preload("res://player/courier.tscn")


func _arena() -> Node3D:
	var a := Node3D.new()
	a.name = "AIArena"
	Geo.box(a, Vector3(0, -0.5, 0), Vector3(120, 1, 120), Color.DIM_GRAY)
	return a


func _courier(a: Node3D, pos: Vector3, traits: Array[String] = []) -> Courier:
	Game.new_road(99)
	Game.time_of_day = 0.5
	Game.courier.traits = traits
	Game.courier.apply_base_stats(100.0, 4)
	var c: Courier = COURIER.instantiate()
	c.data = Game.courier
	a.add_child(c)
	c.global_position = pos
	return c


func _enemy(a: Node3D, script_path: String, pos: Vector3, yaw: float = 0.0) -> Enemy:
	var e: Enemy = load(script_path).new()
	e.position = pos
	a.add_child(e)
	if e.model:
		e.model.rotation.y = yaw
	return e


func _done(a: Node) -> void:
	release_all_inputs()
	a.queue_free()
	await frames(3)


func test_scent_ring_buffer() -> void:
	var s := ScentTrail.new(60)
	for i in 70:
		s.add_point(Vector3(i, 0, 0), float(i))
	eq(s.size(), 60, "ring buffer keeps 60 points")
	eq(s.points()[0].pos, Vector3(10, 0, 0), "oldest point is #10 after 70 adds")
	eq(s.newest().pos, Vector3(69, 0, 0), "newest point is #69")
	# a point every 0.5 s while moving
	var t := ScentTrail.new(60)
	for i in 20:
		t.update(0.1, Vector3(i * 0.5, 0, 0), i * 0.1)
	eq(t.size(), 4, "one point per 0.5 s (2 s -> 4 points)")
	# standing still strengthens the newest point
	var before: float = t.newest().strength
	for i in 20:
		t.update(0.1, Vector3(9.5, 0, 0), 2.0 + i * 0.1)
	check(float(t.newest().strength) > before, "standing still makes the latest point stronger")
	eq(t.size(), 4, "standing still doesn't add points")


func test_water_erases_scent() -> void:
	var a := _arena()
	await add(a)
	var w := WaterVolume.new()
	w.size = Vector3(6, 1, 6)
	w.position = Vector3(0, 0, 10)
	a.add_child(w)
	await frames(2)
	var s := ScentTrail.new(60)
	for i in 30:
		s.add_point(Vector3(0, 0.2, i), float(i))
	var removed := s.erase_where(func(p): return w.contains_point(p))
	check(removed >= 5, "points inside water are erased (%d)" % removed)
	check(s.points().all(func(p): return not w.contains_point(p.pos)), "no remaining point is in water")
	eq(s.size(), 30 - removed, "others are kept")
	# the courier's own trail uses the same rule
	var c := _courier(a, Vector3(0, 0.05, 10))
	await frames(2)
	c.scent.add_point(Vector3(0, 0.2, 10), 0.0)
	c.scent.add_point(Vector3(0, 0.2, 30), 0.1)
	c.scent.erase_where(c._point_in_water)
	eq(c.scent.size(), 1, "courier trail point in water erased")
	await _done(a)


func test_sight_cone_and_modifiers() -> void:
	var a := _arena()
	await add(a)
	var c := _courier(a, Vector3(0, 0.05, -10))
	var e := _enemy(a, "res://enemies/hound/hound.gd", Vector3(0, 0.1, 0), 0.0)  # faces -Z (toward courier)
	await frames(5)
	e.target = c
	check(e.can_see_courier(), "enemy sees a courier 10 m in front")
	e.model.rotation.y = PI
	check(not e.can_see_courier(), "enemy doesn't see a courier behind it")
	e.model.rotation.y = 0.0
	Input.action_press("crouch")
	c.global_position = Vector3(0, 0.05, -12)
	await frames(4)
	check(c.crouching, "courier is crouching")
	check(not e.can_see_courier(), "crouching at 12 m is outside the reduced sight range")
	Input.action_release("crouch")
	await frames(4)
	Game.time_of_day = 0.0
	check(not e.can_see_courier(), "at night sight range drops (12 m unseen)")
	Game.time_of_day = 0.5
	check(e.can_see_courier(), "daylight: seen again")
	Geo.box(a, Vector3(0, 1.5, -6), Vector3(6, 3, 0.5), Color.GRAY)
	await frames(3)
	check(not e.can_see_courier(), "a wall blocks line of sight")
	await _done(a)


func test_sound_makes_suspicious() -> void:
	var a := _arena()
	await add(a)
	var c := _courier(a, Vector3(0, 0.05, 30))
	var e := _enemy(a, "res://enemies/hound/hound.gd", Vector3(0, 0.1, 0), PI)
	await frames(5)
	Events.sound_emitted.emit(Vector3(5, 0, 0), 10.0, "footstep")
	await frames(2)
	eq(e.state, Enemy.State.SUSPICIOUS, "a sound within its radius makes the enemy suspicious")
	var e2 := _enemy(a, "res://enemies/hound/hound.gd", Vector3(-40, 0.1, 0))
	await frames(3)
	Events.sound_emitted.emit(Vector3(5, 0, 0), 10.0, "footstep")
	await frames(2)
	check(e2.state != Enemy.State.SUSPICIOUS, "a far enemy doesn't hear it")
	await _done(a)


func test_hound_follows_scent_trail() -> void:
	var a := _arena()
	# a wall between hound and courier so it can't see: it must use the trail
	Geo.box(a, Vector3(5, 2, 10), Vector3(0.5, 4, 30), Color.GRAY)
	await add(a)
	var c := _courier(a, Vector3(12, 0.05, 20))
	# lay a trail from near the hound around the wall to the courier
	var pts := [Vector3(0, 0, 0), Vector3(0, 0, 6), Vector3(0, 0, 12), Vector3(0, 0, 18), Vector3(0, 0, 24), Vector3(0, 0, 28), Vector3(4, 0, 28), Vector3(8, 0, 27), Vector3(10, 0, 24), Vector3(12, 0, 21)]
	c.scent.clear()
	for i in pts.size():
		c.scent.add_point(pts[i], float(i))
	var h: Hound = _enemy(a, "res://enemies/hound/hound.gd", Vector3(-1.5, 0.1, -2), PI)
	await frames(2)
	c.input_enabled = false
	var reached := false
	var tracked := false
	for i in 600:
		await frames(1)
		c.scent._timer = 0.0  # freeze the trail
		tracked = tracked or h.tracking
		if h.global_position.distance_to(c.global_position) < 3.5:
			reached = true
			break
	check(tracked, "hound picked up and tracked the scent")
	check(reached, "hound followed the trail to the courier (dist %.1f)" % h.global_position.distance_to(c.global_position))
	await _done(a)


func test_light_footed_harder_to_track() -> void:
	var a := _arena()
	await add(a)
	var c := _courier(a, Vector3(30, 0.05, 30), ["light_footed"])
	c.scent.clear()
	c.scent.add_point(Vector3(4.0, 0, 0), 0.0)
	var h: Hound = _enemy(a, "res://enemies/hound/hound.gd", Vector3(0, 0.1, 0))
	await frames(2)
	h.target = c
	check(h._find_scent_start().is_empty(), "light-footed: a point 4 m away is not picked up (radius halved)")
	c.data.traits.clear()
	check(not h._find_scent_start().is_empty(), "normal courier: picked up")
	await _done(a)


func test_hound_cannot_climb() -> void:
	var a := _arena()
	Geo.box(a, Vector3(0, 2, 6), Vector3(4, 4, 4), Color.GRAY, ["climbable"])
	await add(a)
	var c := _courier(a, Vector3(0, 4.1, 6))
	var h: Hound = _enemy(a, "res://enemies/hound/hound.gd", Vector3(0, 0.1, -2))
	await frames(5)
	h.target = c
	h.last_known = c.global_position
	h.awareness = 1.2
	h._enter(Enemy.State.CHASE)
	var gave_up := false
	for i in 480:
		await frames(1)
		if h.state in [Enemy.State.SEARCH, Enemy.State.RETURN, Enemy.State.IDLE, Enemy.State.PATROL]:
			gave_up = true
			break
	check(gave_up, "a hound gives up on a courier up high (state %s)" % h.state_name())
	check(c.data.hp == c.data.max_hp, "and never hurt them")
	await _done(a)


func test_scavenger_steals_and_drops() -> void:
	var a := _arena()
	await add(a)
	var c := _courier(a, Vector3(50, 0.05, 50))
	Game.corpses.clear()
	var cd := Game.handle_death("test", 0, Vector3(0, 0, 5))
	Game.respawn()
	cd.inventory.entries.clear()
	cd.inventory.add("bandage", 2)
	cd.inventory.add("scrap", 3)
	var corpse: Corpse = preload("res://world/corpse/corpse.tscn").instantiate()
	corpse.data = cd
	a.add_child(corpse)
	corpse.position = cd.local_pos
	var s: Scavenger = _enemy(a, "res://enemies/scavenger/scavenger.gd", Vector3(0, 0.1, -6))
	s._steal_timer = 0.5
	var reached := false
	for i in 300:
		await frames(1)
		if s.global_position.distance_to(corpse.global_position) < 2.0:
			reached = true
		if s.stolen.size() > 0:
			break
	check(reached, "scavenger walked to the corpse")
	eq(s.stolen.size(), 1, "scavenger stole one item")
	eq(cd.inventory.count_of("bandage") + cd.inventory.count_of("scrap"), 4, "the corpse lost that item (5 -> 4 units)")
	check(is_equal_approx(Game.config.scavenger_steal_interval, 45.0), "steal interval is 45 s")
	var stolen_copy := s.stolen.duplicate()
	s.take_damage(999.0)
	await frames(3)
	var bags := a.find_children("*", "LootBag", true, false)
	eq(bags.size(), 1, "killing it drops a sack")
	if bags.size() > 0:
		var bag: LootBag = bags[0]
		check(bag.container.inventory.count_of("bandage") + bag.container.inventory.count_of("scrap") >= 1, "the sack holds the stolen item")
	await _done(a)


func test_scavenger_flees_courier() -> void:
	var a := _arena()
	await add(a)
	var c := _courier(a, Vector3(0, 0.05, -4))
	var s: Scavenger = _enemy(a, "res://enemies/scavenger/scavenger.gd", Vector3(0, 0.1, 0), 0.0)
	var start_d := s.global_position.distance_to(c.global_position)
	for i in 150:
		await frames(1)
	eq(s.state, Enemy.State.FLEE, "scavenger flees when it sees the courier")
	check(s.global_position.distance_to(c.global_position) > start_d + 3.0, "and gets away")
	await _done(a)


func test_world_hounds_chase_on_navmesh() -> void:
	ZoneGenerator.clear_cache()
	Game.new_road(6060)
	Game.time_of_day = 0.5
	Game.courier.traits.clear()
	var world: GameWorld = load("res://world/game_world.tscn").instantiate()
	runner.root.add_child(world)
	runner.current_scene = world
	await frames(5)
	var hounds := runner.get_nodes_in_group("hunter").filter(func(n): return n is Hound)
	check(hounds.size() >= 2, "zone 0/1 spawned hounds (%d)" % hounds.size())
	if hounds.is_empty():
		world.queue_free()
		return
	var h: Hound = hounds[0]
	var zone := world.streamer.zone_instance(h.zone_index)
	var t := 0
	while not zone.nav_ready and t < 600:
		await frames(1)
		t += 1
	check(zone.nav_ready, "navmesh ready")
	Game.god_mode = true
	world.courier.global_position = h.global_position + Vector3(0, 0.5, 6)
	world.courier.input_enabled = false
	var chased := false
	var start := h.global_position
	for i in 240:
		await frames(1)
		chased = chased or h.state in [Enemy.State.CHASE, Enemy.State.ATTACK]
	Game.god_mode = false
	check(chased, "hound chases a courier standing next to it (state %s)" % h.state_name())
	check(h.global_position.distance_to(start) > 1.0, "and moves")
	world.queue_free()
	runner.current_scene = null
	await frames(3)
