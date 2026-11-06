class_name Difficulty
extends RefCounted
## Difficulty lookups for a zone (uses DifficultyCurves + the zone's biome).

static var curves: DifficultyCurves = preload("res://world/zone_gen/difficulty_curves.tres")


static func _loop(zone: int) -> int:
	return zone / (Game.config.zones_per_biome * 5)


static func enemy_groups(zone: int) -> int:
	var c := curves
	return maxi(1, floori(c.eval(c.groups_base, c.groups_per_zone, c.groups_per_loop, zone, _loop(zone), 1.0, c.groups_max)))


static func enemy_hp_mult(zone: int) -> float:
	var c := curves
	return c.eval(c.hp_base, c.hp_per_zone, c.hp_per_loop, zone, _loop(zone), 0.5, c.hp_max)


static func enemy_damage_mult(zone: int) -> float:
	var c := curves
	return c.eval(c.damage_base, c.damage_per_zone, c.damage_per_loop, zone, _loop(zone), 0.5, c.damage_max)


static func storm_chance(zone: int) -> float:
	var c := curves
	var b := BiomeDB.for_zone(zone)
	var mult := b.storm_chance_mult if b else 1.0
	return clampf(c.eval(c.storm_base, c.storm_per_zone, c.storm_per_loop, zone, _loop(zone), 0.0, c.storm_max) * mult, 0.0, 0.95)


static func toll_price(zone: int) -> int:
	var c := curves
	return floori(c.eval(c.toll_base, c.toll_per_zone, c.toll_per_loop, zone, _loop(zone), 1.0, c.toll_max))


static func loot_mult(zone: int) -> float:
	var c := curves
	var b := BiomeDB.for_zone(zone)
	var bm := b.loot_mult if b else 1.0
	return c.eval(c.loot_base, c.loot_per_zone, c.loot_per_loop, zone, _loop(zone), c.loot_min, 2.0) * bm
