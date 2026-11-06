class_name CaltropsEffect
extends Node3D
## Scattered spikes: hunters crossing them are slowed and hurt.

@export var radius: float = 2.6
@export var duration: float = 30.0
@export var slow_mult: float = 0.35
@export var slow_time: float = 3.0
var damage: float = 4.0
var _t: float = 0.0
var _hurt: Dictionary = {}


func _ready() -> void:
	add_to_group("caltrops")
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in 14:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * radius
		Geo.deco_box(self, Vector3(cos(a) * r, 0.05, sin(a) * r), Vector3(0.12, 0.1, 0.12), Color(0.35, 0.35, 0.4), null, Vector3(rng.randf(), rng.randf(), 0))


func _physics_process(delta: float) -> void:
	_t += delta
	for n in get_tree().get_nodes_in_group("enemy"):
		var e := n as Enemy
		if e == null or e.is_dead() or not e.is_hunter:
			continue
		var d := e.global_position - global_position
		d.y = 0
		if d.length() < radius:
			e.speed_mult = slow_mult
			e.set_meta("caltrop_until", Time.get_ticks_msec() + int(slow_time * 1000.0))
			if not _hurt.has(e):
				_hurt[e] = true
				e.take_damage(damage, global_position, "caltrops")
		elif e.has_meta("caltrop_until") and Time.get_ticks_msec() > int(e.get_meta("caltrop_until")):
			e.speed_mult = 1.0
			e.remove_meta("caltrop_until")
	if _t >= duration:
		for n in get_tree().get_nodes_in_group("enemy"):
			if n is Enemy and n.has_meta("caltrop_until"):
				(n as Enemy).speed_mult = 1.0
		queue_free()
