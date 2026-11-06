class_name CourierTrait
extends Resource
## A courier trait. Multipliers default to 1 (no effect), additive values to 0.
## Add a new trait by creating a .tres with this script and listing it in TraitDB.PATHS.

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
## Traits sharing an exclusive group never roll together (e.g. "speed").
@export var exclusive_group: String = ""

@export_group("Body")
@export var speed_mult: float = 1.0
@export var hp_mult: float = 1.0
@export var hp_add: float = 0.0
@export var stamina_mult: float = 1.0
@export var climb_speed_mult: float = 1.0
@export var carry_slots_add: int = 0

@export_group("Combat")
@export var melee_damage_mult: float = 1.0
@export var extra_weapon: String = ""

@export_group("Perception")
## Multiplier on enemy detection range against this courier.
@export var enemy_detect_range_mult: float = 1.0
## Seconds enemies hesitate before their first attack.
@export var enemy_attack_hesitation: float = 0.0
## Multiplier on how well hounds track this courier's scent.
@export var scent_mult: float = 1.0
## Multiplier on footstep noise radius.
@export var footstep_noise_mult: float = 1.0

@export_group("Senses & luck")
@export var night_vision: bool = false
@export var sun_glare: bool = false
@export var reveals_hidden_paths: bool = false
## Added to loot luck (0 = normal).
@export var loot_luck: float = 0.0
