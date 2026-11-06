class_name ModuleLibrary
extends RefCounted
## Reads module metadata (tags, size, exit, sockets, slots) from module scenes once and caches it.

static var _cache: Dictionary = {}


## Returns {path, id, tags, length, exit_dir, weight, min_zone, entry: Transform3D, exit: Transform3D,
##          slots: Array[{name, kind, xform: Transform3D}]}
static func info(path: String) -> Dictionary:
	if _cache.has(path):
		return _cache[path]
	var ps := load(path) as PackedScene
	if ps == null:
		push_error("ModuleLibrary: cannot load %s" % path)
		return {}
	var inst := ps.instantiate()
	var m := inst as ZoneModule
	if m == null:
		push_error("ModuleLibrary: %s root is not a ZoneModule" % path)
		inst.free()
		return {}
	var d := {
		"path": path, "id": m.module_id if m.module_id != "" else path.get_file().get_basename(),
		"tags": Array(m.tags), "length": m.length_cells, "exit_dir": int(m.exit_dir),
		"weight": m.weight, "min_zone": m.min_zone,
		"entry": Transform3D.IDENTITY, "exit": Transform3D(Basis(Vector3.UP, ZoneModule.exit_yaw_delta(m.exit_dir)), ZoneModule.exit_local_position(m.exit_dir, m.length_cells)),
		"slots": [],
	}
	var entry := m.get_node_or_null("Entry") as Node3D
	if entry:
		d.entry = entry.transform
	var ex := m.get_node_or_null("Exit") as Node3D
	if ex:
		d.exit = ex.transform
	var slots := m.get_node_or_null("Slots")
	if slots:
		for s in slots.get_children():
			if s is Node3D:
				d.slots.append({"name": String(s.name), "kind": _kind_of(String(s.name)), "xform": (s as Node3D).transform})
	inst.free()
	_cache[path] = d
	return d


static func _kind_of(slot_name: String) -> String:
	for k in ["Enemy", "Loot", "Toll", "Tower", "Open", "Station", "Shelter"]:
		if slot_name.begins_with(k):
			return k.to_lower()
	return "other"


static func clear_cache() -> void:
	_cache.clear()
