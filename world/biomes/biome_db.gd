class_name BiomeDB
extends RefCounted
## The five biomes of the Long Road, in order. Each lasts Game.config.zones_per_biome zones, then loops.

const PATHS: Array[String] = [
	"res://world/biomes/greywood_forest.tres",
	"res://world/biomes/ruined_highway.tres",
	"res://world/biomes/storm_plains.tres",
	"res://world/biomes/floating_ruins.tres",
	"res://world/biomes/salt_desert.tres",
]

static var _biomes: Array = []


static func _ensure() -> void:
	if not _biomes.is_empty():
		return
	for p in PATHS:
		var b: Biome = load(p) as Biome if ResourceLoader.exists(p) else null
		_biomes.append(b)


static func get_biome(index: int) -> Biome:
	_ensure()
	var b: Biome = _biomes[clampi(index, 0, _biomes.size() - 1)]
	if b == null:
		b = _biomes[0]
	return b


static func for_zone(zone_index: int) -> Biome:
	return get_biome(Game.biome_index(zone_index))


static func count() -> int:
	return PATHS.size()
