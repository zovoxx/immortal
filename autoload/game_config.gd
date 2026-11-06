class_name GameConfig
extends Resource
## Global tunables for the run. Edit res://autoload/game_config.tres.

@export_group("Courier")
@export var base_hp: float = 100.0
@export var base_stamina: float = 100.0
@export var base_carry_slots: int = 4
## Movement penalty per carry slot used beyond `free_load_slots`.
@export var load_penalty_per_slot: float = 0.05
@export var free_load_slots: int = 2
## Basic kit for every new courier (id -> count). The Message is always added.
@export var starting_kit: Dictionary = {"short_blade": 1, "bandage": 1, "sling_stones": 3}

@export_group("Corpses & scavengers")
@export var max_corpses: int = 30
@export var scavenger_steal_interval: float = 45.0

@export_group("Stations & upgrades")
@export var stash_slots: int = 6
@export var bed_hp_bonus: float = 20.0
## Upgrade id -> material cost dictionary.
@export var upgrade_costs: Dictionary = {
	"bed": {"cloth": 3, "scrap": 1},
	"forge": {"scrap": 5, "oil": 2},
	"kennel": {"feathers": 3, "cloth": 2},
	"mirror": {"scrap": 2, "oil": 1, "feathers": 1},
}
## Upgrades that are unlocked forever once built (others are per station).
@export var global_upgrades: Array[String] = ["forge", "kennel"]
## Price of a kennel noise-maker (once per courier life).
@export var kennel_price: Dictionary = {"feathers": 1}
## In-game hours (fraction of a day) that resting at a station costs.
@export var rest_time_cost: float = 0.12

@export_group("Momentum")
@export var momentum_max: int = 5
@export var momentum_speed_level: int = 2
@export var momentum_speed_bonus: float = 0.05
@export var momentum_loot_level: int = 3
@export var momentum_loot_luck: float = 0.4
@export var momentum_fast_level: int = 5
## Par time per zone for the Fast Courier time bonus (seconds).
@export var fast_courier_par_time: float = 150.0

@export_group("World")
@export var zones_per_biome: int = 10
@export var day_length_seconds: float = 720.0
@export var start_time_of_day: float = 0.32
@export var fragment_every_zones: int = 25
@export var fragment_count: int = 8
