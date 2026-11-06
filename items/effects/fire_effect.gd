class_name FireEffect
extends Node3D
## Fire pot burst: damage on impact, then burning ground for a few seconds.

@export var radius: float = 3.0
@export var duration: float = 4.0
@export var burn_dps: float = 8.0
var burst_damage: float = 40.0
var thrower: Node3D
var _t: float = 0.0
var _light: OmniLight3D


func _ready() -> void:
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.5, 0.2)
	_light.omni_range = radius * 3.0
	_light.light_energy = 4.0
	_light.position.y = 1.0
	add_child(_light)
	var p := CPUParticles3D.new()
	p.amount = 40
	p.lifetime = 0.8
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = radius * 0.7
	p.direction = Vector3.UP
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 3.0
	p.gravity = Vector3(0, 2, 0)
	var bm := BoxMesh.new()
	bm.size = Vector3(0.3, 0.3, 0.3)
	p.mesh = bm
	p.material_override = Geo.mat(Color(1.0, 0.5, 0.1), 1.0, 4.0)
	add_child(p)
	Audio.play_at("fire", global_position, 2.0)
	Events.sound_emitted.emit(global_position, 18.0, "combat")
	_damage_all(burst_damage)


func _damage_all(amount: float) -> void:
	for n in get_tree().get_nodes_in_group("enemy"):
		var e := n as Enemy
		if e and not e.is_dead() and e.global_position.distance_to(global_position) < radius:
			e.take_damage(amount, global_position, "fire")
	var c := Perception.courier()
	if c and c.global_position.distance_to(global_position) < radius * 0.8:
		c.take_damage(amount * 0.5, "burned by their own fire pot")


func _physics_process(delta: float) -> void:
	_t += delta
	_light.light_energy = 4.0 * clampf(duration - _t, 0.0, 1.0)
	for n in get_tree().get_nodes_in_group("enemy"):
		var e := n as Enemy
		if e and not e.is_dead() and e.global_position.distance_to(global_position) < radius:
			e.hp -= burn_dps * delta
			if e.hp <= 0.0:
				e.die()
	if _t >= duration:
		queue_free()
