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


func test_save_load_roundtrip() -> void:
	Game.new_road(4321)
	Game.courier.inventory.add("scrap", 7)
	Game.activate_station(1)
	Game.activate_station(2)
	Game.current_zone = 2
	Game.highest_zone = 2
	Game.handle_death("eaten by the test", 2, Vector3(3, 1, 40))
	Game.respawn()
	Game.handle_death("second death", 1, Vector3(-2, 0, 10))
	Game.respawn()
	Game.stash.add("bandage", 2)
	Game.stash.add("oil", 3)
	Game.global_upgrades.append("forge")
	Game.station_upgrades["2"] = ["bed"]
	Game.fragments = [0]
	Game.mark_toll_paid(2, "toll_5")
	Game.mark_cache_looted(2, "cache_0")
	Game.current_zone = 2
	var before := Game.to_dict()
	check(Save.save_game(), "save written")
	Game.new_road(1)
	check(Game.world_seed != 4321, "state cleared")
	check(Save.load_game(), "save loaded")
	eq(Game.world_seed, 4321, "seed restored")
	eq(Game.current_zone, 2, "zone index restored")
	eq(Game.last_station, 2, "last station restored")
	eq(Game.courier_counter, 3, "lineage counter restored")
	eq(Game.fallen.size(), 2, "Roll of the Fallen restored")
	eq(String(Game.fallen[0].cause), "eaten by the test", "fallen entry restored")
	eq(Game.corpses.size(), 2, "corpses restored")
	eq(Game.corpses[0].local_pos, Vector3(3, 1, 40), "corpse position restored")
	check(Game.corpses[0].inventory.has("scrap"), "corpse items restored")
	eq(Game.stash.count_of("bandage"), 2, "stash restored")
	eq(Game.stash.count_of("oil"), 3, "stash materials restored")
	check(Game.has_upgrade("forge") and Game.has_upgrade("bed", 2) and not Game.has_upgrade("bed", 1), "upgrades restored (global + per station)")
	eq(Game.fragments, [0] as Array[int], "fragments restored")
	check(Game.is_toll_paid(2, "toll_5") and Game.is_cache_looted(2, "cache_0"), "tolls & caches restored")
	eq(Game.courier.index, 3, "current courier restored")
	check(JSON.stringify(Game.to_dict()) == JSON.stringify(before), "full state round-trips identically")
	Save.delete_save()


func test_upgrades_and_kennel() -> void:
	Game.new_road(11)
	check(not Game.build_upgrade("bed", 3), "can't build without materials")
	Game.courier.inventory.add("cloth", 3, true)
	Game.stash.add("scrap", 6)
	check(Game.build_upgrade("bed", 3), "bed built at station 3 (pouch + stash materials)")
	eq(Game.courier.inventory.count_of("cloth"), 0, "cloth spent")
	Game.courier.inventory.add("oil", 2, true)
	check(Game.build_upgrade("forge", 3), "forge built")
	check(Game.has_upgrade("forge", 99), "forge is global")
	check(Game.has_upgrade("bed", 3) and not Game.has_upgrade("bed", 4), "bed is per station")
	var base := CourierData.new()
	var c3 := Game.create_new_courier(3)
	var c4 := Game.create_new_courier(4)
	base.traits = c3.traits
	base.apply_base_stats(100.0, 4)
	check(is_equal_approx(c3.max_hp, base.max_hp + 20.0), "Bed: +20 HP when spawning at station 3")
	check(c4.inventory.has("fine_blade") and not c4.inventory.has("short_blade"), "Forge: better blade")


func test_momentum_effects_and_fragments() -> void:
	Game.new_road(12)
	Game.courier.traits.clear()
	check(is_equal_approx(Game.momentum_speed_mult(), 1.0), "no bonus at 0")
	Game.set_momentum(2)
	check(is_equal_approx(Game.momentum_speed_mult(), 1.05), "momentum 2: +5% speed")
	var l2 := Game.loot_luck()
	Game.set_momentum(3)
	check(Game.loot_luck() > l2, "momentum 3: better loot")
	check(not Game.reveals_hidden_paths(), "no shortcuts below 5")
	Game.set_momentum(5)
	check(Game.reveals_hidden_paths(), "momentum 5: Fast Courier reveals shortcuts")
	Game.set_momentum(9)
	eq(Game.momentum, 5, "momentum caps at 5")
	# fragments every 25 zones
	Game.new_road(13)
	var got: Array = []
	var cb := func(i): got.append(i)
	Events.message_fragment_revealed.connect(cb)
	for s in range(1, 52):
		Game.activate_station(s)
	Events.message_fragment_revealed.disconnect(cb)
	eq(got, [0, 1], "Seal Breaks at relays 25 and 50")
	eq(MessageFragments.TEXT.size(), 8, "8 fragments written")
	# fast courier time bonus
	Game.new_road(14)
	Game.set_momentum(4)
	Game.zone_enter_time = Game.play_time
	var mats_before := 0
	for m in ItemDB.MATERIALS:
		mats_before += Game.courier.inventory.count_of(m)
	Game.activate_station(1)
	var mats_after := 0
	for m in ItemDB.MATERIALS:
		mats_after += Game.courier.inventory.count_of(m)
	check(Game.momentum == 5 and mats_after > mats_before, "Fast Courier: station-to-station time bonus")


func test_stash_shared_between_couriers() -> void:
	Game.new_road(15)
	Game.stash.add("bandage", 1)
	Game.handle_death("x", 0, Vector3.ZERO)
	Game.respawn()
	eq(Game.stash.count_of("bandage"), 1, "stash survives death")
	eq(Game.stash.capacity, 6, "stash has 6 slots")
