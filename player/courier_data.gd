class_name CourierData
extends RefCounted
## One courier of the lineage: identity, traits, health and carried items.

var index: int = 1
var first_name: String = ""
var full_name: String = ""
var traits: Array[String] = []
var max_hp: float = 100.0
var hp: float = 100.0
var inventory: CarryInventory = CarryInventory.new(4)
var lived_seconds: float = 0.0
var born_unix: float = 0.0
var spawn_station: int = 0
var kennel_used: bool = false


func trait_resources() -> Array[CourierTrait]:
	var out: Array[CourierTrait] = []
	for id in traits:
		var t := TraitDB.get_trait(id)
		if t:
			out.append(t)
	return out


func _mult(prop: StringName) -> float:
	var m := 1.0
	for t in trait_resources():
		m *= float(t.get(prop))
	return m


func _sum(prop: StringName) -> float:
	var s := 0.0
	for t in trait_resources():
		s += float(t.get(prop))
	return s


func _any(prop: StringName) -> bool:
	for t in trait_resources():
		if bool(t.get(prop)):
			return true
	return false


func speed_mult() -> float: return _mult(&"speed_mult")
func stamina_mult() -> float: return _mult(&"stamina_mult")
func climb_speed_mult() -> float: return _mult(&"climb_speed_mult")
func melee_damage_mult() -> float: return _mult(&"melee_damage_mult")
func detect_range_mult() -> float: return _mult(&"enemy_detect_range_mult")
func scent_mult() -> float: return _mult(&"scent_mult")
func footstep_noise_mult() -> float: return _mult(&"footstep_noise_mult")
func attack_hesitation() -> float: return _sum(&"enemy_attack_hesitation")
func loot_luck() -> float: return _sum(&"loot_luck")
func night_vision() -> bool: return _any(&"night_vision")
func sun_glare() -> bool: return _any(&"sun_glare")
func reveals_hidden_paths() -> bool: return _any(&"reveals_hidden_paths")
func has_trait(id: String) -> bool: return traits.has(id)


## Computes max HP / carry capacity from config + traits + bonus. Fills HP.
func apply_base_stats(base_hp: float, base_slots: int, bonus_hp: float = 0.0) -> void:
	max_hp = roundf(base_hp * _mult(&"hp_mult") + _sum(&"hp_add") + bonus_hp)
	hp = max_hp
	inventory.capacity = base_slots + int(_sum(&"carry_slots_add"))


func trait_names() -> String:
	var names: PackedStringArray = []
	for t in trait_resources():
		names.append(t.display_name)
	return ", ".join(names)


func to_dict() -> Dictionary:
	return {
		"index": index, "first_name": first_name, "full_name": full_name,
		"traits": traits.duplicate(), "max_hp": max_hp, "hp": hp,
		"capacity": inventory.capacity, "items": inventory.to_array(),
		"lived_seconds": lived_seconds, "born_unix": born_unix,
		"spawn_station": spawn_station, "kennel_used": kennel_used,
	}


static func from_dict(d: Dictionary) -> CourierData:
	var c := CourierData.new()
	c.index = int(d.get("index", 1))
	c.first_name = String(d.get("first_name", ""))
	c.full_name = String(d.get("full_name", "Courier"))
	c.traits.clear()
	for t in d.get("traits", []):
		c.traits.append(String(t))
	c.max_hp = float(d.get("max_hp", 100.0))
	c.hp = float(d.get("hp", c.max_hp))
	c.inventory = CarryInventory.new(int(d.get("capacity", 4)))
	c.inventory.from_array(d.get("items", []))
	c.lived_seconds = float(d.get("lived_seconds", 0.0))
	c.born_unix = float(d.get("born_unix", 0.0))
	c.spawn_station = int(d.get("spawn_station", 0))
	c.kennel_used = bool(d.get("kennel_used", false))
	return c
