extends TestBase
## Data-level tests: inventory, traits, corpses, save/load, difficulty.


func test_inventory_slots() -> void:
	var inv := CarryInventory.new(4)
	inv.add("message", 1, true)
	eq(inv.used_slots(), 1, "message takes 1 slot")
	eq(inv.add("sling_stones", 3), 3, "stones added")
	eq(inv.add("sling_stones", 2), 2, "stones stack in the same slot")
	eq(inv.used_slots(), 2, "stack costs one slot")
	eq(inv.add("hand_axe", 1), 1, "axe (2 slots) fits")
	eq(inv.used_slots(), 4, "4/4 used")
	eq(inv.add("bandage", 1), 0, "no room for a bandage")
	eq(inv.add("scrap", 5), 5, "pouch materials take no slot")
	check(absf(inv.speed_multiplier(0.05, 2) - 0.9) < 0.001, "two slots past 2 = -10% speed")
	check(inv.droppable_entries().all(func(e): return e.id != "message"), "the Message is never droppable")


func test_death_creates_corpse_with_items() -> void:
	Game.new_road(7)
	var c := Game.courier
	c.inventory.add("bandage", 1)
	c.inventory.add("scrap", 4)
	var expected := c.inventory.droppable_entries()
	var name_before := c.full_name
	var idx_before := c.index
	var corpse := Game.handle_death("struck by lightning", 3, Vector3(1, 2, 3), 0.5)
	check(corpse != null, "a corpse record is created")
	eq(corpse.courier_name, name_before, "corpse keeps the courier's name")
	eq(corpse.zone, 3, "corpse zone")
	eq(corpse.local_pos, Vector3(1, 2, 3), "corpse position")
	eq(corpse.cause, "struck by lightning", "corpse cause")
	eq(corpse.inventory.to_array(), expected, "corpse holds exactly the droppable items")
	check(not corpse.inventory.has("message"), "the Message is not left on the body")
	eq(Game.fallen.size(), 1, "Roll of the Fallen gets an entry")
	eq(String(Game.fallen[0].cause), "struck by lightning", "Roll entry cause")
	var nc := Game.respawn()
	check(nc != c, "respawn creates a new courier")
	eq(nc.index, idx_before + 1, "courier index increments")
	check(nc.traits.size() >= 1 and nc.traits.size() <= 2, "new courier has 1-2 traits (%d)" % nc.traits.size())
	check(nc.inventory.has("message"), "the new courier carries the Message")
	check(nc.inventory.has("short_blade") and nc.inventory.count_of("bandage") == 1 and nc.inventory.count_of("sling_stones") == 3, "basic gear: blade, 1 bandage, 3 stones")
	eq(nc.hp, nc.max_hp, "new courier at full health")


func test_corpse_cap_removes_oldest() -> void:
	Game.new_road(8)
	for i in 31:
		Game.handle_death("test %d" % i, 0, Vector3(i, 0, 0))
		Game.respawn()
	eq(Game.corpses.size(), 30, "at most 30 corpses")
	eq(Game.corpses[0].cause, "test 1", "the oldest (#0) decayed")
	eq(Game.most_recent_corpse().cause, "test 30", "most recent corpse")


func test_trait_modifiers() -> void:
	var c := CourierData.new()
	c.traits = ["swift"]
	c.apply_base_stats(100.0, 4)
	check(is_equal_approx(c.speed_mult(), 1.2), "Swift: +20% speed")
	check(is_equal_approx(c.max_hp, 75.0), "Swift: -25% HP (got %.1f)" % c.max_hp)
	c.traits = ["ox"]
	c.apply_base_stats(100.0, 4)
	eq(c.inventory.capacity, 6, "Ox: +2 carry slots")
	check(is_equal_approx(c.climb_speed_mult(), 0.7), "Ox: -30% climb speed")
	c.traits = ["clumsy", "iron_lunged"]
	c.apply_base_stats(100.0, 4)
	check(is_equal_approx(c.max_hp, 120.0), "Clumsy: +20 HP")
	check(c.footstep_noise_mult() > 1.0, "Clumsy: loud footsteps")
	check(is_equal_approx(c.stamina_mult(), 1.4), "Iron-lunged: +40% stamina")
	c.traits = ["lucky"]
	check(c.loot_luck() > 0.0 and is_equal_approx(c.melee_damage_mult(), 0.8), "Lucky: luck up, -20% melee")
	c.traits = ["scarred"]
	check(is_equal_approx(c.detect_range_mult(), 1.3) and is_equal_approx(c.attack_hesitation(), 1.0), "Scarred: +30% detect, 1 s hesitation")
	c.traits = ["light_footed"]
	check(is_equal_approx(c.scent_mult(), 0.5), "Light-footed: scent x0.5")
	c.traits = ["old"]
	check(c.reveals_hidden_paths() and c.speed_mult() < 1.0, "Old: slower, reveals hidden paths")
	c.traits = ["night_eyed"]
	check(c.night_vision() and c.sun_glare(), "Night-eyed: night vision + glare")
	Game.new_road(9)
	var vet_found := false
	for i in 60:
		var nc := Game.create_new_courier(0)
		if nc.has_trait("veteran"):
			vet_found = true
			check(nc.inventory.has("hand_axe"), "Veteran starts with an extra weapon")
			break
	check(vet_found, "a veteran courier rolled within 60 tries")


func test_trait_roll_and_names() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var counts := {}
	for i in 200:
		var t := TraitDB.roll(rng)
		check(t.size() >= 1 and t.size() <= 2, "1-2 traits")
		check(not (t.has("swift") and t.has("old")), "exclusive traits never combine")
		var n := NameGenerator.generate(rng, t, counts)
		counts[n.first] = int(counts.get(n.first, 0)) + 1
		check(String(n.full).length() > 2, "name generated")
	eq(TraitDB.ids().size(), 10, "10 traits registered")


func test_station_activation_and_momentum() -> void:
	Game.new_road(10)
	check(Game.activate_station(1), "station 1 activates")
	eq(Game.last_station, 1, "last station = 1")
	eq(Game.momentum, 1, "momentum +1 per zone cleared")
	Game.activate_station(2)
	Game.activate_station(3)
	eq(Game.momentum, 3, "momentum 3")
	check(not Game.activate_station(2), "going back doesn't re-activate")
	eq(Game.last_station, 3, "respawn stays at the furthest station")
	Game.handle_death("test", 3, Vector3.ZERO)
	eq(Game.momentum, 0, "death resets momentum")
