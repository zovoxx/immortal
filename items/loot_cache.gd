class_name LootCache
extends Interactable
## A supply cache in a zone. Contents roll when first opened (seeded by zone + cache id, luck and
## difficulty), and stay in the cache until it's unloaded. Looted caches stay empty on reload.

const MODEL := preload("res://items/loot_cache_model.tscn")

@export var zone_index: int = 0
@export var cache_id: String = "cache"
@export var rolls: int = 3

var container: ItemContainer


func _ready() -> void:
	add_child(MODEL.instantiate())


func _ensure_container() -> void:
	if container:
		return
	var inv := CarryInventory.new(99)
	if not Game.is_cache_looted(zone_index, cache_id):
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("%d:%d:%s" % [Game.world_seed, zone_index, cache_id])
		var n := maxi(1, roundi(float(rolls) * Difficulty.loot_mult(zone_index)))
		for e in ItemDB.roll_loot(rng, n, Game.loot_luck()):
			inv.add(e.id, e.count, true)
	container = ItemContainer.new("Supply cache", inv)
	container.on_changed = func(): Game.mark_cache_looted(zone_index, cache_id)


func get_prompt(_courier: Node) -> String:
	_ensure_container()
	return "Search supply cache" + ("" if not container.inventory.entries.is_empty() else " (empty)")


func interact(_courier: Node) -> void:
	_ensure_container()
	Events.open_container.emit(container, container.title)
