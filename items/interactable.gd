class_name Interactable
extends Node3D
## Base for things the courier can interact with. Override get_prompt() and interact().
## Lives in group "interactable"; CourierActions picks the nearest one in reach.

@export var interact_radius: float = 2.2


func _enter_tree() -> void:
	add_to_group("interactable")


## Text shown in the HUD ("" = can't interact now).
func get_prompt(_courier: Node) -> String:
	return ""


func interact(_courier: Node) -> void:
	pass
