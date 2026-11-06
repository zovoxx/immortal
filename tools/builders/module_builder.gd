extends RefCounted
## Builds every biome's zone modules into res://world/modules/<biome>/ and writes the module lists
## into the biome resources.

const BC := preload("res://tools/build_content.gd")

const BIOME_BUILDERS := {
	"res://world/biomes/greywood_forest.tres": "res://tools/builders/biome_greywood.gd",
	"res://world/biomes/ruined_highway.tres": "res://tools/builders/biome_highway.gd",
	"res://world/biomes/storm_plains.tres": "res://tools/builders/biome_plains.gd",
	"res://world/biomes/floating_ruins.tres": "res://tools/builders/biome_floating.gd",
	"res://world/biomes/salt_desert.tres": "res://tools/builders/biome_desert.gd",
}


func build_all() -> int:
	seed(12345)
	var n := 0
	for biome_path in BIOME_BUILDERS:
		if not ResourceLoader.exists(biome_path) or not ResourceLoader.exists(BIOME_BUILDERS[biome_path]):
			continue
		var biome: Biome = load(biome_path)
		var builder: Object = load(BIOME_BUILDERS[biome_path]).new()
		var kit := ModuleKit.new(biome)
		var paths: Array[String] = []
		var station_path := ""
		for mod: ZoneModule in builder.modules(kit):
			var path := "res://world/modules/%s/%s.tscn" % [biome.id, mod.module_id]
			var is_station := mod.tags.has("station")
			if BC.save_scene(mod, path):
				n += 1
				if is_station:
					station_path = path
				else:
					paths.append(path)
		biome.modules = paths
		biome.station_module = station_path
		ResourceSaver.save(biome, biome_path)
		print("  %s: %d modules + station" % [biome.id, paths.size()])
	return n
