class_name ItemDef
extends Resource
## Definition of a carriable item. Create new items as .tres files and register them in ItemDB.PATHS.

enum Kind { MESSAGE, MELEE, CONSUMABLE, THROWABLE, MATERIAL }

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var kind: Kind = Kind.CONSUMABLE
## Carry slots one stack of this item occupies (0 = pouch item, costs no slot).
@export_range(0, 3) var weight: int = 1
@export_range(1, 99) var max_stack: int = 1
## Rough worth. Toll-keepers take the least valuable items first.
@export var value: int = 1
@export var droppable: bool = true
## HUD tint for the slot icon (placeholder art).
@export var color: Color = Color(0.8, 0.8, 0.8)

@export_group("Consumable")
@export var heal_amount: float = 0.0
@export var use_time: float = 0.0

@export_group("Melee")
@export var light_damage: float = 0.0
@export var charged_damage: float = 0.0
## Multiplier on swing speed (1 = normal).
@export var swing_speed: float = 1.0
@export var reach: float = 1.4

@export_group("Throwable")
## stone, noise, smoke, caltrops, fire
@export var throw_kind: String = ""
@export var throw_damage: float = 0.0

@export_group("Loot")
## Relative chance to appear in loot caches. 0 = never.
@export var loot_weight: float = 0.0
@export var loot_min: int = 1
@export var loot_max: int = 1
