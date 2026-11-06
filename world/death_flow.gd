class_name DeathFlow
extends Node
## Handles a courier's death: slow-motion, death card, corpse record + body, respawn as a new courier.
## The owning world must implement:
##   zone_of_position(pos) -> int, to_zone_local(zone, pos) -> Vector3,
##   spawn_corpse_node(CorpseData) -> void, respawn_courier() -> void

@export var slowmo_scale: float = 0.25
@export var slowmo_seconds: float = 1.4

var world: Node
var death_card: Node
var busy: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	death_card = preload("res://ui/death_card.tscn").instantiate()
	add_child(death_card)
	Events.courier_died.connect(_on_died)


func _on_died(cause: String) -> void:
	if busy:
		return
	busy = true
	var courier := get_tree().get_first_node_in_group("player") as Courier
	var pos := courier.global_position if courier else Vector3.ZERO
	var yaw: float = courier.model.rotation.y if courier else 0.0
	var data := Game.courier
	var zone: int = world.zone_of_position(pos)
	var lived := data.lived_seconds if data else 0.0
	var cname := data.full_name if data else "The courier"
	var corpse := Game.handle_death(cause, zone, world.to_zone_local(zone, pos), yaw)
	if corpse:
		world.spawn_corpse_node(corpse)
	Save.save_game()
	Engine.time_scale = slowmo_scale
	death_card.show_death(cname, zone, cause, lived, Game.last_station)
	await get_tree().create_timer(slowmo_seconds, true, false, true).timeout
	Engine.time_scale = 1.0
	await death_card.continued
	Game.respawn()
	world.respawn_courier()
	Save.save_game()
	death_card.hide_card()
	Events.courier_respawned.emit()
	busy = false
