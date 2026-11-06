class_name CameraRig
extends Node3D
## Third-person orbit camera on a spring arm. Follows a target; mouse/right-stick orbit;
## sprint FOV kick; over-the-shoulder aim mode; screen shake.

@export var follow_height: float = 1.55
@export var follow_smoothing: float = 18.0
@export var arm_length: float = 4.2
@export var aim_arm_length: float = 1.9
@export var aim_shoulder_offset: float = 0.65
@export var aim_fov_delta: float = -16.0
@export var min_pitch_deg: float = -70.0
@export var max_pitch_deg: float = 55.0
@export var fov_lerp_speed: float = 6.0

@onready var yaw_node: Node3D = $Yaw
@onready var pitch_node: Node3D = $Yaw/Pitch
@onready var spring: SpringArm3D = $Yaw/Pitch/SpringArm3D
@onready var camera: Camera3D = $Yaw/Pitch/SpringArm3D/Camera3D

var target: Node3D
var aiming: bool = false
var sprint_kick: float = 0.0
var extra_fov: float = 0.0
var _shake: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	top_level = true
	spring.spring_length = arm_length
	spring.collision_mask = Geo.LAYER_WORLD
	spring.margin = 0.25
	camera.fov = Settings.fov
	pitch_node.rotation.x = deg_to_rad(-15.0)
	if target:
		global_position = target.global_position + Vector3.UP * follow_height


func set_target(t: Node3D) -> void:
	target = t
	if t:
		if t is CollisionObject3D:
			spring.add_excluded_object((t as CollisionObject3D).get_rid())
		global_position = t.global_position + Vector3.UP * follow_height


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var s := Settings.mouse_sensitivity * 0.01
		rotate_view(-event.relative.x * s, -event.relative.y * s * (-1.0 if Settings.invert_y else 1.0))


func rotate_view(yaw_delta: float, pitch_delta: float) -> void:
	yaw_node.rotation.y += yaw_delta
	pitch_node.rotation.x = clampf(pitch_node.rotation.x + pitch_delta, deg_to_rad(min_pitch_deg), deg_to_rad(max_pitch_deg))


func _process(delta: float) -> void:
	var look := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if look.length() > 0.0:
		var s := Settings.gamepad_sensitivity * delta
		rotate_view(-look.x * s, -look.y * s * 0.7 * (-1.0 if Settings.invert_y else 1.0))
	if target and is_instance_valid(target):
		var goal := target.global_position + Vector3.UP * follow_height
		global_position = global_position.lerp(goal, clampf(follow_smoothing * delta, 0.0, 1.0))
		if global_position.distance_to(goal) > 6.0:
			global_position = goal
	var goal_len := aim_arm_length if aiming else arm_length
	spring.spring_length = lerpf(spring.spring_length, goal_len, clampf(10.0 * delta, 0.0, 1.0))
	spring.position.x = lerpf(spring.position.x, aim_shoulder_offset if aiming else 0.0, clampf(10.0 * delta, 0.0, 1.0))
	var goal_fov := Settings.fov + sprint_kick + extra_fov + (aim_fov_delta if aiming else 0.0)
	camera.fov = lerpf(camera.fov, goal_fov, clampf(fov_lerp_speed * delta, 0.0, 1.0))
	if _shake > 0.0:
		_shake = maxf(_shake - delta * 2.5, 0.0)
		camera.h_offset = _rng.randf_range(-1, 1) * _shake * 0.25
		camera.v_offset = _rng.randf_range(-1, 1) * _shake * 0.25
	else:
		camera.h_offset = 0.0
		camera.v_offset = 0.0


func shake(amount: float) -> void:
	_shake = clampf(maxf(_shake, amount), 0.0, 1.5)


## Horizontal basis of the camera (for camera-relative movement).
func flat_basis() -> Basis:
	return Basis(Vector3.UP, yaw_node.global_rotation.y)


func forward() -> Vector3:
	return -camera.global_transform.basis.z


## Point the centre of the screen is looking at (for aiming).
func aim_point(space: PhysicsDirectSpaceState3D, exclude: Array[RID], max_dist: float = 80.0) -> Vector3:
	var from := camera.global_position
	var to := from + forward() * max_dist
	var q := PhysicsRayQueryParameters3D.create(from, to, Geo.LAYER_WORLD | Geo.LAYER_ENEMY | Geo.LAYER_HITBOX, exclude)
	q.collide_with_areas = true
	var hit := space.intersect_ray(q)
	return hit.position if hit else to


func face_direction(dir: Vector3) -> void:
	if dir.length_squared() > 0.001:
		yaw_node.rotation.y = atan2(-dir.x, -dir.z)
