extends Node3D
## Placeholder courier visuals with procedural "animation". Replace the mesh children with your own
## .glb model and drive its AnimationPlayer from `set_pose()` — the courier logic only calls set_pose().

@onready var body: Node3D = $Body
@onready var head: Node3D = $Head
@onready var arm_l: Node3D = $ArmL
@onready var arm_r: Node3D = $ArmR
@onready var leg_l: Node3D = $LegL
@onready var leg_r: Node3D = $LegR
@onready var scarf: MeshInstance3D = $Scarf

var _phase: float = 0.0
var _lean: float = 0.0


func set_scarf_color(c: Color) -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	scarf.material_override = m


## state: "move", "air", "slide", "vault", "hang", "climb", "wallrun", "roll", "dead", "attack", "aim", "crouch"
func set_pose(state: String, speed: float, delta: float, wall_side: float = 0.0) -> void:
	_phase += delta * speed * 1.6
	var swing := sin(_phase) * clampf(speed / 7.0, 0.0, 1.0)
	var target_lean := 0.0
	var crouch := 0.0
	var roll := 0.0
	var arm_up := 0.0
	match state:
		"move":
			target_lean = clampf(speed / 10.0, 0.0, 1.0) * 0.25
		"crouch":
			crouch = 0.45
			target_lean = 0.2
		"air":
			swing = 0.3
		"slide":
			crouch = 0.7
			target_lean = -0.6
			swing = 0.0
		"vault":
			crouch = 0.3
			target_lean = 0.5
		"hang", "climb":
			arm_up = 1.0
			swing = sin(_phase * 0.5) * 0.2
		"wallrun":
			target_lean = 0.2
		"roll":
			crouch = 0.6
			roll = fmod(_phase * 2.0, TAU)
		"dead":
			rotation.x = lerpf(rotation.x, -PI * 0.5, clampf(delta * 6.0, 0.0, 1.0))
			return
		"attack":
			arm_up = 0.5
		"aim":
			arm_up = 0.7
	rotation.x = 0.0
	_lean = lerpf(_lean, target_lean, clampf(delta * 8.0, 0.0, 1.0))
	body.rotation.x = -_lean
	body.position.y = lerpf(body.position.y, 1.0 - crouch * 0.45, clampf(delta * 12.0, 0.0, 1.0))
	head.position.y = body.position.y + 0.75 - crouch * 0.1
	head.position.z = -_lean * 0.6
	leg_l.rotation.x = swing * 0.8
	leg_r.rotation.x = -swing * 0.8
	arm_l.rotation.x = lerpf(-swing * 0.7, -2.8, arm_up)
	arm_r.rotation.x = lerpf(swing * 0.7, -2.8, arm_up)
	arm_l.position.y = body.position.y + 0.35
	arm_r.position.y = body.position.y + 0.35
	rotation.z = lerpf(rotation.z, wall_side * 0.35, clampf(delta * 8.0, 0.0, 1.0))
	if state == "roll":
		body.rotation.x = -roll
