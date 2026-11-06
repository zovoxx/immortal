class_name ModuleKit
extends RefCounted
## Helpers for building zone module scenes with a biome palette.
## Module frame: entry at origin facing +Z, x in [-10, 10], z in [0, 20 * length].

const RELAY_STATION := "res://world/station/relay_station.tscn"

var b: Biome
var m: ZoneModule
var geo: Node3D
var slots: Node3D
var _hidden_count := 0


func _init(biome: Biome) -> void:
	b = biome


func begin(id: String, tags: Array, length: int, exit_dir: int, weight: float = 1.0, min_zone: int = 0) -> ZoneModule:
	m = ZoneModule.new()
	m.name = id.to_pascal_case()
	m.module_id = id
	m.tags = PackedStringArray(tags)
	m.length_cells = length
	m.exit_dir = exit_dir
	m.weight = weight
	m.min_zone = min_zone
	var entry := Marker3D.new()
	entry.name = "Entry"
	m.add_child(entry)
	var ex := Marker3D.new()
	ex.name = "Exit"
	ex.position = ZoneModule.exit_local_position(exit_dir, length)
	ex.rotation.y = ZoneModule.exit_yaw_delta(exit_dir)
	m.add_child(ex)
	geo = Node3D.new()
	geo.name = "Geometry"
	m.add_child(geo)
	slots = Node3D.new()
	slots.name = "Slots"
	m.add_child(slots)
	_hidden_count = 0
	return m


func length_m() -> float:
	return 20.0 * m.length_cells


# ----------------------------------------------------------------- basics

func floor_box(x0: float, x1: float, z0: float, z1: float, top: float = 0.0, color: Color = Color(), thick: float = 1.0, groups: Array = []) -> StaticBody3D:
	var c := color if color != Color() else b.ground_color
	return Geo.box(geo, Vector3((x0 + x1) * 0.5, top - thick * 0.5, (z0 + z1) * 0.5), Vector3(x1 - x0, thick, z1 - z0), c, groups)


## Full floor for the module (or a turn cell).
func full_floor() -> void:
	floor_box(-10, 10, 0, length_m())


func path_strip(points: Array, width: float = 3.5) -> void:
	for i in range(1, points.size()):
		var a: Vector3 = points[i - 1]
		var c: Vector3 = points[i]
		var mid := (a + c) * 0.5
		var d := c - a
		var mi := Geo.deco_box(geo, Vector3(mid.x, 0.015, mid.z), Vector3(width, 0.03, d.length() + width * 0.5), b.path_color)
		mi.rotation.y = atan2(d.x, d.z)


func slot(slot_name: String, pos: Vector3, yaw: float = 0.0) -> Marker3D:
	var s := Marker3D.new()
	s.name = slot_name
	s.position = pos
	s.rotation.y = yaw
	slots.add_child(s)
	return s


func tree(pos: Vector3, scale: float = 1.0) -> void:
	Geo.tree(geo, pos, b.trunk_color, b.foliage_color, scale)


func rock(pos: Vector3, size: Vector3, climbable: bool = false, yaw: float = 0.0) -> StaticBody3D:
	var groups := ["climbable", "surface_stone"] if climbable else ["surface_stone"]
	return Geo.box(geo, pos + Vector3(0, size.y * 0.5, 0), size, b.rock_color.darkened(randf_range(0.0, 0.12)), groups, null, yaw)


func block(pos: Vector3, size: Vector3, color: Color, groups: Array = [], yaw: float = 0.0) -> StaticBody3D:
	return Geo.box(geo, pos + Vector3(0, size.y * 0.5, 0), size, color, groups, null, yaw)


func log_obstacle(pos: Vector3, length: float, yaw: float = PI * 0.5, height: float = 0.7) -> void:
	Geo.box(geo, pos + Vector3(0, height * 0.5, 0), Vector3(height, height, length), b.trunk_color, ["surface_wood"], null, yaw)


func water(pos: Vector3, size: Vector2, base_depth: float = 0.6, flood_depth: float = 2.4) -> WaterVolume:
	var w := WaterVolume.new()
	w.name = "Water%d" % geo.get_child_count()
	w.size = Vector3(size.x, base_depth, size.y)
	w.base_depth = base_depth
	w.flood_depth = flood_depth
	w.color = b.water_color
	w.position = pos
	geo.add_child(w)
	return w


func grass(pos: Vector3, size: Vector2, density: int = 30) -> void:
	var v := VolumeArea.new()
	v.name = "TallGrass%d" % geo.get_child_count()
	v.kind = "tall_grass"
	v.size = Vector3(size.x, 1.5, size.y)
	v.position = pos
	geo.add_child(v)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(pos)
	var c := b.foliage_color.lightened(0.25)
	for i in density:
		var p := pos + Vector3(rng.randf_range(-size.x * 0.5, size.x * 0.5), 0.6, rng.randf_range(-size.y * 0.5, size.y * 0.5))
		Geo.deco_box(geo, p, Vector3(0.1, 1.2 + rng.randf() * 0.4, 0.1), c, null, Vector3(rng.randf_range(-0.2, 0.2), 0, rng.randf_range(-0.2, 0.2)))


func shelter_volume(pos: Vector3, size: Vector3) -> void:
	var v := VolumeArea.new()
	v.name = "ShelterArea%d" % geo.get_child_count()
	v.kind = "shelter"
	v.size = size
	v.position = pos
	geo.add_child(v)
	slot("Shelter%d" % slots.get_child_count(), pos)


## Rock overhang shelter (two pillars + slab).
func overhang(pos: Vector3, yaw: float = 0.0) -> void:
	var holder := Node3D.new()
	holder.name = "Overhang%d" % geo.get_child_count()
	holder.position = pos
	holder.rotation.y = yaw
	geo.add_child(holder)
	Geo.box(holder, Vector3(-2.6, 1.6, 0), Vector3(1.0, 3.2, 3.6), b.rock_color, ["surface_stone"])
	Geo.box(holder, Vector3(2.6, 1.6, 0), Vector3(1.0, 3.2, 3.6), b.rock_color, ["surface_stone"])
	Geo.box(holder, Vector3(0, 3.5, 0.4), Vector3(6.6, 0.6, 4.6), b.rock_color.darkened(0.1), ["climbable", "surface_stone"])
	Geo.box(holder, Vector3(0, 1.6, 1.9), Vector3(6.2, 3.2, 0.6), b.rock_color.darkened(0.05), ["surface_stone"])
	var v := VolumeArea.new()
	v.kind = "shelter"
	v.size = Vector3(4.2, 3.0, 3.4)
	holder.add_child(v)
	slot("Shelter%d" % slots.get_child_count(), pos)


## Ruined hut shelter (walls on three sides, roof).
func hut(pos: Vector3, yaw: float = 0.0, wall_color: Color = Color()) -> void:
	var wc := wall_color if wall_color != Color() else b.rock_color
	var holder := Node3D.new()
	holder.name = "Hut%d" % geo.get_child_count()
	holder.position = pos
	holder.rotation.y = yaw
	geo.add_child(holder)
	Geo.box(holder, Vector3(0, 1.5, 2.3), Vector3(5, 3, 0.4), wc, ["climbable"])
	Geo.box(holder, Vector3(2.3, 1.5, 0), Vector3(0.4, 3, 5), wc)
	Geo.box(holder, Vector3(-2.3, 1.5, 0.9), Vector3(0.4, 3, 2.8), wc)
	Geo.box(holder, Vector3(0, 3.15, 0.2), Vector3(5.4, 0.3, 5.4), b.trunk_color, ["surface_wood"])
	var v := VolumeArea.new()
	v.kind = "shelter"
	v.size = Vector3(4.0, 2.9, 4.2)
	holder.add_child(v)
	slot("Shelter%d" % slots.get_child_count(), pos)


func hidden() -> HiddenPath:
	var h := HiddenPath.new()
	_hidden_count += 1
	h.name = "HiddenPath%d" % _hidden_count
	geo.add_child(h)
	return h


## Glowing marks that hint at a hidden path (only visible with it).
func hidden_marks(h: HiddenPath, points: Array) -> void:
	for p in points:
		var mi := Geo.deco_box(h, p, Vector3(0.15, 0.15, 0.15), b.accent_color)
		mi.material_override = Geo.mat(b.accent_color, 0.5, 2.5)


func label(pos: Vector3, text: String) -> void:
	Geo.label(geo, pos, text, 48)


func station() -> void:
	var st: Node3D = (load(RELAY_STATION) as PackedScene).instantiate()
	st.name = "RelayStation"
	st.position = Vector3(0, 0, 10)
	m.add_child(st)
	slot("Station", Vector3(0, 0, 10))
