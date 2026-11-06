class_name NoiseMakerEffect
extends Node3D
## A rattling clay ball: emits loud "noise_maker" sounds for a few seconds. Enemies investigate.

@export var radius: float = 26.0
@export var duration: float = 5.0
@export var interval: float = 1.0
var _t: float = 0.0
var _next: float = 0.0


func _ready() -> void:
	add_to_group("noise_source")
	Geo.deco_sphere(self, Vector3(0, 0.15, 0), 0.16, Color(0.9, 0.6, 0.2))


func _physics_process(delta: float) -> void:
	_t += delta
	_next -= delta
	if _next <= 0.0:
		_next = interval
		Events.sound_emitted.emit(global_position, radius, "noise_maker")
		Audio.play_at("rattle", global_position, 0.0, 50.0)
	if _t >= duration:
		queue_free()
