class_name SmokeCloud
extends Node3D
## Thick smoke: blocks enemy line of sight through it (see Perception.smoke_blocks).

@export var radius: float = 4.5
@export var duration: float = 12.0
var _t: float = 0.0
var _puffs: Array[MeshInstance3D] = []


func _ready() -> void:
	add_to_group("smoke")
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.75, 0.75, 0.78, 0.55)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for i in 9:
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = rng.randf_range(1.6, 2.6)
		sm.height = sm.radius * 2.0
		sm.radial_segments = 10
		sm.rings = 5
		mi.mesh = sm
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(rng.randf_range(-2, 2), rng.randf_range(0.0, 2.0), rng.randf_range(-2, 2))
		add_child(mi)
		_puffs.append(mi)
	Audio.play_at("slide", global_position, -2.0)


func _process(delta: float) -> void:
	_t += delta
	var k := clampf(minf(_t / 0.6, (duration - _t) / 2.0), 0.0, 1.0)
	for p in _puffs:
		p.scale = Vector3.ONE * maxf(k, 0.01)
	if _t >= duration:
		queue_free()
