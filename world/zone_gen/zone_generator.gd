class_name ZoneGenerator
extends RefCounted
## Seeded zone layout generation. A zone is a winding chain of modules on a 20 m grid, from its
## start (the previous zone's relay station) to its own relay station. Layouts are pure data
## (ZoneLayout) so they can be tested and regenerated identically: seed = world_seed + zone_index.
##
## Rules: headings are +Z, +X or -X (never back toward -Z), lateral drift stays within ±3 cells,
## at most 2 modules in a row run sideways, every zone ends heading +Z with its station.
## Guarantees per zone: a station, a shelter module, a climb (alternate route) module, a loot cache
## and at least one enemy encounter.

const CELL := 20.0
const MAX_LATERAL := 3
const MAX_SIDE_RUN := 2
const REQUIRED_TAGS: Array[String] = ["shelter", "climb"]

static var _layouts: Dictionary = {}
static var _starts: Dictionary = {}


static func clear_cache() -> void:
	_layouts.clear()
	_starts.clear()


static func cell_center(cell: Vector2i) -> Vector3:
	return Vector3(cell.x * CELL, 0.0, cell.y * CELL + CELL * 0.5)


static func cell_of(local_pos: Vector3) -> Vector2i:
	return Vector2i(roundi(local_pos.x / CELL), floori(local_pos.z / CELL))


static func heading_from_yaw(yaw: float) -> Vector2i:
	return Vector2i(roundi(sin(yaw)), roundi(cos(yaw)))


## Cached layout with its global start cell filled in.
static func layout(world_seed: int, zone: int) -> ZoneLayout:
	var key := "%d:%d" % [world_seed, zone]
	if _layouts.has(key):
		return _layouts[key]
	var l := generate(world_seed, zone)
	l.start_cell = start_cell(world_seed, zone)
	_layouts[key] = l
	return l


## Global start cell of a zone (cumulative over the previous zones' end cells).
static func start_cell(world_seed: int, zone: int) -> Vector2i:
	if zone <= 0:
		return Vector2i.ZERO
	var key := "%d:%d" % [world_seed, zone]
	if _starts.has(key):
		return _starts[key]
	# walk back to the nearest cached start
	var z := zone - 1
	while z > 0 and not _starts.has("%d:%d" % [world_seed, z]):
		z -= 1
	var s: Vector2i = _starts.get("%d:%d" % [world_seed, z], Vector2i.ZERO)
	while z < zone:
		var l := generate(world_seed, z) if not _layouts.has("%d:%d" % [world_seed, z]) else _layouts["%d:%d" % [world_seed, z]] as ZoneLayout
		s = s + l.end_cell + Vector2i(0, 1)
		z += 1
		_starts["%d:%d" % [world_seed, z]] = s
	return s


static func generate(world_seed: int, zone: int) -> ZoneLayout:
	var biome := BiomeDB.get_biome(Game.biome_index(zone))
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed + zone
	var l := ZoneLayout.new()
	l.zone_index = zone
	l.seed = world_seed + zone
	l.biome_index = Game.biome_index(zone)
	l.loop = Game.loop_index(zone)

	var infos: Array = []
	for p in biome.modules:
		var inf := ModuleLibrary.info(p)
		if not inf.is_empty() and not inf.tags.has("station"):
			infos.append(inf)
	var station_info := ModuleLibrary.info(biome.station_module)

	var st := {"cell": Vector2i.ZERO, "heading": Vector2i(0, 1), "origin": Vector3.ZERO, "yaw": 0.0, "side_run": 0}
	var occupied: Dictionary = {}
	if zone == 0:
		_place(l, station_info, st, occupied)
	var target := rng.randi_range(11, 14)
	var body := target - (2 if zone == 0 else 1)
	var schedule: Dictionary = {}
	for tag in REQUIRED_TAGS:
		var idx := rng.randi_range(1, body - 2)
		while schedule.has(idx):
			idx = (idx % (body - 2)) + 1
		schedule[idx] = tag
	var have: Dictionary = {}
	var placed := 0
	var step := 0
	var last_id := ""
	var pending: Array[String] = []
	while (placed < body or not pending.is_empty() or _missing(have).size() > 0) and step < body + 8:
		if schedule.has(step):
			pending.append(schedule[step])
		var want := pending[0] if not pending.is_empty() else ""
		var remaining := body - placed
		if remaining <= _missing(have).size() and want == "" and not _missing(have).is_empty():
			want = _missing(have)[0]
		var cands := _candidates(infos, st, occupied, zone, want, maxi(remaining, 2 if want != "" else 1))
		if cands.is_empty() and want != "":
			cands = _candidates(infos, st, occupied, zone, "", maxi(remaining, 1))
		if cands.is_empty():
			cands = _candidates(infos, st, occupied, zone, "", 99)
		if cands.is_empty():
			push_warning("ZoneGenerator: zone %d got stuck at %d cells" % [zone, placed])
			break
		var pick := _weighted(rng, cands, last_id)
		_place(l, pick, st, occupied)
		last_id = pick.id
		placed += int(pick.length)
		for t in pick.tags:
			have[t] = true
		if want != "" and pick.tags.has(want):
			pending.erase(want)
		step += 1
	# turn back to +Z before the station
	var guard := 0
	while st.heading != Vector2i(0, 1) and guard < 3:
		guard += 1
		var turns := infos.filter(func(inf): return _fits(inf, st, occupied, zone) and _heading_after(st, inf) == Vector2i(0, 1))
		if turns.is_empty():
			break
		_place(l, _weighted(rng, turns, last_id), st, occupied)
	# end station
	_place(l, station_info, st, occupied)
	l.end_cell = l.modules[l.modules.size() - 1].cells[0]
	l.end_heading = st.heading
	_compute_features(l, rng, biome)
	return l


static func _missing(have: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for t in REQUIRED_TAGS:
		if not have.has(t):
			out.append(t)
	return out


static func _heading_after(st: Dictionary, inf: Dictionary) -> Vector2i:
	return heading_from_yaw(float(st.yaw) + ZoneModule.exit_yaw_delta(int(inf.exit_dir)))


static func _fits(inf: Dictionary, st: Dictionary, occupied: Dictionary, zone: int) -> bool:
	if int(inf.min_zone) > zone:
		return false
	var h: Vector2i = st.heading
	var new_h := _heading_after(st, inf)
	if new_h.y < 0:
		return false
	var cell: Vector2i = st.cell
	var length := int(inf.length)
	for k in length:
		var c := cell + h * k
		if occupied.has(c) or absi(c.x) > MAX_LATERAL:
			return false
	var last := cell + h * (length - 1)
	var next := last + new_h
	if occupied.has(next) or absi(next.x) > MAX_LATERAL:
		return false
	# don't run sideways for too long
	if h.y == 0 and new_h.y == 0 and int(st.side_run) + length >= MAX_SIDE_RUN:
		return false
	return true


static func _candidates(infos: Array, st: Dictionary, occupied: Dictionary, zone: int, want_tag: String, max_len: int) -> Array:
	var out: Array = []
	for inf in infos:
		if want_tag != "" and not inf.tags.has(want_tag):
			continue
		if int(inf.length) > max_len:
			continue
		if _fits(inf, st, occupied, zone):
			out.append(inf)
	return out


static func _weighted(rng: RandomNumberGenerator, cands: Array, last_id: String) -> Dictionary:
	var total := 0.0
	var ws: Array[float] = []
	for c in cands:
		var w := float(c.weight) * (0.25 if c.id == last_id else 1.0)
		ws.append(w)
		total += w
	var r := rng.randf() * total
	for i in cands.size():
		r -= ws[i]
		if r <= 0.0:
			return cands[i]
	return cands[cands.size() - 1]


static func _place(l: ZoneLayout, inf: Dictionary, st: Dictionary, occupied: Dictionary) -> void:
	var yaw: float = st.yaw
	var origin: Vector3 = st.origin
	var xform := Transform3D(Basis(Vector3.UP, yaw), origin) * (inf.entry as Transform3D).affine_inverse()
	var h: Vector2i = st.heading
	var cells: Array[Vector2i] = []
	for k in int(inf.length):
		var c: Vector2i = st.cell + h * k
		cells.append(c)
		occupied[c] = true
	var exit_x: Transform3D = xform * (inf.exit as Transform3D)
	var new_yaw := yaw + ZoneModule.exit_yaw_delta(int(inf.exit_dir))
	var new_h := heading_from_yaw(new_yaw)
	l.modules.append({
		"path": inf.path, "id": inf.id, "tags": inf.tags, "cells": cells, "heading": h,
		"length": int(inf.length), "exit_dir": int(inf.exit_dir), "xform": xform,
		"entry_pos": origin, "exit_pos": exit_x.origin, "info": inf,
	})
	st.side_run = (int(st.side_run) + int(inf.length)) if (h.y == 0 and new_h.y == 0) else 0
	st.cell = cells[cells.size() - 1] + new_h
	st.heading = new_h
	st.origin = exit_x.origin
	st.yaw = new_yaw


static func _compute_features(l: ZoneLayout, rng: RandomNumberGenerator, biome: Biome) -> void:
	var feat_rng := RandomNumberGenerator.new()
	feat_rng.seed = l.seed * 31 + 7
	var loot_slots: Array = []
	var enemy_slots: Array = []
	var open_slots: Array = []
	for mi in l.modules.size():
		var m: Dictionary = l.modules[mi]
		var xf: Transform3D = m.xform
		l.path_points.append(m.entry_pos)
		for c in m.cells:
			l.path_points.append(cell_center(c))
		for s in m.info.slots:
			var sx: Transform3D = xf * (s.xform as Transform3D)
			var entry := {"xform": sx, "module": mi, "name": s.name}
			match String(s.kind):
				"station":
					var idx := 0 if (l.zone_index == 0 and mi == 0) else l.zone_index + 1
					l.stations.append({"index": idx, "xform": sx, "module": mi})
				"shelter":
					l.shelters.append(entry)
				"loot":
					if not m.tags.has("station"):
						loot_slots.append(entry)
				"enemy":
					if mi > 0 and not m.tags.has("station"):
						enemy_slots.append(entry)
				"open":
					open_slots.append(entry)
				"toll":
					l.enemies.append({"type": "tollkeeper", "xform": sx, "count": 1, "id": "toll_%d" % mi, "module": mi})
				"tower":
					if feat_rng.randf() < 0.75 or float(biome.enemy_weights.get("watchtower", 0.0)) > 0.5:
						l.enemies.append({"type": "watchtower", "xform": sx, "count": 1, "id": "tower_%d" % mi, "module": mi})
	l.path_points.append(l.modules[l.modules.size() - 1].exit_pos)
	# loot caches (at least one)
	_shuffle(feat_rng, loot_slots)
	var n_loot := 1 + (1 if feat_rng.randf() < 0.45 * Difficulty.loot_mult(l.zone_index) else 0)
	for i in mini(n_loot, loot_slots.size()):
		l.loot.append({"id": "cache_%d" % i, "xform": loot_slots[i].xform})
	if l.loot.is_empty():
		var mid: Dictionary = l.modules[l.modules.size() / 2]
		l.loot.append({"id": "cache_0", "xform": Transform3D(Basis(), cell_center(mid.cells[0]) + Vector3(4, 0, 0))})
	# generic encounters
	var groups := Difficulty.enemy_groups(l.zone_index)
	_shuffle(feat_rng, enemy_slots)
	var weights: Dictionary = biome.enemy_weights.duplicate()
	weights.erase("watchtower")
	weights.erase("tollkeeper")
	for i in mini(groups, enemy_slots.size()):
		var t := _pick_type(feat_rng, weights, ["rider"])
		var count := 1
		if t == "hound":
			count = feat_rng.randi_range(2, mini(4, 2 + l.zone_index / 6 + l.loop))
		elif t == "scavenger":
			count = feat_rng.randi_range(1, 2)
		l.enemies.append({"type": t, "xform": enemy_slots[i].xform, "count": count, "id": "grp_%d" % i, "module": enemy_slots[i].module})
	# riders roam open ground
	if float(weights.get("rider", 0.0)) > 0.0:
		_shuffle(feat_rng, open_slots)
		for i in mini(1 + l.loop, open_slots.size()):
			l.enemies.append({"type": "rider", "xform": open_slots[i].xform, "count": 1, "id": "rider_%d" % i, "module": open_slots[i].module})
	if l.enemies.is_empty():
		var mid: Dictionary = l.modules[maxi(l.modules.size() / 2, 1)]
		l.enemies.append({"type": "hound", "xform": Transform3D(Basis(), cell_center(mid.cells[0])), "count": 2, "id": "grp_fallback", "module": l.modules.size() / 2})
	# weather roll (separate stream so tuning weather never changes layouts)
	var w_rng := RandomNumberGenerator.new()
	w_rng.seed = l.seed * 977 + 13
	l.storm = w_rng.randf() < Difficulty.storm_chance(l.zone_index)
	l.storm_delay = w_rng.randf_range(15.0, 60.0)
	l.length_m = 0.0
	for i in range(1, l.path_points.size()):
		l.length_m += l.path_points[i - 1].distance_to(l.path_points[i])


static func _pick_type(rng: RandomNumberGenerator, weights: Dictionary, exclude: Array) -> String:
	var total := 0.0
	for k in weights:
		if not exclude.has(k):
			total += float(weights[k])
	if total <= 0.0:
		return "hound"
	var r := rng.randf() * total
	for k in weights:
		if exclude.has(k):
			continue
		r -= float(weights[k])
		if r <= 0.0:
			return String(k)
	return "hound"


static func _shuffle(rng: RandomNumberGenerator, arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t: Variant = arr[i]
		arr[i] = arr[j]
		arr[j] = t
