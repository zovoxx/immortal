class_name HiddenPath
extends Node3D
## Container for a hidden shortcut (planks, handholds, stepping stones). It only exists (visible
## and solid) when the courier is Old or has Fast Courier momentum.

var revealed: bool = true
var _layers: Dictionary = {}


func _ready() -> void:
	add_to_group("hidden_path")
	set_revealed(Game.reveals_hidden_paths())


func set_revealed(on: bool) -> void:
	revealed = on
	visible = on
	for c in find_children("*", "CollisionObject3D", true, false):
		var co := c as CollisionObject3D
		if not _layers.has(co):
			_layers[co] = co.collision_layer
		co.collision_layer = _layers[co] if on else 0
