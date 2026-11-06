class_name Biome
extends Resource
## A biome: colour palette, module set, enemies, weather and hazards.

@export var id: String = ""
@export var display_name: String = ""

@export_group("Palette")
@export var ground_color: Color = Color(0.3, 0.35, 0.25)
@export var path_color: Color = Color(0.45, 0.4, 0.3)
@export var rock_color: Color = Color(0.45, 0.45, 0.45)
@export var foliage_color: Color = Color(0.2, 0.35, 0.2)
@export var trunk_color: Color = Color(0.3, 0.22, 0.15)
@export var accent_color: Color = Color(0.9, 0.7, 0.3)
@export var water_color: Color = Color(0.2, 0.35, 0.45, 0.65)
@export var fog_color: Color = Color(0.6, 0.65, 0.7)
@export var sky_top: Color = Color(0.35, 0.5, 0.7)
@export var sky_horizon: Color = Color(0.7, 0.75, 0.8)
@export var sun_color: Color = Color(1.0, 0.95, 0.85)
@export var sun_energy: float = 1.0
@export var fog_density: float = 0.012
@export var ambient_energy: float = 0.6

@export_group("Generation")
## Module scenes for this biome (each root has ZoneModule).
@export var modules: Array[String] = []
## The relay station module used at zone ends (and the road's start).
@export var station_module: String = ""
## Ground plane colour/height under the zone (hides gaps; none for void biomes).
@export var underlay: bool = true
## Edge blocking style: "cliff", "barrier", "ridge", "void", "dune"
@export var edge_style: String = "cliff"
## Enemy type -> relative weight for generic encounters ("hound", "scavenger", "rider", "watchtower", "tollkeeper").
@export var enemy_weights: Dictionary = {"hound": 1.0}
@export var loot_mult: float = 1.0

@export_group("Weather & hazards")
@export var storm_chance_mult: float = 1.0
## "rain" or "dust"
@export var storm_kind: String = "rain"
## "none", "flood", "void", "glare"
@export var hazard: String = "none"
## Wind gusts per minute even without a storm.
@export var ambient_gusts_per_min: float = 0.0
## Sun glare factor for Night-eyed couriers (and general exposure).
@export var glare: float = 1.0
