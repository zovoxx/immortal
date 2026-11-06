class_name EnemySpawner
extends Node
## Spawns a zone's encounters from its layout features, plus scavengers drawn to corpses.

const SCRIPTS := {
	"hound": "res://enemies/hound/hound.gd",
	"scavenger": "res://enemies/scavenger/scavenger.gd",
	"tollkeeper": "res://enemies/tollkeeper/tollkeeper.gd",
	"watchtower": "res://enemies/watchtower/watchtower.gd",
	"rider": "res://enemies/rider/rider.gd",
}

## Max scavengers attracted per zone by corpses.
@export var max_corpse_scavengers: int = 3
## Seconds after a death before a scavenger arrives at the new corpse.
@export var new_corpse_scavenger_delay: float = 40.0
## Extra wandering scavengers per Salt Desert zone.
@export var desert_extra_scavengers: int = 2
var enabled: bool = true


func _ready() -> void:
	Events.courier_respawned.connect(_on_respawned)


func populate_zone(zone: ZoneInstance) -> void:
	if not enabled:
		return
	var l := zone.layout
	for f in l.enemies:
		spawn_feature(zone, f)
	# scavengers go for corpses with loot in this zone
	var with_loot := Game.corpses_in_zone(l.zone_index).filter(func(c): return c.item_count() > 0)
	var n := mini(max_corpse_scavengers, ceili(with_loot.size() / 2.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = l.seed * 13 + Game.corpses.size()
	for i in n:
		var c: CorpseData = with_loot[i % with_loot.size()]
		_spawn_scavenger_near(zone, c.local_pos, rng)
	# Salt Desert: scavengers everywhere
	if zone.biome and zone.biome.id == "desert":
		for i in desert_extra_scavengers + l.loop:
			var p: Vector3 = l.path_points[rng.randi_range(4, l.path_points.size() - 2)]
			spawn(zone, "scavenger", Transform3D(Basis(), p + Vector3(rng.randf_range(-5, 5), 0, rng.randf_range(-5, 5))))


func spawn_feature(zone: ZoneInstance, f: Dictionary) -> Array:
	var out: Array = []
	var t := String(f.type)
	var xf: Transform3D = f.xform
	match t:
		"hound":
			var pack: Array = []
			for i in int(f.count):
				var off := Vector3(cos(i * 2.1) * 1.6, 0, sin(i * 2.1) * 1.6)
				var h := spawn(zone, "hound", Transform3D(xf.basis, xf.origin + off))
				if h:
					h.group_id = String(f.id)
					pack.append(h)
			for h in pack:
				h.pack = pack
			out = pack
		"tollkeeper", "watchtower", "rider", "scavenger":
			for i in int(f.count):
				var off := Vector3(i * 1.5, 0, 0)
				var e := spawn(zone, t, Transform3D(xf.basis, xf.origin + off))
				if e:
					e.set("feature_id", String(f.id))
					out.append(e)
	return out


func spawn(zone: ZoneInstance, type: String, xf: Transform3D) -> Node3D:
	var path: String = SCRIPTS.get(type, "")
	if path == "" or not ResourceLoader.exists(path):
		return null
	var e: Node3D = load(path).new()
	e.set("zone_index", zone.layout.zone_index)
	e.transform = Transform3D(Basis(), xf.origin + Vector3.UP * 0.1)
	if e.has_method("set_initial_yaw"):
		e.call("set_initial_yaw", xf.basis.get_euler().y)
	zone.actors.add_child(e)
	return e


func _spawn_scavenger_near(zone: ZoneInstance, local_pos: Vector3, rng: RandomNumberGenerator) -> Node3D:
	# spawn on the path 20-40 m away from the corpse
	var best := local_pos
	var best_score := -INF
	for p in zone.layout.path_points:
		var d := p.distance_to(local_pos)
		var score := -absf(d - 30.0) + rng.randf() * 6.0
		if score > best_score:
			best_score = score
			best = p
	return spawn(zone, "scavenger", Transform3D(Basis(), best + Vector3(rng.randf_range(-3, 3), 0, rng.randf_range(-3, 3))))


func _on_respawned() -> void:
	var c := Game.most_recent_corpse()
	if c == null or c.item_count() == 0:
		return
	await get_tree().create_timer(new_corpse_scavenger_delay).timeout
	var world := get_tree().get_first_node_in_group("world")
	if world == null:
		return
	var zone: ZoneInstance = world.streamer.zone_instance(c.zone)
	if zone and Game.get_corpse(c.id) != null:
		var rng := RandomNumberGenerator.new()
		rng.seed = c.id
		_spawn_scavenger_near(zone, c.local_pos, rng)


## Debug: spawn an enemy near a world position in the current zone.
func debug_spawn(type: String, world_pos: Vector3) -> Node3D:
	var world := get_tree().get_first_node_in_group("world")
	var zone: ZoneInstance = world.current_zone_instance() if world else null
	if zone == null:
		return null
	var xf := Transform3D(Basis(), zone.to_local(world_pos))
	var arr := spawn_feature(zone, {"type": type, "xform": xf, "count": 3 if type == "hound" else 1, "id": "debug"})
	return arr[0] if not arr.is_empty() else null
