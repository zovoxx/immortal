class_name ZoneLayout
extends RefCounted
## Pure-data description of a generated zone. Positions/transforms are zone-local
## (origin = the zone's entry socket); add `origin_world()` for global placement.

var zone_index: int = 0
var seed: int = 0
var biome_index: int = 0
var loop: int = 0
## Global grid cell of the zone's first module.
var start_cell: Vector2i = Vector2i.ZERO
## Local cell of the end station.
var end_cell: Vector2i = Vector2i.ZERO
var end_heading: Vector2i = Vector2i(0, 1)
## Each: {path, id, tags, cells: Array[Vector2i], heading, length, exit_dir, xform, entry_pos, exit_pos, info}
var modules: Array = []
## {index, xform, module}
var stations: Array = []
## {xform, module, name}
var shelters: Array = []
## {id, xform}
var loot: Array = []
## {type, xform, count, id, module}
var enemies: Array = []
var path_points: PackedVector3Array = PackedVector3Array()
var length_m: float = 0.0
var storm: bool = false
var storm_delay: float = 30.0


func origin_world() -> Vector3:
	return Vector3(start_cell.x * ZoneGenerator.CELL, 0.0, start_cell.y * ZoneGenerator.CELL)


func all_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for m in modules:
		for c in m.cells:
			out.append(c)
	return out


func global_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c in all_cells():
		out.append(c + start_cell)
	return out


func end_station() -> Dictionary:
	for s in stations:
		if int(s.index) == zone_index + 1:
			return s
	return {}


## A comparable fingerprint of the layout (for determinism tests).
func signature() -> String:
	var parts: PackedStringArray = []
	for m in modules:
		var x: Transform3D = m.xform
		parts.append("%s@%s/%.2f,%.2f,%.2f" % [m.id, str(m.cells[0]), x.origin.x, x.origin.z, x.basis.get_euler().y])
	for e in enemies:
		parts.append("%s:%d@%.1f,%.1f" % [e.type, e.count, e.xform.origin.x, e.xform.origin.z])
	for l in loot:
		parts.append("loot@%.1f,%.1f" % [l.xform.origin.x, l.xform.origin.z])
	return "|".join(parts)


## Distance along the path polyline of the point closest to `local_pos`.
func progress_of(local_pos: Vector3) -> float:
	var best := INF
	var best_prog := 0.0
	var acc := 0.0
	for i in range(1, path_points.size()):
		var a := path_points[i - 1]
		var b := path_points[i]
		var seg := b - a
		var len := seg.length()
		if len < 0.001:
			continue
		var t := clampf((local_pos - a).dot(seg) / (len * len), 0.0, 1.0)
		var p := a + seg * t
		var d := Vector2(p.x - local_pos.x, p.z - local_pos.z).length()
		if d < best:
			best = d
			best_prog = acc + len * t
		acc += len
	return best_prog


## Point on the path at distance `prog` and the path direction there.
func point_at(prog: float) -> Array:
	var acc := 0.0
	for i in range(1, path_points.size()):
		var a := path_points[i - 1]
		var b := path_points[i]
		var len := a.distance_to(b)
		if acc + len >= prog and len > 0.001:
			var t := (prog - acc) / len
			return [a.lerp(b, t), (b - a).normalized()]
		acc += len
	var n := path_points.size()
	if n >= 2:
		return [path_points[n - 1], (path_points[n - 1] - path_points[n - 2]).normalized()]
	return [Vector3.ZERO, Vector3.BACK]
