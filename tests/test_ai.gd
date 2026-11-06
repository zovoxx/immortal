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


func test_blade_light_and_charged() -> void:
	var a := _arena()
	await add(a)
	var c := _courier(a, Vector3(0, 0.05, 0))
	var h: Hound = _enemy(a, "res://enemies/hound/hound.gd", Vector3(0, 0.1, -1.4))
	await frames(3)
	c.facing = Vector3(0, 0, -1)
	var hp0 := h.hp
	eq(c.combat.melee(false), 1, "light attack hits the hound in front")
	var light := hp0 - h.hp
	check(is_equal_approx(light, 15.0), "short blade light = 15 (got %.1f)" % light)
	h.hp = 1000.0
	c.combat._cooldown = 0.0
	c.combat.melee(true)
	check(is_equal_approx(1000.0 - h.hp, 35.0), "charged = 35")
	c.facing = Vector3(0, 0, 1)
	eq(c.combat.melee(false), 0, "no hit behind the courier")
	c.data.traits = ["lucky"]
	c.facing = Vector3(0, 0, -1)
	h.hp = 1000.0
	c.combat.melee(false)
	check(is_equal_approx(1000.0 - h.hp, 12.0), "Lucky: -20% melee (12)")
	await _done(a)


func test_dodge_roll_iframes() -> void:
	var a := _arena()
	await add(a)
	var c := _courier(a, Vector3(0, 0.05, 0))
	await frames(5)
	Input.action_press("dodge")
	await frames(2)
	Input.action_release("dodge")
	eq(c.state, Courier.State.ROLL, "dodge starts a roll")
	check(c.stamina < c.max_stamina, "roll costs stamina")
	var hp := c.data.hp
	c.take_damage(20.0, "test")
	eq(c.data.hp, hp, "invulnerable during the roll's i-frames")
	await frames(30)
	c.take_damage(20.0, "test")
	check(c.data.hp < hp, "vulnerable after")
	await _done(a)


func test_sling_breaks_lantern_and_tower_alarm() -> void:
	var a := _arena()
	await add(a)
	var c := _courier(a, Vector3(0, 0.05, 30))
	var tw := Watchtower.new()
	tw.position = Vector3(0, 0, 0)
	tw.sweep_half_angle_deg = 0.0
	tw.beam_ground_distance = 17.0
	a.add_child(tw)
	var h: Hound = _enemy(a, "res://enemies/hound/hound.gd", Vector3(30, 0.1, -30))
	await frames(3)
	# put the courier where the beam lands (tower faces -Z with yaw 0)
	c.global_position = Vector3(0, 0.05, -16.0)
	c.input_enabled = false
	var rang := false
	for i in 150:
		await frames(1)
		if tw.alarm_timer > 0.0:
			rang = true
			break
	check(rang, "standing in the light ~1 s rings the bell (exposure %.2f)" % tw.exposure)
	await frames(3)
	eq(h.state, Enemy.State.CHASE, "a hunter within 60 m enters CHASE on the bell")
	# shoot the lantern
	c.global_position = Vector3(0, 0.05, -20.0)
	await frames(2)
	c.combat.throw_item("sling_stones", tw.lantern.global_position)
	var broken := false
	for i in 90:
		await frames(1)
		if tw.is_disabled():
			broken = true
			break
	check(broken, "a sling stone to the lantern disables the tower")
	check(tw.disabled_time > 25.0 and tw.disabled_time <= 30.0, "for 30 s")
	tw.alarm_timer = 0.0
	tw.exposure = 0.0
	await frames(90)
	eq(tw.alarm_timer, 0.0, "a dark tower can't raise the alarm")
	await _done(a)


func test_noise_maker_distracts() -> void:
	var a := _arena()
	await add(a)
	var c := _courier(a, Vector3(0, 0.05, 40))
	var e := _enemy(a, "res://enemies/hound/hound.gd", Vector3(0, 0.1, 0), PI)
	await frames(3)
	c.data.inventory.add("noise_maker", 1, true)
	check(c.combat.throw_item("noise_maker", Vector3(10, 0, 5)), "noise-maker thrown")
	var sus := false
	for i in 120:
		await frames(1)
		if e.state == Enemy.State.SUSPICIOUS:
			sus = true
			break
	check(sus, "noise-maker makes the enemy investigate")
	check(e.investigate_pos.distance_to(Vector3(10, 0, 5)) < 4.0, "toward the noise (%s)" % e.investigate_pos)
	await _done(a)


func test_smoke_blocks_sight() -> void:
	var a := _arena()
	await add(a)
	var c := _courier(a, Vector3(0, 0.05, -10))
	var e := _enemy(a, "res://enemies/hound/hound.gd", Vector3(0, 0.1, 0), 0.0)
	await frames(3)
	e.target = c
	check(e.can_see_courier(), "sees before smoke")
	var s := SmokeCloud.new()
	a.add_child(s)
	s.global_position = Vector3(0, 1, -5)
	await frames(2)
	check(not e.can_see_courier(), "smoke breaks line of sight")
	await _done(a)


func test_tollkeeper_pay_sneak_fight() -> void:
	var a := _arena()
	await add(a)
	var c := _courier(a, Vector3(0, 0.05, -6))
	var t: Tollkeeper = load("res://enemies/tollkeeper/tollkeeper.gd").new()
	t.feature_id = "toll_test"
	t.position = Vector3(0, 0.1, 0)
	a.add_child(t)
	t.set_initial_yaw(0.0)  # faces -Z, toward the courier
	await frames(20)
	t.look_cycle = 1000.0
	t._look_t = 0.0
	await frames(90)
	check(t.demanding, "toll-keeper demands the toll when the courier approaches in front")
	c.data.inventory.entries.clear()
	c.data.inventory.add("message", 1, true)
	check(not t.can_pay(), "the Message can't pay the toll")
	c.data.inventory.add("scrap", 1)
	c.data.inventory.add("bandage", 1)
	c.data.inventory.add("short_blade", 1)
	var price := t.price()
	check(price >= 1, "price >= 1")
	check(t.pay(), "paying works")
	check(t.paid and Game.is_toll_paid(t.zone_index, "toll_test"), "toll recorded as paid")
	check(c.data.inventory.has("short_blade"), "least valuable items are taken first")
	check(not t.hostile, "stays peaceful")
	# --- sneaking: a fresh keeper looking the other way doesn't notice a courier behind it
	var t2: Tollkeeper = load("res://enemies/tollkeeper/tollkeeper.gd").new()
	t2.position = Vector3(20, 0.1, 0)
	a.add_child(t2)
	t2.set_initial_yaw(0.0)
	await frames(2)
	t2.look_cycle = 1000.0
	c.global_position = Vector3(20, 0.05, 4.0)  # behind it
	await frames(40)
	check(not t2.demanding and not t2.hostile, "sneaking behind it goes unnoticed")
	# --- fighting: attacking makes it hostile
	t2.take_damage(10.0, c.global_position)
	await frames(2)
	check(t2.hostile, "attacking it makes it hostile")
	check(t2.hp > 150.0, "it has high HP (%.0f)" % t2.hp)
	await _done(a)


func test_tollkeeper_angry_if_passed_while_watching() -> void:
	var a := _arena()
	await add(a)
	var c := _courier(a, Vector3(0, 0.05, -5))
	var t: Tollkeeper = load("res://enemies/tollkeeper/tollkeeper.gd").new()
	t.position = Vector3(0, 0.1, 0)
	a.add_child(t)
	t.set_initial_yaw(0.0)
	await frames(3)
	t.look_cycle = 1000.0
	t._look_t = 0.0
	await frames(90)
	check(t.demanding, "demanding")
	# walk past it on the side while it watches
	c.global_position = Vector3(1.8, 0.05, 1.6)
	await frames(30)
	check(t.hostile, "slipping past while it watches makes it hostile")
	await _done(a)


func test_rider_turn_limit_and_crash() -> void:
	var a := _arena()
	Geo.box(a, Vector3(0, 2, -30), Vector3(30, 4, 1), Color.GRAY)
	await add(a)
	var c := _courier(a, Vector3(0, 0.05, -45))
	c.input_enabled = false
	Game.god_mode = true
	var r: Rider = load("res://enemies/rider/rider.gd").new()
	r.position = Vector3(0, 0.1, 10)
	a.add_child(r)
	r.set_initial_yaw(0.0)
	await frames(3)
	r.target = c
	r.last_known = c.global_position
	r.awareness = 1.2
	r._enter(Enemy.State.CHASE)
	var max_turn := 0.0
	var prev := r.heading
	var stunned := false
	var top_speed := 0.0
	for i in 300:
		await frames(1)
		r.sees_player = true
		r._lost_sight_time = 0.0
		max_turn = maxf(max_turn, absf(wrapf(r.heading - prev, -PI, PI)) * 60.0)
		prev = r.heading
		top_speed = maxf(top_speed, r.speed)
		if r.state == Enemy.State.STUNNED:
			stunned = true
			break
	Game.god_mode = false
	check(top_speed > 11.0, "rider gallops fast on open ground (%.1f m/s)" % top_speed)
	check(max_turn <= r.turn_rate_slow + 0.1, "turn rate is limited (%.2f rad/s)" % max_turn)
	check(stunned, "charging into a wall stuns the rider")
	await _done(a)


func test_rider_predicts_path() -> void:
	var a := _arena()
	await add(a)
	var c := _courier(a, Vector3(0, 0.05, 0))
	c.velocity = Vector3(10, 0, 0)
	var r: Rider = load("res://enemies/rider/rider.gd").new()
	r.position = Vector3(0, 0.1, -20)
	a.add_child(r)
	r.set_initial_yaw(PI)  # facing +Z toward the courier
	await frames(2)
	r.target = c
	r._enter(Enemy.State.CHASE)
	var h0 := r.heading
	# one step of steering: it should turn toward where the courier will be (+X), not straight at it
	c.input_enabled = false
	r.speed = 12.0
	r._move(0.1)
	check(wrapf(r.heading - h0, -PI, PI) < -0.01 or wrapf(r.heading - h0, -PI, PI) > 0.01, "rider steers toward the predicted position")
	var f := r.forward()
	check(f.x > 0.0, "leading the courier who runs +X (forward %s)" % f)
	await _done(a)
