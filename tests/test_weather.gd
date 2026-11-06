extends TestBase
## Phase 6: weather, lightning, wind, floods, day/night.

const COURIER := preload("res://player/courier.tscn")


func _setup() -> Array:
	var a := Node3D.new()
	a.name = "WeatherArena"
	Geo.box(a, Vector3(0, -0.5, 0), Vector3(120, 1, 120), Color.DIM_GRAY)
	runner.root.add_child(a)
	var tr := Node3D.new()
	tr.add_to_group("transient")
	a.add_child(tr)
	Game.new_road(5)
	Game.courier.traits.clear()
	Game.courier.apply_base_stats(100.0, 4)
	var c: Courier = COURIER.instantiate()
	c.data = Game.courier
	a.add_child(c)
	c.global_position = Vector3(0, 0.05, 0)
	var w := WeatherManager.new()
	a.add_child(w)
	await frames(3)
	return [a, c, w]


func test_day_night_cycle() -> void:
	check(is_equal_approx(Game.config.day_length_seconds, 720.0), "a full day is 12 real minutes")
	Game.time_of_day = 0.5
	check(Game.night_factor() < 0.01 and not Game.is_night(), "noon is day")
	Game.time_of_day = 0.0
	check(Game.night_factor() > 0.99 and Game.is_night(), "midnight is night")
	var was := Game.is_running
	Game.is_running = true
	Game.time_of_day = 0.3
	Game._process(72.0)
	check(absf(Game.time_of_day - 0.4) < 0.001, "72 s advance a tenth of a day")
	Game.is_running = was
	# night effects on AI
	var c := Courier.new()
	c.data = CourierData.new()
	Game.time_of_day = 0.5
	var day_scent := Perception.scent_mult(c)
	Game.time_of_day = 0.0
	check(Perception.scent_mult(c) > day_scent * 1.4, "hounds track scent better at night")
	c.free()
	Game.time_of_day = 0.5


func test_lightning_targets_highest_exposed_point() -> void:
	var s := await _setup()
	var a: Node3D = s[0]
	var c: Courier = s[1]
	var w: WeatherManager = s[2]
	var t := w.pick_lightning_target(c)
	check(t.distance_to(c.global_position + Vector3.UP * 1.8) < 0.05, "on flat open ground the courier is the highest point")
	Geo.box(a, Vector3(9, 3, 0), Vector3(12, 6, 30), Color.GRAY)
	await frames(2)
	var high := 0
	for i in 10:
		if w.pick_lightning_target(c).y > 5.5:
			high += 1
	check(high >= 8, "a tall rock nearby draws the strike (%d/10)" % high)
	# shelter: under an overhang the courier isn't exposed
	Geo.box(a, Vector3(-20, 3.2, 0), Vector3(5, 0.4, 5), Color.GRAY)
	var sh := VolumeArea.new()
	sh.kind = "shelter"
	sh.size = Vector3(4, 3, 4)
	sh.position = Vector3(-20, 0, 0)
	a.add_child(sh)
	c.global_position = Vector3(-20, 0.05, 0)
	await frames(5)
	check(c.is_sheltered(), "courier is inside the shelter volume")
	check(not w.is_exposed(c.global_position + Vector3.UP * 1.8, c), "a sheltered courier is not exposed")
	a.queue_free()
	await frames(2)


func test_lightning_warning_then_strike() -> void:
	var s := await _setup()
	var a: Node3D = s[0]
	var c: Courier = s[1]
	var w: WeatherManager = s[2]
	var times := {}
	var t0 := Time.get_ticks_msec()
	var on_warn := func(_p): times["warn"] = Time.get_ticks_msec() - t0
	var on_strike := func(_p): times["strike"] = Time.get_ticks_msec() - t0
	Events.lightning_warning.connect(on_warn)
	Events.lightning_strike.connect(on_strike)
	var hp := c.data.hp
	w.strike_at(c.global_position + Vector3.UP * 1.8)
	await runner.create_timer(1.9).timeout
	Events.lightning_warning.disconnect(on_warn)
	Events.lightning_strike.disconnect(on_strike)
	check(times.has("warn") and times.has("strike"), "warning and strike both happened")
	if times.has("strike"):
		var gap: int = int(times.strike) - int(times.get("warn", 0))
		check(gap >= 1400 and gap <= 1800, "strike follows the warning by ~1.5 s (%d ms)" % gap)
	check(c.data.hp < hp, "an exposed courier under the strike is hurt")
	a.queue_free()
	await frames(2)


func test_wind_gust_pushes_midair() -> void:
	var s := await _setup()
	var a: Node3D = s[0]
	var c: Courier = s[1]
	var w: WeatherManager = s[2]
	c.global_position = Vector3(0, 6, 0)
	c.velocity = Vector3.ZERO
	c.global_position = Vector3(0, 8, 0)
	w.gust(Vector3(1, 0, 0))
	await frames(40)
	check(c.global_position.x > 0.8, "a gust pushes the courier sideways mid-air (x=%.2f)" % c.global_position.x)
	a.queue_free()
	await frames(2)


func test_flood_and_dust() -> void:
	var s := await _setup()
	var a: Node3D = s[0]
	var w: WeatherManager = s[2]
	var water := WaterVolume.new()
	water.size = Vector3(6, 1, 6)
	water.base_depth = 0.5
	water.flood_depth = 2.0
	a.add_child(water)
	await frames(2)
	water.set_flooded(true)
	for i in 300:
		await frames(1)
	check(water.depth > 1.5, "flash flood raises the water (%.2f)" % water.depth)
	w.active = true
	w.kind = "dust"
	w.intensity = 1.0
	check(w.scent_disabled(), "an intense dust storm disables scent tracking")
	check(w.visibility_mult() < 0.5, "and visibility is very low")
	w.kind = "rain"
	check(not w.scent_disabled() and w.visibility_mult() < 1.0, "rain lowers visibility but not scent")
	w.active = false
	a.queue_free()
	await frames(2)


func test_storm_front_in_world() -> void:
	ZoneGenerator.clear_cache()
	Game.new_road(888)
	var world: GameWorld = load("res://world/game_world.tscn").instantiate()
	runner.root.add_child(world)
	runner.current_scene = world
	await frames(5)
	var w: WeatherManager = world.weather
	check(w != null, "game world has a weather manager")
	w.start_storm("rain")
	check(w.active, "storm started")
	var p0 := w.front_progress
	await frames(60)
	check(w.front_progress > p0, "the front moves along the road")
	check(w.intensity > 0.0, "the courier feels it (%.2f)" % w.intensity)
	w.front_progress = 9999.0
	await frames(3)
	check(not w.active, "storm ends after the front passes the zone end")
	world.queue_free()
	runner.current_scene = null
	await frames(3)
