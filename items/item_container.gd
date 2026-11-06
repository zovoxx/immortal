class_name ItemContainer
extends RefCounted
## Anything the loot window can show: corpses, loot caches, scavenger bags, the station stash.

var title: String = ""
var inventory: CarryInventory
## Can the courier put items into it (stash only)?
var allow_put: bool = false
var on_changed: Callable = Callable()


func _init(t: String, inv: CarryInventory, can_put: bool = false) -> void:
	title = t
	inventory = inv
	allow_put = can_put


func changed() -> void:
	if on_changed.is_valid():
		on_changed.call()
