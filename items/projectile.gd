class_name Projectile
extends Node3D
## A thrown sling stone / pot. Ballistic, swept raycast collision against world, enemies and
## hitboxes (watchtower lanterns). Effect on impact depends on `kind`.

const GRAVITY := 18.0

var kind: String = "stone"
var damage: float = 18.0
var velocity: Vector3 = Vector3.ZERO
var thrower: Node3D
var _life: float = 6.0
var _mesh: MeshInstance3D


func _ready() -> void:
	add_to_group("projectile")
	_mesh = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.09 if kind == "stone" else 0.16
	sm.height = sm.radius * 2.0
	sm.radial_segments = 8
	sm.rings = 4
	_mesh.mesh = sm
	var col := Color(0.5, 0.5, 0.5)
	match kind:
		"noise": col = Color(0.9, 0.6, 0.2)
		"smoke": col = Color(0.6, 0.6, 0.7)
		"caltrops": col = Color(0.4, 0.4, 0.45)
		"fire": col = Color(1.0, 0.35, 0.1)
	_mesh.material_override = Geo.mat(col, 0.6, 1.0 if kind == "fire" else 0.0)
	add_child(_mesh)


func _physics_process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return
	velocity.y -= GRAVITY * delta
	var from := global_position
	var to := from + velocity * delta
	var ex: Array[RID] = []
	if thrower and is_instance_valid(thrower) and thrower is CollisionObject3D:
		ex.append((thrower as CollisionObject3D).get_rid())
	var q := PhysicsRayQueryParameters3D.create(from, to, Geo.LAYER_WORLD | Geo.LAYER_ENEMY | Geo.LAYER_HITBOX, ex)
	q.collide_with_areas = true
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		global_position = to
		return
	_impact(hit.position, hit.normal, hit.collider)


func _impact(pos: Vector3, normal: Vector3, collider: Object) -> void:
	global_position = pos
	var node := collider as Node
	var lantern_owner: Node = null
	if node:
		var n := node
		while n and lantern_owner == null:
			if n.is_in_group("lantern"):
				lantern_owner = n
			n = n.get_parent()
	var enemy: Enemy = null
	if node:
		var n2 := node
		while n2 and enemy == null:
			if n2 is Enemy:
				enemy = n2
			n2 = n2.get_parent()
	var parent := get_parent()
	match kind:
		"stone":
			var tower: Object = lantern_owner.get_meta("tower") if lantern_owner and lantern_owner.has_meta("tower") else lantern_owner
			if tower and tower.has_method("on_lantern_hit"):
				tower.on_lantern_hit()
			elif enemy:
				enemy.take_damage(damage, thrower.global_position if thrower else pos, "stone")
			Audio.play_at("impact", pos, -4.0)
			Events.sound_emitted.emit(pos, 7.0, "impact")
		"noise":
			var nm := NoiseMakerEffect.new()
			parent.add_child(nm)
			nm.global_position = pos + normal * 0.1
		"smoke":
			var sc := SmokeCloud.new()
			parent.add_child(sc)
			sc.global_position = pos + Vector3.UP * 0.5
		"caltrops":
			var ca := CaltropsEffect.new()
			ca.damage = damage
			parent.add_child(ca)
			ca.global_position = pos + Vector3.UP * 0.05
		"fire":
			var fa := FireEffect.new()
			fa.burst_damage = damage
			fa.thrower = thrower
			parent.add_child(fa)
			fa.global_position = pos + Vector3.UP * 0.05
	queue_free()
