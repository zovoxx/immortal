class_name Courier
extends CharacterBody3D
## The player courier: parkour movement (walk/run/sprint/jump/slide/vault/climb/wall-run/roll),
## stamina, health, fall damage, footstep noise and the scent trail hounds follow.
## Combat and interaction live in child components (CourierCombat, CourierInteract).

enum State { MOVE, SLIDE, VAULT, HANG, CLIMB_UP, WALLRUN, ROLL, USING, DEAD }

@export var tuning: MovementTuning = preload("res://player/movement_tuning.tres")

@onready var model: Node3D = $Model
@onready var collision: CollisionShape3D = $CollisionShape3D
@onready var camera_rig: CameraRig = $CameraRig

var state: State = State.MOVE
var data: CourierData

# --- stamina / health ---
var stamina: float = 100.0
var max_stamina: float = 100.0
var exhausted: bool = false
var _stamina_regen_wait: float = 0.0
var invulnerable_timer: float = 0.0
var input_enabled: bool = true

# --- movement runtime ---
var move_input: Vector2 = Vector2.ZERO
var wish_dir: Vector3 = Vector3.ZERO
var facing: Vector3 = Vector3.FORWARD
var crouching: bool = false
var sprinting: bool = false
var aiming: bool = false
var _coyote: float = 0.0
var _jump_buffer: float = 0.0
var _was_on_floor: bool = true
var _air_peak_y: float = 0.0
var _grab_cooldown: float = 0.0
var _state_time: float = 0.0
var _stride: float = 0.0
var speed_modifier: float = 1.0  # external (weather, caltrops on player, etc.)

# slide / roll
var _slide_dir: Vector3 = Vector3.ZERO
var _slide_speed: float = 0.0
# vault / climb-up tween
var _tween_from: Vector3
var _tween_to: Vector3
var _tween_peak: float
var _tween_time: float
var _tween_dur: float
var _vault_exit_velocity: Vector3
# hang
var _ledge_y: float = 0.0
var _wall_normal: Vector3 = Vector3.BACK
# wall-run
var _wallrun_dir: Vector3 = Vector3.ZERO
var _wallrun_normal: Vector3 = Vector3.ZERO
var _last_wallrun_normal: Vector3 = Vector3.ZERO
var _wallrun_side: float = 0.0
# using an item (healing)
var _use_callback: Callable
var _use_time: float = 0.0

# --- environment volumes ---
var _volumes: Dictionary = {}  # kind -> Array[Area3D]
var _breath: float = 4.0
var _drown_tick: float = 0.0
var wind_force: Vector3 = Vector3.ZERO

# --- scent ---
var scent := ScentTrail.new(60)

# --- input edges (sampled once per physics frame) ---
var _held: Dictionary = {}
var _edges: Dictionary = {}
const EDGE_ACTIONS: Array[String] = ["jump", "crouch", "dodge"]


func _ready() -> void:
	add_to_group("player")
	collision_layer = Geo.LAYER_PLAYER
	collision_mask = Geo.LAYER_WORLD | Geo.LAYER_ENEMY
	floor_max_angle = deg_to_rad(48.0)
	floor_snap_length = 0.35
	camera_rig.set_target(self)
	if data == null:
		data = Game.courier
	apply_courier_data()
	_air_peak_y = global_position.y
	Events.courier_spawned.emit(self)


func apply_courier_data() -> void:
	if data == null:
		return
	max_stamina = tuning.max_stamina * data.stamina_mult()
	stamina = max_stamina
	if model.has_method("set_scarf_color"):
		var hue := fposmod(float(data.index) * 0.137, 1.0)
		model.set_scarf_color(Color.from_hsv(hue, 0.7, 0.85))
	Events.health_changed.emit(data.hp, data.max_hp)
	Events.stamina_changed.emit(stamina, max_stamina)


# =====================================================================
# Main loop
# =====================================================================

func _physics_process(delta: float) -> void:
	_state_time += delta
	invulnerable_timer = maxf(invulnerable_timer - delta, 0.0)
	_grab_cooldown = maxf(_grab_cooldown - delta, 0.0)
	if state == State.DEAD:
		velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)
		velocity.y -= tuning.gravity * delta
		move_and_slide()
		model.set_pose("dead", 0.0, delta)
		return
	_read_input()
	match state:
		State.MOVE, State.USING:
			_state_move(delta)
		State.SLIDE:
			_state_slide(delta)
		State.VAULT, State.CLIMB_UP:
			_state_tween(delta)
		State.HANG:
			_state_hang(delta)
		State.WALLRUN:
			_state_wallrun(delta)
		State.ROLL:
			_state_roll(delta)
	_update_stamina(delta)
	_update_landing()
	_update_water(delta)
	_update_footsteps(delta)
	_update_visuals(delta)
	scent.update(delta, global_position, Game.play_time, _point_in_water)
	if global_position.y < -60.0:
		die("fell into the void")


func _read_input() -> void:
	if not input_enabled:
		move_input = Vector2.ZERO
		wish_dir = Vector3.ZERO
		sprinting = false
		return
	for a in EDGE_ACTIONS:
		var down := Input.is_action_pressed(a)
		_edges[a] = down and not bool(_held.get(a, false))
		_held[a] = down
	move_input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var b := camera_rig.flat_basis()
	var d := b * Vector3(move_input.x, 0.0, move_input.y)
	d.y = 0.0
	wish_dir = d.normalized() if d.length() > 0.05 else Vector3.ZERO
	sprinting = Input.is_action_pressed("sprint") and not exhausted and move_input.length() > 0.3 and not crouching
	if pressed("jump"):
		_jump_buffer = tuning.jump_buffer


## True on the physics frame an action went down.
func pressed(action: String) -> bool:
	return input_enabled and bool(_edges.get(action, false))


func _enter_state(s: State) -> void:
	state = s
	_state_time = 0.0


# =====================================================================
# States
# =====================================================================

func _state_move(delta: float) -> void:
	var on_floor := is_on_floor()
	if on_floor:
		_coyote = tuning.coyote_time
		_last_wallrun_normal = Vector3.ZERO
	else:
		_coyote -= delta
	_jump_buffer -= delta

	# crouch toggling (hold)
	var want_crouch := input_enabled and Input.is_action_pressed("crouch")
	if want_crouch and not crouching and on_floor:
		# sprint + crouch press = slide
		var hspeed := Vector2(velocity.x, velocity.z).length()
		if pressed("crouch") and hspeed >= tuning.slide_min_speed and state == State.MOVE:
			_start_slide()
			return
		_set_crouch(true)
	elif not want_crouch and crouching and _can_stand():
		_set_crouch(false)

	var target_speed := _target_speed()
	var wish := wish_dir * target_speed
	var hvel := Vector3(velocity.x, 0.0, velocity.z)
	var accel := tuning.ground_accel if wish.length() > 0.01 else tuning.ground_decel
	if not on_floor:
		accel = tuning.air_accel
		# keep momentum in the air unless steering against it
		if wish.length() < 0.01:
			accel = 1.0
	hvel = hvel.move_toward(wish, accel * delta)
	velocity.x = hvel.x
	velocity.z = hvel.z

	if not on_floor:
		velocity.y = maxf(velocity.y - tuning.gravity * delta, -tuning.max_fall_speed)
		velocity += wind_force * delta
	elif velocity.y < 0.0:
		velocity.y = -0.5

	if state == State.USING:
		_use_time -= delta
		if _use_time <= 0.0:
			_enter_state(State.MOVE)
			if _use_callback.is_valid():
				_use_callback.call()
		move_and_slide()
		return

	# jump
	if _jump_buffer > 0.0 and _coyote > 0.0 and input_enabled:
		if not crouching or _can_stand():
			_set_crouch(false)
			_jump_buffer = 0.0
			_coyote = 0.0
			velocity.y = _jump_velocity()
			Audio.play_at("jump", global_position, -12.0)

	# dodge roll
	if pressed("dodge") and on_floor and stamina >= tuning.roll_stamina_cost and not aiming:
		_start_roll()
		return

	# parkour checks
	if wish_dir != Vector3.ZERO:
		if on_floor and hvel.length() >= tuning.vault_min_speed and not crouching and _try_vault():
			return
		if not on_floor and _grab_cooldown <= 0.0 and velocity.y < 3.0 and _try_ledge_grab():
			return
		if not on_floor and _try_wallrun():
			return
	# jump pressed in front of a climbable ledge from the ground: jump first, grab happens mid-air

	move_and_slide()


func _target_speed() -> float:
	var base := tuning.run_speed
	if crouching:
		base = tuning.crouch_speed
	elif exhausted:
		base = tuning.exhausted_speed
	elif sprinting:
		base = tuning.sprint_speed
	elif (input_enabled and Input.is_action_pressed("walk")) or move_input.length() < tuning.walk_stick_threshold:
		base = tuning.walk_speed
	if aiming:
		base = minf(base, tuning.walk_speed)
	if state == State.USING:
		base = minf(base, tuning.crouch_speed)
	return base * movement_multiplier()


func movement_multiplier() -> float:
	var m := speed_modifier * Game.momentum_speed_mult()
	if data:
		m *= data.speed_mult() * data.inventory.speed_multiplier(Game.config.load_penalty_per_slot, Game.config.free_load_slots)
	if in_volume("water"):
		m *= 0.7
	return m


func _jump_velocity() -> float:
	return sqrt(2.0 * tuning.gravity * tuning.jump_height)


# ---------------------------------------------------------------- slide

func _start_slide() -> void:
	_enter_state(State.SLIDE)
	_set_crouch(true)
	var h := Vector3(velocity.x, 0.0, velocity.z)
	_slide_dir = h.normalized() if h.length() > 0.1 else facing
	_slide_speed = maxf(h.length(), tuning.slide_start_speed * movement_multiplier())
	Audio.play_at("slide", global_position, -6.0)
	emit_noise(tuning.noise_run, "slide")


func _state_slide(delta: float) -> void:
	_slide_speed = maxf(_slide_speed - tuning.slide_friction * delta, 0.0)
	# slight steering
	if wish_dir != Vector3.ZERO:
		_slide_dir = _slide_dir.slerp(wish_dir, clampf(delta * 1.5, 0.0, 1.0)).normalized()
	velocity.x = _slide_dir.x * _slide_speed
	velocity.z = _slide_dir.z * _slide_speed
	velocity.y = -1.0 if is_on_floor() else velocity.y - tuning.gravity * delta
	move_and_slide()
	_jump_buffer -= delta
	if _jump_buffer > 0.0 and _can_stand():
		_jump_buffer = 0.0
		_set_crouch(false)
		velocity.y = _jump_velocity()
		_enter_state(State.MOVE)
		return
	var done := _state_time >= tuning.slide_duration or _slide_speed < tuning.crouch_speed or not is_on_floor()
	if done:
		_enter_state(State.MOVE)
		if _can_stand() and not Input.is_action_pressed("crouch"):
			_set_crouch(false)


# ---------------------------------------------------------------- roll

func _start_roll() -> void:
	_enter_state(State.ROLL)
	use_stamina(tuning.roll_stamina_cost)
	_set_crouch(true)
	_slide_dir = wish_dir if wish_dir != Vector3.ZERO else facing
	invulnerable_timer = tuning.roll_iframes
	Audio.play_at("slide", global_position, -10.0, 30.0, 0.2)


func _state_roll(delta: float) -> void:
	var s := tuning.roll_speed * movement_multiplier()
	velocity.x = _slide_dir.x * s
	velocity.z = _slide_dir.z * s
	velocity.y = -1.0 if is_on_floor() else velocity.y - tuning.gravity * delta
	move_and_slide()
	if _state_time >= tuning.roll_duration:
		_enter_state(State.MOVE)
		if _can_stand():
			_set_crouch(false)


# ---------------------------------------------------------------- vault

func _space() -> PhysicsDirectSpaceState3D:
	return get_world_3d().direct_space_state


func _ray(from: Vector3, to: Vector3, mask: int = Geo.LAYER_WORLD) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, to, mask, [get_rid()])
	return _space().intersect_ray(q)


func _try_vault() -> bool:
	var fwd := Vector3(velocity.x, 0.0, velocity.z).normalized()
	if fwd.dot(wish_dir) < 0.6:
		return false
	var feet := global_position
	var knee := feet + Vector3.UP * 0.45
	var hit := _ray(knee, knee + fwd * tuning.vault_probe_distance)
	if hit.is_empty() or absf(hit.normal.y) > 0.5:
		# low obstacle below knee height
		var low := feet + Vector3.UP * 0.12
		hit = _ray(low, low + fwd * tuning.vault_probe_distance)
		if hit.is_empty() or absf(hit.normal.y) > 0.5:
			return false
	var into := -Vector3(hit.normal.x, 0.0, hit.normal.z).normalized()
	var top_from := Vector3(hit.position.x, feet.y + tuning.vault_max_height + 0.35, hit.position.z) + into * 0.2
	var top := _ray(top_from, Vector3(top_from.x, feet.y + 0.05, top_from.z))
	if top.is_empty() or top.normal.y < 0.7:
		return false
	var h: float = top.position.y - feet.y
	if h < tuning.vault_min_height or h > tuning.vault_max_height:
		return false
	# make sure the space above the obstacle is clear at standing-ish height
	if not _ray(top.position + Vector3.UP * 0.1, top.position + Vector3.UP * 1.2).is_empty():
		return false
	# find the far side: thin obstacles are vaulted over, deep ones mantled onto
	var landing := Vector3.ZERO
	var over := false
	for d in [0.45, 0.8, 1.15, 1.5]:
		var p: Vector3 = Vector3(hit.position.x, top.position.y + 0.3, hit.position.z) + into * d
		var down := _ray(p, p + Vector3.DOWN * 0.6)
		if down.is_empty() or down.position.y < top.position.y - 0.3:
			landing = Vector3(p.x, top.position.y + 0.05, p.z) + into * 0.45
			over = true
			break
	if not over:
		landing = Vector3(hit.position.x, top.position.y + 0.05, hit.position.z) + into * 0.55
	if not _fits_at(landing, tuning.crouch_height):
		return false
	_tween_from = feet
	_tween_to = landing
	_tween_peak = top.position.y + 0.35
	_tween_time = 0.0
	_tween_dur = tuning.vault_duration * (0.7 if h < 0.6 else 1.0)
	_vault_exit_velocity = into * maxf(Vector3(velocity.x, 0.0, velocity.z).length(), tuning.run_speed * 0.8)
	_enter_state(State.VAULT)
	Audio.play_at("jump", global_position, -10.0)
	return true


## Shared tween for vault and climb-up: quadratic arc from _tween_from to _tween_to over _tween_peak.
func _state_tween(delta: float) -> void:
	_tween_time += delta
	var t := clampf(_tween_time / _tween_dur, 0.0, 1.0)
	var p := _tween_from.lerp(_tween_to, t if state == State.VAULT else clampf((t - 0.55) / 0.45, 0.0, 1.0))
	var y0 := _tween_from.y
	var y1 := _tween_to.y
	if state == State.VAULT:
		p.y = (1.0 - t) * (1.0 - t) * y0 + 2.0 * (1.0 - t) * t * _tween_peak + t * t * y1
	else:
		p.y = lerpf(y0, y1, ease(clampf(t / 0.55, 0.0, 1.0), 0.6))
	global_position = p
	velocity = Vector3.ZERO
	_air_peak_y = global_position.y
	if t >= 1.0:
		_enter_state(State.MOVE)
		if state == State.MOVE:
			velocity = _vault_exit_velocity
		_vault_exit_velocity = Vector3.ZERO


# ---------------------------------------------------------------- ledge grab / hang

func _try_ledge_grab() -> bool:
	if exhausted or stamina <= 1.0:
		return false
	var dir := wish_dir
	var feet := global_position
	var chest := feet + Vector3.UP * 1.3
	var hit := _ray(chest, chest + dir * 0.8)
	if hit.is_empty():
		var hip := feet + Vector3.UP * 0.8
		hit = _ray(hip, hip + dir * 0.8)
		if hit.is_empty():
			return false
	if absf(hit.normal.y) > 0.3 or not _is_climbable(hit.collider):
		return false
	var n := Vector3(hit.normal.x, 0.0, hit.normal.z).normalized()
	var ledge := _probe_ledge(hit.position, n, feet.y)
	if ledge.is_empty():
		return false
	_start_hang(hit.position, n, ledge.y)
	return true


## Finds the ledge top above a wall point. Returns {} or {"y": float}.
func _probe_ledge(wall_point: Vector3, n: Vector3, feet_y: float) -> Dictionary:
	var from := Vector3(wall_point.x, feet_y + tuning.ledge_reach + 0.25, wall_point.z) - n * 0.25
	var top := _ray(from, Vector3(from.x, feet_y + tuning.ledge_min_height - 0.1, from.z))
	if top.is_empty() or top.normal.y < 0.7:
		return {}
	var h: float = top.position.y - feet_y
	if h < tuning.ledge_min_height or h > tuning.ledge_reach + 0.25:
		return {}
	# head room above the ledge
	if not _ray(top.position + Vector3.UP * 0.05, top.position + Vector3.UP * 0.6).is_empty():
		return {}
	return {"y": top.position.y}


func _is_climbable(collider: Object) -> bool:
	if collider is Node:
		var n := collider as Node
		return n.is_in_group("climbable") or (n.get_parent() != null and n.get_parent().is_in_group("climbable"))
	return false


func _start_hang(wall_point: Vector3, n: Vector3, ledge_y: float) -> void:
	_enter_state(State.HANG)
	_set_crouch(false)
	_ledge_y = ledge_y
	_wall_normal = n
	velocity = Vector3.ZERO
	var p := Vector3(wall_point.x, ledge_y - tuning.hang_offset, wall_point.z) + n * (tuning.radius + 0.05)
	global_position = p
	facing = -n
	_air_peak_y = global_position.y
	Audio.play_at("impact", global_position, -14.0)


func _state_hang(delta: float) -> void:
	velocity = Vector3.ZERO
	_air_peak_y = global_position.y
	_jump_buffer -= delta
	use_stamina(tuning.hang_stamina_drain * delta)
	if stamina <= 0.0:
		_drop_from_ledge()
		return
	var climb_mult := data.climb_speed_mult() if data else 1.0
	# shimmy left/right along the wall
	var right := _wall_normal.cross(Vector3.UP).normalized() * -1.0
	var side := move_input.x
	if absf(side) > 0.2:
		var step := right * signf(side) * tuning.shimmy_speed * climb_mult * delta
		var probe_center := global_position + step + Vector3.UP * (tuning.hang_offset - 0.2)
		var wall := _ray(probe_center, probe_center - _wall_normal * 0.8)
		if not wall.is_empty() and _is_climbable(wall.collider):
			var ledge := _probe_ledge(wall.position, _wall_normal, global_position.y + step.y)
			if not ledge.is_empty() and absf(float(ledge.y) - _ledge_y) < 0.4:
				global_position += step
				_ledge_y = ledge.y
				_wall_normal = Vector3(wall.normal.x, 0.0, wall.normal.z).normalized()
				facing = -_wall_normal
	# pull up / drop / jump off
	var pull := _jump_buffer > 0.0 or (move_input.y < -0.6 and _state_time > 0.3)
	if pull:
		_jump_buffer = 0.0
		var top := Vector3(global_position.x, _ledge_y + 0.05, global_position.z) - _wall_normal * (tuning.radius + 0.45)
		if _fits_at(top, tuning.stand_height) and stamina >= 1.0:
			use_stamina(tuning.climb_up_stamina_cost)
			_tween_from = global_position
			_tween_to = top
			_tween_peak = top.y
			_tween_time = 0.0
			_tween_dur = tuning.climb_up_duration / maxf(climb_mult, 0.2)
			_vault_exit_velocity = Vector3.ZERO
			_enter_state(State.CLIMB_UP)
			Audio.play_at("jump", global_position, -12.0)
		elif move_input.y > 0.5:
			_wall_jump_off()
		return
	if pressed("crouch"):
		_drop_from_ledge()


func _drop_from_ledge() -> void:
	_enter_state(State.MOVE)
	_grab_cooldown = 0.45
	velocity = _wall_normal * 1.0
	_air_peak_y = global_position.y


func _wall_jump_off() -> void:
	_enter_state(State.MOVE)
	_grab_cooldown = 0.4
	velocity = _wall_normal * tuning.wall_jump_push
	velocity.y = _jump_velocity() * 0.85


# ---------------------------------------------------------------- wall-run

func _try_wallrun() -> bool:
	if exhausted or stamina < 5.0 or not (input_enabled and Input.is_action_pressed("sprint")):
		return false
	var hvel := Vector3(velocity.x, 0.0, velocity.z)
	if hvel.length() < tuning.wallrun_min_speed:
		return false
	var dir := hvel.normalized()
	var right := dir.cross(Vector3.UP).normalized()
	var origin := global_position + Vector3.UP * 1.0
	for side in [-1.0, 1.0]:
		var hit := _ray(origin, origin + right * side * 0.95)
		if hit.is_empty() or absf(hit.normal.y) > 0.3:
			continue
		var c: Object = hit.collider
		if not (c is Node and ((c as Node).is_in_group("runnable"))):
			continue
		var n := Vector3(hit.normal.x, 0.0, hit.normal.z).normalized()
		if n.dot(_last_wallrun_normal) > 0.9:
			continue
		var along := (dir - n * dir.dot(n)).normalized()
		if along.length() < 0.5:
			continue
		_wallrun_dir = along
		_wallrun_normal = n
		_wallrun_side = side
		_last_wallrun_normal = n
		velocity.y = maxf(velocity.y, 2.0)
		_enter_state(State.WALLRUN)
		return true
	return false


func _state_wallrun(delta: float) -> void:
	use_stamina(tuning.wallrun_stamina_drain * delta)
	_jump_buffer -= delta
	var s := tuning.wallrun_speed * movement_multiplier()
	velocity.x = _wallrun_dir.x * s - _wallrun_normal.x * 1.5
	velocity.z = _wallrun_dir.z * s - _wallrun_normal.z * 1.5
	velocity.y -= tuning.gravity * tuning.wallrun_gravity_scale * delta
	_air_peak_y = global_position.y
	facing = _wallrun_dir
	move_and_slide()
	if _jump_buffer > 0.0:
		_jump_buffer = 0.0
		_enter_state(State.MOVE)
		velocity = _wallrun_normal * tuning.wall_jump_push + _wallrun_dir * s * 0.8
		velocity.y = _jump_velocity()
		return
	var origin := global_position + Vector3.UP * 1.0
	var still := _ray(origin, origin - _wallrun_normal * 1.0)
	var released := not (input_enabled and Input.is_action_pressed("sprint")) or move_input.y > 0.3
	if is_on_floor() or still.is_empty() or _state_time >= tuning.wallrun_duration or stamina <= 0.0 or released:
		_enter_state(State.MOVE)


# =====================================================================
# Helpers
# =====================================================================

func _set_crouch(on: bool) -> void:
	if crouching == on:
		return
	crouching = on
	var cap := collision.shape as CapsuleShape3D
	cap.height = tuning.crouch_height if on else tuning.stand_height
	collision.position.y = cap.height * 0.5


func _can_stand() -> bool:
	return _fits_at(global_position, tuning.stand_height)


func _fits_at(feet: Vector3, height: float) -> bool:
	var shape := CapsuleShape3D.new()
	shape.radius = tuning.radius - 0.03
	shape.height = height - 0.05
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.transform = Transform3D(Basis(), feet + Vector3.UP * (height * 0.5 + 0.04))
	q.collision_mask = Geo.LAYER_WORLD
	q.exclude = [get_rid()]
	return _space().intersect_shape(q, 1).is_empty()


func use_stamina(amount: float) -> void:
	if amount <= 0.0:
		return
	stamina = maxf(stamina - amount, 0.0)
	_stamina_regen_wait = tuning.regen_delay
	if stamina <= 0.0:
		exhausted = true


func _update_stamina(delta: float) -> void:
	var before := stamina
	var draining := false
	if state == State.MOVE and sprinting and is_on_floor() and Vector3(velocity.x, 0, velocity.z).length() > tuning.run_speed * 0.9:
		use_stamina(tuning.sprint_drain * delta)
		draining = true
	if state in [State.HANG, State.WALLRUN, State.CLIMB_UP]:
		draining = true
	if not draining:
		_stamina_regen_wait -= delta
		if _stamina_regen_wait <= 0.0:
			stamina = minf(stamina + tuning.regen_rate * delta, max_stamina)
	if exhausted and stamina >= tuning.exhausted_recover:
		exhausted = false
	if not is_equal_approx(before, stamina):
		Events.stamina_changed.emit(stamina, max_stamina)


func _update_landing() -> void:
	var on_floor := is_on_floor()
	if state != State.MOVE and state != State.SLIDE and state != State.ROLL and state != State.USING:
		_was_on_floor = false
		return
	if not on_floor:
		_air_peak_y = maxf(_air_peak_y, global_position.y)
	elif not _was_on_floor:
		var drop := _air_peak_y - global_position.y
		_on_landed(drop)
	if on_floor:
		_air_peak_y = global_position.y
	_was_on_floor = on_floor


func _on_landed(drop: float) -> void:
	if drop >= tuning.hard_landing_height:
		emit_noise(tuning.noise_land * clampf(drop / 6.0, 0.6, 1.5), "land")
		Audio.play_at("land", global_position, -4.0)
		camera_rig.shake(clampf(drop / 10.0, 0.1, 1.0))
	if in_volume("water") and water_depth() > 1.0:
		return
	if drop >= tuning.fall_death_height:
		take_damage(99999.0, "fell to their death")
	elif drop > tuning.fall_damage_height:
		var t := (drop - tuning.fall_damage_height) / (tuning.fall_death_height - tuning.fall_damage_height)
		take_damage(lerpf(10.0, 95.0, t), "fell to their death")


func _update_footsteps(delta: float) -> void:
	if state != State.MOVE or not is_on_floor():
		return
	var hs := Vector2(velocity.x, velocity.z).length()
	if hs < 0.5:
		return
	_stride += hs * delta
	var stride := tuning.stride_length * (0.75 if crouching else 1.0)
	if _stride < stride:
		return
	_stride = 0.0
	var radius := tuning.noise_walk
	if hs > tuning.run_speed * 1.1:
		radius = tuning.noise_sprint
	elif hs > tuning.walk_speed * 1.2:
		radius = tuning.noise_run
	if crouching:
		radius = 0.0
	var mult := data.footstep_noise_mult() if data else 1.0
	if radius > 0.0:
		emit_noise(radius * mult, "footstep")
	var vol := -22.0 + (6.0 if mult > 1.0 else 0.0) + (4.0 if hs > tuning.run_speed else 0.0) - (8.0 if crouching else 0.0)
	Audio.play_at(_surface_sound(), global_position, vol, 25.0, 0.15)


func _surface_sound() -> String:
	var c := get_last_slide_collision()
	if c and c.get_collider() is Node:
		var n := c.get_collider() as Node
		for s in ["wood", "metal", "stone", "sand"]:
			if n.is_in_group("surface_" + s):
				return "footstep_" + s
	return "footstep_dirt"


func emit_noise(radius: float, kind: String) -> void:
	Events.sound_emitted.emit(global_position, radius, kind)


func _update_visuals(delta: float) -> void:
	var hvel := Vector3(velocity.x, 0.0, velocity.z)
	if aiming:
		facing = camera_rig.forward()
		facing.y = 0.0
		facing = facing.normalized()
	elif state == State.MOVE and hvel.length() > 0.3:
		facing = hvel.normalized()
	elif state in [State.SLIDE, State.ROLL]:
		facing = _slide_dir
	if facing.length_squared() > 0.01:
		var target_yaw := atan2(-facing.x, -facing.z)
		model.rotation.y = lerp_angle(model.rotation.y, target_yaw, clampf(tuning.turn_speed * delta, 0.0, 1.0))
	var pose := "move"
	match state:
		State.MOVE, State.USING:
			pose = "crouch" if crouching else ("move" if is_on_floor() else "air")
			if aiming:
				pose = "aim"
		State.SLIDE: pose = "slide"
		State.VAULT: pose = "vault"
		State.HANG: pose = "hang"
		State.CLIMB_UP: pose = "climb"
		State.WALLRUN: pose = "wallrun"
		State.ROLL: pose = "roll"
	model.set_pose(pose, hvel.length(), delta, _wallrun_side if state == State.WALLRUN else 0.0)
	camera_rig.sprint_kick = tuning.fov_sprint_kick if (sprinting and hvel.length() > tuning.run_speed) or state == State.WALLRUN or state == State.SLIDE else 0.0
	camera_rig.aiming = aiming


# =====================================================================
# Environment volumes (water, tall grass, shelter, station...)
# =====================================================================

func enter_volume(kind: String, area: Node) -> void:
	var list: Array = _volumes.get(kind, [])
	if not list.has(area):
		list.append(area)
	_volumes[kind] = list


func exit_volume(kind: String, area: Node) -> void:
	var list: Array = _volumes.get(kind, [])
	list.erase(area)
	_volumes[kind] = list


func in_volume(kind: String) -> bool:
	var list: Array = _volumes.get(kind, [])
	for a in list:
		if is_instance_valid(a):
			return true
	return false


func volumes_of(kind: String) -> Array:
	var out: Array = []
	for a in _volumes.get(kind, []):
		if is_instance_valid(a):
			out.append(a)
	return out


func water_depth() -> float:
	var depth := 0.0
	for w in volumes_of("water"):
		if w.has_method("surface_y"):
			depth = maxf(depth, float(w.surface_y()) - global_position.y)
	return depth


func _point_in_water(p: Vector3) -> bool:
	for w in get_tree().get_nodes_in_group("water"):
		if w.has_method("contains_point") and w.contains_point(p):
			return true
	return false


func _update_water(delta: float) -> void:
	if not in_volume("water"):
		_breath = minf(_breath + delta * 2.0, 4.0)
		return
	if water_depth() > tuning.stand_height + 0.1:
		_breath -= delta
		if _breath <= 0.0:
			_drown_tick -= delta
			if _drown_tick <= 0.0:
				_drown_tick = 1.0
				take_damage(10.0, "drowned in a flash flood")
	else:
		_breath = minf(_breath + delta, 4.0)


func is_sheltered() -> bool:
	return in_volume("shelter") or in_volume("station")


func is_hidden_in_grass() -> bool:
	return in_volume("tall_grass") and crouching


# =====================================================================
# Health
# =====================================================================

func is_dead() -> bool:
	return state == State.DEAD


func take_damage(amount: float, cause: String, _from: Vector3 = Vector3.INF) -> void:
	if state == State.DEAD or data == null:
		return
	if Game.god_mode and amount < 99999.0:
		return
	if Game.god_mode:
		return
	if invulnerable_timer > 0.0 and amount < 99999.0:
		return
	data.hp = maxf(data.hp - amount, 0.0)
	Events.courier_damaged.emit(amount, cause)
	Events.health_changed.emit(data.hp, data.max_hp)
	camera_rig.shake(clampf(amount / 40.0, 0.15, 1.0))
	Audio.play("hurt", -6.0)
	if data.hp <= 0.0:
		die(cause)


func heal(amount: float) -> void:
	if data == null or state == State.DEAD:
		return
	data.hp = minf(data.hp + amount, data.max_hp)
	Events.courier_healed.emit(amount)
	Events.health_changed.emit(data.hp, data.max_hp)


## Starts a timed action (bandaging). The callback runs if not interrupted.
func begin_use(duration: float, callback: Callable) -> bool:
	if state != State.MOVE or not is_on_floor():
		return false
	_use_time = duration
	_use_callback = callback
	_enter_state(State.USING)
	return true


func interrupt_use() -> void:
	if state == State.USING:
		_use_callback = Callable()
		_enter_state(State.MOVE)


func die(cause: String) -> void:
	if state == State.DEAD:
		return
	_enter_state(State.DEAD)
	_set_crouch(false)
	input_enabled = false
	aiming = false
	if data:
		data.hp = 0.0
	Events.health_changed.emit(0.0, data.max_hp if data else 100.0)
	Events.courier_died.emit(cause)


func shift_origin(delta: Vector3) -> void:
	global_position += delta
	_air_peak_y += delta.y
	_tween_from += delta
	_tween_to += delta
	scent.shift(delta)
	camera_rig.global_position += delta
