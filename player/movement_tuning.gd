class_name MovementTuning
extends Resource
## Every movement number of the courier. Edit res://player/movement_tuning.tres.

@export_group("Speeds (m/s)")
@export var walk_speed: float = 4.0
@export var run_speed: float = 7.0
@export var sprint_speed: float = 10.0
@export var crouch_speed: float = 2.6
@export var exhausted_speed: float = 4.0
## Stick deflection below this walks instead of runs.
@export var walk_stick_threshold: float = 0.55
@export var ground_accel: float = 45.0
@export var ground_decel: float = 38.0
@export var air_accel: float = 9.0
@export var turn_speed: float = 12.0

@export_group("Jump & gravity")
@export var gravity: float = 22.0
@export var jump_height: float = 1.4
@export var coyote_time: float = 0.12
@export var jump_buffer: float = 0.12
@export var max_fall_speed: float = 45.0

@export_group("Slide")
@export var slide_duration: float = 1.0
@export var slide_min_speed: float = 8.0
@export var slide_start_speed: float = 11.5
@export var slide_friction: float = 5.5

@export_group("Vault")
@export var vault_min_height: float = 0.2
@export var vault_max_height: float = 1.2
@export var vault_min_speed: float = 3.0
@export var vault_duration: float = 0.36
@export var vault_probe_distance: float = 0.85

@export_group("Climb")
## Highest ledge (above the feet) that can be grabbed.
@export var ledge_reach: float = 2.2
@export var ledge_min_height: float = 0.95
@export var hang_offset: float = 1.75
@export var shimmy_speed: float = 1.5
@export var climb_up_duration: float = 0.55
@export var hang_stamina_drain: float = 7.0
@export var climb_up_stamina_cost: float = 8.0

@export_group("Wall-run")
@export var wallrun_duration: float = 1.2
@export var wallrun_speed: float = 9.5
@export var wallrun_min_speed: float = 5.0
@export var wallrun_gravity_scale: float = 0.15
@export var wallrun_stamina_drain: float = 22.0
@export var wall_jump_push: float = 6.5

@export_group("Dodge roll")
@export var roll_duration: float = 0.45
@export var roll_speed: float = 9.0
@export var roll_iframes: float = 0.3
@export var roll_stamina_cost: float = 20.0

@export_group("Stamina")
@export var max_stamina: float = 100.0
@export var sprint_drain: float = 16.0
@export var regen_rate: float = 24.0
@export var regen_delay: float = 0.7
## After hitting 0, sprint/climb unlock again at this value.
@export var exhausted_recover: float = 25.0

@export_group("Falling")
@export var fall_damage_height: float = 6.0
@export var fall_death_height: float = 15.0
@export var hard_landing_height: float = 3.0

@export_group("Body")
@export var stand_height: float = 1.8
@export var crouch_height: float = 1.0
@export var radius: float = 0.35

@export_group("Noise (sound radius, m)")
@export var noise_walk: float = 3.0
@export var noise_run: float = 7.0
@export var noise_sprint: float = 13.0
@export var noise_land: float = 15.0
@export var stride_length: float = 1.6

@export_group("Camera")
@export var fov_sprint_kick: float = 8.0
