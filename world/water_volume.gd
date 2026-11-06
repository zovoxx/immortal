class_name WaterVolume
extends VolumeArea
## Water: slows the courier, erases scent points inside it, can rise during flash floods.

@export var base_depth: float = 0.6
@export var flood_depth: float = 2.4
@export var color: Color = Color(0.2, 0.35, 0.45, 0.65)

var depth: float = 0.6
var _mesh: MeshInstance3D
var _target_depth: float = 0.6


func _ready() -> void:
	kind = "water"
	depth = base_depth
	_target_depth = base_depth
	size = Vector3(size.x, depth, size.z)
	super._ready()
	_mesh = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1, 1, 1)
	_mesh.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.1
	m.metallic = 0.3
	_mesh.material_override = m
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)
	_apply()


func _process(delta: float) -> void:
	if not is_equal_approx(depth, _target_depth):
		depth = move_toward(depth, _target_depth, delta * 0.35)
		_apply()


func _apply() -> void:
	size = Vector3(size.x, maxf(depth, 0.05), size.z)
	if _mesh:
		_mesh.scale = Vector3(size.x, maxf(depth, 0.05), size.z)
		_mesh.position = Vector3(0, depth * 0.5, 0)


func surface_y() -> float:
	return global_position.y + depth


func set_flooded(on: bool) -> void:
	_target_depth = flood_depth if on else base_depth
