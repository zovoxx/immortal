class_name ZoneInstance
extends Node3D
## A loaded zone: module instances + edge blockers under a NavigationRegion3D (baked at runtime),
## stations, loot caches, corpses and enemies. Built from a ZoneLayout by build().

const EDGE_HEIGHT := 12.0
const EDGE_THICK := 3.0

var layout: ZoneLayout
var biome: Biome
var nav: NavigationRegion3D
var actors: Node3D
var stations: Dictionary = {}  # index -> RelayStation
var nav_ready: bool = false
var _cell_set: Dictionary = {}


static func create(l: ZoneLayout) -> ZoneInstance:
	var z := ZoneInstance.new()
	z.layout = l
	z.biome = BiomeDB.get_biome(l.biome_index)
	z.name = "Zone%d" % l.zone_index
	z._build()
	return z


func _build() -> void:
	nav = NavigationRegion3D.new()
	nav.name = "Nav"
	var nm := NavigationMesh.new()
	nm.agent_radius = 0.45
	nm.agent_height = 1.5
	nm.agent_max_climb = 0.4
	nm.agent_max_slope = 40.0
	nm.cell_size = 0.3
	nm.cell_height = 0.25
	nm.region_min_size = 4.0
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = Geo.LAYER_WORLD
	nav.navigation_mesh = nm
	add_child(nav)
	actors = Node3D.new()
	actors.name = "Actors"
	add_child(actors)
	for c in layout.all_cells():
		_cell_set[c] = true
	# modules
	for mi in layout.modules.size():
		var md: Dictionary = layout.modules[mi]
		var inst: Node3D = (load(md.path) as PackedScene).instantiate()
		inst.name = "M%02d_%s" % [mi, md.id]
		inst.transform = md.xform
		var st := inst.get_node_or_null("RelayStation") as RelayStation
		if st:
			var idx := 0 if (layout.zone_index == 0 and mi == 0) else layout.zone_index + 1
			st.station_index = idx
			stations[idx] = st
		nav.add_child(inst)
	_build_edges()
	_build_underlay()
	# loot caches
	for l in layout.loot:
		var cache := LootCache.new()
		cache.zone_index = layout.zone_index
		cache.cache_id = l.id
		cache.rolls = 3
		cache.transform = l.xform
		actors.add_child(cache)
	# corpses of this zone
	for c in Game.corpses_in_zone(layout.zone_index):
		spawn_corpse(c)


## Ordered path cells with their connections → walls on every other side.
func _build_edges() -> void:
	var order: Array[Vector2i] = layout.all_cells()
	var holder := Node3D.new()
	holder.name = "Edges"
	nav.add_child(holder)
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for i in order.size():
		var c := order[i]
		var open: Array[Vector2i] = []
		if i > 0:
			open.append(order[i - 1] - c)
		elif layout.zone_index > 0:
			open.append(Vector2i(0, -1))
		if i < order.size() - 1:
			open.append(order[i + 1] - c)
		else:
			open.append(Vector2i(0, 1))
		for d in dirs:
			if open.has(d):
				continue
			_edge(holder, c, d)


func _edge(parent: Node3D, cell: Vector2i, d: Vector2i) -> void:
	var center := ZoneGenerator.cell_center(cell)
	var half := ZoneGenerator.CELL * 0.5
	var pos := center + Vector3(d.x, 0, d.y) * (half + EDGE_THICK * 0.5)
	var along_x := d.y != 0
	var size := Vector3(ZoneGenerator.CELL + EDGE_THICK * 2.0, EDGE_HEIGHT, EDGE_THICK) if along_x else Vector3(EDGE_THICK, EDGE_HEIGHT, ZoneGenerator.CELL + EDGE_THICK * 2.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(cell.x, cell.y, d.x * 3 + d.y)) + layout.seed
	match biome.edge_style:
		"void":
			# no wall: the platforms end over the void. A low lip hints at the edge.
			Geo.deco_box(parent, pos - Vector3(d.x, 0, d.y) * (EDGE_THICK * 0.5) + Vector3(0, 0.05, 0), Vector3(size.x if along_x else 0.3, 0.1, size.z if not along_x else 0.3), biome.accent_color.darkened(0.4))
			if rng.randf() < 0.4:
				var far := center + Vector3(d.x, 0, d.y) * rng.randf_range(30, 60) + Vector3(0, rng.randf_range(-20, 8), 0)
				Geo.deco_box(parent, far, Vector3(rng.randf_range(3, 8), rng.randf_range(2, 6), rng.randf_range(3, 8)), biome.rock_color.darkened(0.2))
			return
		"barrier":
			Geo.box(parent, pos + Vector3(0, 4.0, 0), Vector3(size.x, 8.0, size.z), biome.rock_color.darkened(0.15), ["edge"])
			for i in 3:
				var off := Vector3(rng.randf_range(-8, 8), 0, 0) if along_x else Vector3(0, 0, rng.randf_range(-8, 8))
				Geo.deco_box(parent, pos + off + Vector3(0, 8.5 + rng.randf() * 1.5, 0), Vector3(2.0, rng.randf_range(1.0, 3.0), 2.0), biome.rock_color.darkened(0.3))
		"ridge":
			Geo.box(parent, pos + Vector3(0, 3.5, 0), Vector3(size.x, 7.0, size.z), biome.ground_color.darkened(0.2), ["edge"])
			for i in 4:
				var off := Vector3(rng.randf_range(-9, 9), 0, 0) if along_x else Vector3(0, 0, rng.randf_range(-9, 9))
				Geo.deco_sphere(parent, pos + off + Vector3(0, 7.2, 0), rng.randf_range(1.2, 2.2), biome.foliage_color.darkened(0.2), null, 0.7)
		"dune":
			Geo.box(parent, pos + Vector3(0, 4.5, 0), Vector3(size.x, 9.0, size.z), biome.ground_color.lightened(0.05), ["edge"])
			Geo.deco_sphere(parent, pos + Vector3(0, 8.5, 0), 6.0, biome.ground_color, null, 0.35)
		_:
			Geo.box(parent, pos + Vector3(0, EDGE_HEIGHT * 0.5, 0), size, biome.rock_color.darkened(rng.randf_range(0.05, 0.2)), ["edge"])
			for i in 2:
				var off := Vector3(rng.randf_range(-8, 8), 0, 0) if along_x else Vector3(0, 0, rng.randf_range(-8, 8))
				var tp := pos + off + Vector3(0, EDGE_HEIGHT, 0)
				Geo.deco_cone(parent, tp + Vector3(0, 2.0, 0), 1.8, 4.5, biome.foliage_color.darkened(0.15))


func _build_underlay() -> void:
	if not biome.underlay:
		var kill := VolumeArea.new()
		kill.kind = "kill"
		kill.cause = "fell into the void"
		var mn := Vector2(INF, INF)
		var mx := Vector2(-INF, -INF)
		for c in layout.all_cells():
			mn = mn.min(Vector2(c.x, c.y))
			mx = mx.max(Vector2(c.x, c.y))
		kill.size = Vector3((mx.x - mn.x + 5) * 20, 4, (mx.y - mn.y + 5) * 20)
		kill.position = Vector3((mn.x + mx.x) * 10, -32, (mn.y + mx.y) * 10 + 10)
		actors.add_child(kill)
		return
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for c in layout.all_cells():
		mn = mn.min(Vector2(c.x, c.y))
		mx = mx.max(Vector2(c.x, c.y))
	var u := MeshInstance3D.new()
	u.name = "Underlay"
	var pm := PlaneMesh.new()
	pm.size = Vector2((mx.x - mn.x + 6) * 20, (mx.y - mn.y + 4) * 20)
	u.mesh = pm
	u.material_override = Geo.mat(biome.ground_color.darkened(0.3))
	u.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	u.position = Vector3((mn.x + mx.x) * 10, -0.6, (mn.y + mx.y) * 10 + 10)
	add_child(u)


func bake_navigation() -> void:
	if not is_inside_tree():
		return
	nav.bake_finished.connect(func(): nav_ready = true, CONNECT_ONE_SHOT)
	nav.bake_navigation_mesh(true)


func has_local_cell(c: Vector2i) -> bool:
	return _cell_set.has(c)


func station_node(index: int) -> RelayStation:
	return stations.get(index) as RelayStation


func end_station() -> RelayStation:
	return station_node(layout.zone_index + 1)


func spawn_corpse(data: CorpseData) -> Corpse:
	var c: Corpse = preload("res://world/corpse/corpse.tscn").instantiate()
	c.data = data
	c.position = data.local_pos
	actors.add_child(c)
	return c


func corpse_nodes() -> Array:
	return actors.get_children().filter(func(n): return n is Corpse)
