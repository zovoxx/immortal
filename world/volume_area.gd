class_name VolumeArea
extends Area3D
## A trigger box that tells the courier (and enemies) they are inside a volume of `kind`:
## "tall_grass", "shelter", "water", "station", "kill", "hidden_reveal".

@export var kind: String = "shelter"
@export var size: Vector3 = Vector3(4, 3, 4):
	set(v):
		size = v
		if is_inside_tree():
			_update_shape()
## For "kill" volumes: cause of death.
@export var cause: String = "fell into the void"

var _shape: CollisionShape3D


func _ready() -> void:
	collision_layer = Geo.LAYER_TRIGGER
	collision_mask = Geo.LAYER_PLAYER | Geo.LAYER_ENEMY
	monitoring = true
	monitorable = true
	add_to_group(kind)
	add_to_group("volume")
	_update_shape()
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)


func _update_shape() -> void:
	if _shape == null:
		for c in get_children():
			if c is CollisionShape3D:
				_shape = c
		if _shape == null:
			_shape = CollisionShape3D.new()
			add_child(_shape)
	var b := BoxShape3D.new()
	b.size = size
	_shape.shape = b
	_shape.position = Vector3(0, size.y * 0.5, 0)


func _on_enter(body: Node3D) -> void:
	if body.has_method("enter_volume"):
		body.enter_volume(kind, self)
	if kind == "kill" and body.has_method("die"):
		body.die(cause)


func _on_exit(body: Node3D) -> void:
	if body.has_method("exit_volume"):
		body.exit_volume(kind, self)


## Local-space AABB test (position is the bottom centre of the box).
func contains_point(p: Vector3) -> bool:
	var l := to_local(p)
	return absf(l.x) <= size.x * 0.5 and absf(l.z) <= size.z * 0.5 and l.y >= 0.0 and l.y <= size.y
