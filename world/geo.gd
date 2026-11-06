class_name Geo
extends RefCounted
## Helpers to build placeholder geometry from primitives (boxes, cylinders, ramps) with colliders.

const LAYER_WORLD := 1
const LAYER_PLAYER := 2
const LAYER_ENEMY := 4
const LAYER_TRIGGER := 8
const LAYER_HITBOX := 16

static var _materials: Dictionary = {}


static func mat(color: Color, roughness: float = 0.9, emission: float = 0.0) -> StandardMaterial3D:
	var key := "%s_%.2f_%.2f" % [color.to_html(), roughness, emission]
	if _materials.has(key):
		return _materials[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	if color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	_materials[key] = m
	return m


static func _own(n: Node, owner: Node) -> void:
	if owner and owner != n:
		n.owner = owner


## Solid box: StaticBody3D + mesh + collider. pos is the box centre.
static func box(parent: Node, pos: Vector3, size: Vector3, color: Color, groups: Array = [], owner: Node = null, rot_y: float = 0.0, node_name: String = "") -> StaticBody3D:
	var body := StaticBody3D.new()
	if node_name != "":
		body.name = node_name
	body.collision_layer = LAYER_WORLD
	body.collision_mask = 0
	parent.add_child(body)
	_own(body, owner)
	body.position = pos
	body.rotation.y = rot_y
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat(color)
	body.add_child(mi)
	_own(mi, owner)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	_own(cs, owner)
	for g in groups:
		body.add_to_group(g, true)
	return body


## Visual-only box (no collider).
static func deco_box(parent: Node, pos: Vector3, size: Vector3, color: Color, owner: Node = null, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat(color)
	parent.add_child(mi)
	_own(mi, owner)
	mi.position = pos
	mi.rotation = rot
	return mi


## Solid cylinder (trunks, pillars).
static func cylinder(parent: Node, pos: Vector3, radius: float, height: float, color: Color, groups: Array = [], owner: Node = null) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = LAYER_WORLD
	body.collision_mask = 0
	parent.add_child(body)
	_own(body, owner)
	body.position = pos
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	cm.radial_segments = 8
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = mat(color)
	body.add_child(mi)
	_own(mi, owner)
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	cs.shape = shape
	body.add_child(cs)
	_own(cs, owner)
	for g in groups:
		body.add_to_group(g, true)
	return body


static func deco_sphere(parent: Node, pos: Vector3, radius: float, color: Color, owner: Node = null, squash: float = 1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0 * squash
	sm.radial_segments = 10
	sm.rings = 5
	mi.mesh = sm
	mi.material_override = mat(color)
	parent.add_child(mi)
	_own(mi, owner)
	mi.position = pos
	return mi


static func deco_cone(parent: Node, pos: Vector3, radius: float, height: float, color: Color, owner: Node = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = radius
	cm.height = height
	cm.radial_segments = 7
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = mat(color)
	parent.add_child(mi)
	_own(mi, owner)
	mi.position = pos
	return mi


## Ramp rising along +Z of its own frame from height 0 to `height` over `length`.
static func ramp(parent: Node, pos: Vector3, width: float, length: float, height: float, color: Color, owner: Node = null, rot_y: float = 0.0) -> StaticBody3D:
	var slope := sqrt(length * length + height * height)
	var angle := atan2(height, length)
	var holder := StaticBody3D.new()
	holder.collision_layer = LAYER_WORLD
	holder.collision_mask = 0
	parent.add_child(holder)
	_own(holder, owner)
	holder.position = pos
	holder.rotation.y = rot_y
	var thick := 0.3
	var center := Vector3(0, height * 0.5 - thick * 0.5 * cos(angle), length * 0.5)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(width, thick, slope)
	mi.mesh = bm
	mi.material_override = mat(color)
	mi.position = center
	mi.rotation.x = -angle
	holder.add_child(mi)
	_own(mi, owner)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = bm.size
	cs.shape = shape
	cs.position = center
	cs.rotation.x = -angle
	holder.add_child(cs)
	_own(cs, owner)
	return holder


## A simple tree: trunk collider + cone foliage.
static func tree(parent: Node, pos: Vector3, trunk_color: Color, leaf_color: Color, scale: float = 1.0, owner: Node = null) -> StaticBody3D:
	var t := cylinder(parent, pos + Vector3(0, 2.0 * scale, 0), 0.3 * scale, 4.0 * scale, trunk_color, ["tree"], owner)
	deco_cone(t, Vector3(0, 2.2 * scale, 0), 1.8 * scale, 3.6 * scale, leaf_color, owner)
	deco_cone(t, Vector3(0, 3.6 * scale, 0), 1.3 * scale, 2.6 * scale, leaf_color.lightened(0.08), owner)
	return t


static func label(parent: Node, pos: Vector3, text: String, size: int = 64, owner: Node = null) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.01
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.outline_size = 12
	parent.add_child(l)
	_own(l, owner)
	l.position = pos
	return l
