class_name LootBag
extends Interactable
## A sack dropped by a dead scavenger with everything it stole.

const MODEL := preload("res://items/loot_bag_model.tscn")

var container: ItemContainer


func _ready() -> void:
	add_child(MODEL.instantiate())
	if container == null:
		container = ItemContainer.new("Scavenger's sack", CarryInventory.new(99))


func set_items(items: Array) -> void:
	container = ItemContainer.new("Scavenger's sack", CarryInventory.new(99))
	for e in items:
		container.inventory.add(e.id, e.count, true)


func get_prompt(_courier: Node) -> String:
	return "Open scavenger's sack" + ("" if not container.inventory.entries.is_empty() else " (empty)")


func interact(_courier: Node) -> void:
	Events.open_container.emit(container, container.title)
