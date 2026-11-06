class_name Pickup
extends Interactable
## An item lying in the world. Interact to put it in the carry slots.

const MODEL := preload("res://items/pickup_model.tscn")

@export var item_id: String = "bandage"
@export var count: int = 1

var _model: Node3D
var _t: float = 0.0


func _ready() -> void:
	_model = MODEL.instantiate()
	add_child(_model)
	var d := ItemDB.get_def(item_id)
	if d:
		var mesh := _model.get_node_or_null("Mesh") as MeshInstance3D
		if mesh:
			mesh.material_override = Geo.mat(d.color, 0.6, 0.4)
	_t = randf() * TAU


func _process(delta: float) -> void:
	_t += delta
	_model.position.y = 0.1 + sin(_t * 2.0) * 0.08
	_model.rotation.y += delta


func get_prompt(_courier: Node) -> String:
	return "Take %s%s" % [ItemDB.display_name(item_id), (" x%d" % count) if count > 1 else ""]


func interact(_courier: Node) -> void:
	var inv := Game.courier.inventory
	var added := inv.add(item_id, count)
	if added <= 0:
		Events.notify.emit("No free carry slot for %s" % ItemDB.display_name(item_id))
		return
	count -= added
	Audio.play("pickup", -6.0)
	Events.inventory_changed.emit()
	if count <= 0:
		queue_free()
