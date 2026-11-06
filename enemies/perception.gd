class_name Perception
extends RefCounted
## Shared detection rules: how far an enemy can see the courier (crouch, tall grass, darkness,
## weather, smoke, traits) and scent tracking multipliers.

const CROUCH_MULT := 0.55
const GRASS_MULT := 0.6
const GRASS_CROUCH_MULT := 0.35
const NIGHT_SIGHT_MULT := 0.55
const NIGHT_SCENT_MULT := 1.5


static func courier() -> Courier:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.get_first_node_in_group("player") as Courier if tree else null


static func weather() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.get_first_node_in_group("weather") if tree else null


## Multiplier on an enemy's sight range against the courier.
static func sight_mult(c: Courier, uses_light: bool = false) -> float:
	if c == null or c.is_dead():
		return 0.0
	if c.in_volume("station"):
		return 0.0
	var m := 1.0
	var grass := c.in_volume("tall_grass")
	if grass and c.crouching:
		m *= GRASS_CROUCH_MULT
	elif grass:
		m *= GRASS_MULT
	elif c.crouching:
		m *= CROUCH_MULT
	if not uses_light:
		m *= lerpf(1.0, NIGHT_SIGHT_MULT, Game.night_factor())
	var w := weather()
	if w and w.has_method("visibility_mult"):
		m *= float(w.visibility_mult())
	if c.data:
		m *= c.data.detect_range_mult()
	return m


static func scent_mult(c: Courier) -> float:
	if c == null:
		return 0.0
	var w := weather()
	if w and w.has_method("scent_disabled") and w.scent_disabled():
		return 0.0
	var m := lerpf(1.0, NIGHT_SCENT_MULT, Game.night_factor())
	if c.data:
		m *= c.data.scent_mult()
	return m


## True if the segment a->b passes through a smoke cloud.
static func smoke_blocks(a: Vector3, b: Vector3) -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	for s in tree.get_nodes_in_group("smoke"):
		var center: Vector3 = (s as Node3D).global_position
		var r: float = float(s.get("radius"))
		var ab := b - a
		var t := clampf((center - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		if (a + ab * t).distance_to(center) < r:
			return true
	return false


## Line of sight from an eye to a target point (world geometry + smoke).
static func has_los(space: PhysicsDirectSpaceState3D, eye: Vector3, target: Vector3, exclude: Array[RID]) -> bool:
	var q := PhysicsRayQueryParameters3D.create(eye, target, Geo.LAYER_WORLD, exclude)
	if not space.intersect_ray(q).is_empty():
		return false
	return not smoke_blocks(eye, target)
