class_name StormFront
extends Node3D
## The visible edge of a storm: a dark curtain placed across the road at the front's position.

const MODEL := preload("res://world/weather/storm_front_model.tscn")

var model: Node3D


func _ready() -> void:
	model = MODEL.instantiate()
	add_child(model)


func place(pos: Vector3, dir: Vector3, dust: bool) -> void:
	global_position = Vector3(pos.x, 0.0, pos.z)
	if dir.length_squared() > 0.001:
		rotation.y = atan2(dir.x, dir.z)
	var wall := model.get_node_or_null("Wall") as MeshInstance3D
	if wall and wall.material_override:
		var m := wall.material_override as StandardMaterial3D
		m.albedo_color = Color(0.6, 0.48, 0.32, 0.6) if dust else Color(0.12, 0.13, 0.17, 0.55)
