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
