class_name ZoneStreamer
extends Node3D
## Keeps the previous, current and next zones loaded and frees older ones (their corpse data stays
## in Game). Places zones relative to a floating origin cell to keep coordinates small forever.

signal zone_built(zone: ZoneInstance)

var world_seed: int = 0
var loaded: Dictionary = {}  # zone index -> ZoneInstance
var origin_cell: Vector2i = Vector2i.ZERO
var bake_navmesh: bool = true
## Extra builder hooks: Callable(ZoneInstance) called after a zone is built and added (enemies, etc.)
var on_zone_added: Array[Callable] = []


func layout(zone: int) -> ZoneLayout:
	return ZoneGenerator.layout(world_seed, zone)


func zone_offset(zone: int) -> Vector3:
	var s := ZoneGenerator.start_cell(world_seed, zone) - origin_cell
	return Vector3(s.x * ZoneGenerator.CELL, 0.0, s.y * ZoneGenerator.CELL)


## Loads center-1 .. center+1, frees the rest.
func ensure(center: int) -> void:
	var want: Array[int] = []
	for z in [center - 1, center, center + 1]:
		if z >= 0:
			want.append(z)
	for z in loaded.keys():
		if not want.has(z):
			var inst: ZoneInstance = loaded[z]
			loaded.erase(z)
			inst.queue_free()
			Events.zone_unloaded.emit(z)
	for z in want:
		if not loaded.has(z):
			_load(z)


func _load(zone: int) -> void:
	var l := layout(zone)
	var inst := ZoneInstance.create(l)
	inst.position = zone_offset(zone)
	add_child(inst)
	loaded[zone] = inst
	for cb in on_zone_added:
		cb.call(inst)
	if bake_navmesh:
		inst.bake_navigation()
	zone_built.emit(inst)
	Events.zone_loaded.emit(zone)


func zone_instance(zone: int) -> ZoneInstance:
	return loaded.get(zone) as ZoneInstance


## Zone index whose cells contain a world position (-1 if none loaded).
func zone_at(world_pos: Vector3) -> int:
	for z in loaded:
		var inst: ZoneInstance = loaded[z]
		var local := world_pos - inst.position
		if inst.has_local_cell(ZoneGenerator.cell_of(local)):
			return z
	return -1


func to_zone_local(zone: int, world_pos: Vector3) -> Vector3:
	return world_pos - zone_offset(zone)


func to_world(zone: int, local_pos: Vector3) -> Vector3:
	return local_pos + zone_offset(zone)


## Moves the floating origin to a new cell. Returns the world-space delta applied to everything.
func set_origin(cell: Vector2i) -> Vector3:
	if cell == origin_cell:
		return Vector3.ZERO
	var delta := Vector3(origin_cell.x - cell.x, 0, origin_cell.y - cell.y) * ZoneGenerator.CELL
	origin_cell = cell
	for z in loaded:
		(loaded[z] as ZoneInstance).position += delta
	return delta


## Relay station s sits in zone 0 (s == 0) or at the end of zone s-1.
static func station_zone(station_index: int) -> int:
	return 0 if station_index <= 0 else station_index - 1
