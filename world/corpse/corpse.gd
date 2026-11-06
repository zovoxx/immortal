class_name Corpse
extends Interactable
## A fallen courier's body in the world, backed by a CorpseData record in Game.corpses.

const MODEL := preload("res://world/corpse/corpse_model.tscn")

var data: CorpseData
var container: ItemContainer


func _enter_tree() -> void:
	super._enter_tree()
	add_to_group("corpse")


func _ready() -> void:
	var m := MODEL.instantiate()
	add_child(m)
	rotation.y = data.yaw if data else 0.0
	var flag := m.get_node_or_null("Flag") as MeshInstance3D
	if flag and data:
		var hue := fposmod(float(data.courier_index) * 0.137, 1.0)
		flag.material_override = Geo.mat(Color.from_hsv(hue, 0.7, 0.85), 0.8, 0.5)
	if data:
		container = ItemContainer.new("Remains of %s" % data.courier_name, data.inventory)
		container.on_changed = func(): Events.inventory_changed.emit()


func get_prompt(_courier: Node) -> String:
	if data == null:
		return ""
	return "Search remains of %s%s" % [data.courier_name, "" if data.item_count() > 0 else " (empty)"]


func interact(_courier: Node) -> void:
	if container:
		Events.open_container.emit(container, container.title)


func corpse_id() -> int:
	return data.id if data else -1


func has_loot() -> bool:
	return data != null and data.item_count() > 0 and Game.get_corpse(data.id) != null
