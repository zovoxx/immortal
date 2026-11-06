class_name DifficultyCurves
extends Resource
## Difficulty as a function of zone index. Each value = base + per_zone * zone + per_loop * loop,
## clamped to [min, max]. "loop" is the Long Road +N counter (every 5 biomes).
## Edit res://world/zone_gen/difficulty_curves.tres.

@export_group("Enemy groups per zone")
@export var groups_base: float = 1.2
@export var groups_per_zone: float = 0.07
@export var groups_per_loop: float = 1.0
@export var groups_max: float = 7.0

@export_group("Enemy HP multiplier")
@export var hp_base: float = 1.0
@export var hp_per_zone: float = 0.015
@export var hp_per_loop: float = 0.35
@export var hp_max: float = 4.0

@export_group("Enemy damage multiplier")
@export var damage_base: float = 1.0
@export var damage_per_zone: float = 0.008
@export var damage_per_loop: float = 0.2
@export var damage_max: float = 2.5

@export_group("Storm chance per zone")
@export var storm_base: float = 0.12
@export var storm_per_zone: float = 0.008
@export var storm_per_loop: float = 0.12
@export var storm_max: float = 0.85

@export_group("Toll price (items)")
@export var toll_base: float = 1.0
@export var toll_per_zone: float = 0.06
@export var toll_per_loop: float = 1.0
@export var toll_max: float = 5.0

@export_group("Loot multiplier")
@export var loot_base: float = 1.0
@export var loot_per_zone: float = -0.004
@export var loot_per_loop: float = -0.15
@export var loot_min: float = 0.45


func eval(base: float, per_zone: float, per_loop: float, zone: int, loop: int, lo: float, hi: float) -> float:
	return clampf(base + per_zone * zone + per_loop * loop, lo, hi)
