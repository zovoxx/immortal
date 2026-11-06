class_name CarryInventory
extends RefCounted
## Carry-slot inventory. Each entry is {"id": String, "count": int}.
## A stack occupies ItemDef.weight slots regardless of count. Weight-0 items live in the pouch.

var entries: Array = []
var capacity: int = 4


func _init(cap: int = 4) -> void:
	capacity = cap


func used_slots() -> int:
	var used := 0
	for e in entries:
		var d := ItemDB.get_def(e.id)
		used += d.weight if d else 1
	return used


func free_slots() -> int:
	return capacity - used_slots()


func is_overloaded() -> bool:
	return used_slots() > capacity


## How many of `count` units of `id` could be added.
func can_add(id: String, count: int = 1) -> int:
	var d := ItemDB.get_def(id)
	if d == null:
		return 0
	var room := 0
	for e in entries:
		if e.id == id:
			room += d.max_stack - int(e.count)
	var free := free_slots()
	while room < count and (d.weight == 0 or free >= d.weight):
		room += d.max_stack
		free -= d.weight
		if d.weight == 0 and room >= count:
			break
	return mini(room, count)


## Adds up to `count` units; returns how many were added. force=true ignores capacity (starting kit).
func add(id: String, count: int = 1, force: bool = false) -> int:
	var d := ItemDB.get_def(id)
	if d == null or count <= 0:
		return 0
	var remaining := count
	for e in entries:
		if remaining <= 0:
			break
		if e.id == id and int(e.count) < d.max_stack:
			var put := mini(d.max_stack - int(e.count), remaining)
			e.count = int(e.count) + put
			remaining -= put
	while remaining > 0:
		if not force and d.weight > 0 and free_slots() < d.weight:
			break
		var put := mini(d.max_stack, remaining)
		entries.append({"id": id, "count": put})
		remaining -= put
	return count - remaining


func count_of(id: String) -> int:
	var c := 0
	for e in entries:
		if e.id == id:
			c += int(e.count)
	return c


func has(id: String) -> bool:
	return count_of(id) > 0


## Removes up to `count` units of id; returns how many were removed.
func remove_id(id: String, count: int = 1) -> int:
	var removed := 0
	for i in range(entries.size() - 1, -1, -1):
		if removed >= count:
			break
		var e: Dictionary = entries[i]
		if e.id != id:
			continue
		var take := mini(int(e.count), count - removed)
		e.count = int(e.count) - take
		removed += take
		if int(e.count) <= 0:
			entries.remove_at(i)
	return removed


## Removes `count` units from the entry at index; returns the removed {id,count} (count may be less).
func remove_at(index: int, count: int = -1) -> Dictionary:
	if index < 0 or index >= entries.size():
		return {}
	var e: Dictionary = entries[index]
	var take: int = int(e.count) if count < 0 else mini(count, int(e.count))
	e.count = int(e.count) - take
	if int(e.count) <= 0:
		entries.remove_at(index)
	return {"id": e.id, "count": take}


## Entries that occupy slots (shown in the HUD carry bar), as indices into entries.
func slot_indices() -> Array[int]:
	var out: Array[int] = []
	for i in entries.size():
		var d := ItemDB.get_def(entries[i].id)
		if d and d.weight > 0:
			out.append(i)
	return out


## Movement multiplier: -penalty per slot used past `free_slots_allowed`.
func speed_multiplier(penalty_per_slot: float = 0.05, free_slots_allowed: int = 2) -> float:
	return clampf(1.0 - penalty_per_slot * float(maxi(0, used_slots() - free_slots_allowed)), 0.4, 1.0)


func to_array() -> Array:
	var out: Array = []
	for e in entries:
		out.append({"id": String(e.id), "count": int(e.count)})
	return out


func from_array(arr: Array) -> void:
	entries.clear()
	for e in arr:
		if e is Dictionary and ItemDB.has(String(e.get("id", ""))):
			entries.append({"id": String(e.id), "count": int(e.get("count", 1))})


## Everything except undroppable items (the Message).
func droppable_entries() -> Array:
	var out: Array = []
	for e in entries:
		var d := ItemDB.get_def(e.id)
		if d and d.droppable:
			out.append({"id": String(e.id), "count": int(e.count)})
	return out
