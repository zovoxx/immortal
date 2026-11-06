class_name EnvironmentController
extends Node
## Sky, sun, fog and exposure: blends the biome palette, the day/night cycle (Game.time_of_day),
## storm/dust intensity (set by the WeatherManager) and Night-eyed vision.

@export var palette_blend_speed: float = 0.4

var world_env: WorldEnvironment
var env: Environment
var sun: DirectionalLight3D
var moon: DirectionalLight3D
var sky_mat: ProceduralSkyMaterial
var camera: Camera3D
var courier: Node

var biome: Biome
var storm_intensity: float = 0.0   # 0..1, set by weather
var dust_intensity: float = 0.0    # 0..1
var lightning_flash: float = 0.0   # decays

var _fog: Color = Color(0.6, 0.6, 0.6)
var _sky_top: Color
var _sky_hor: Color
var _ground: Color
var _sun_col: Color = Color.WHITE
var _sun_energy: float = 1.0
var _fog_density: float = 0.012
var _ambient: float = 0.6
var _glare: float = 1.0
var _cam_attr: CameraAttributesPractical


func _ready() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky_mat = ProceduralSkyMaterial.new()
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_sky_affect = 0.85
	env.volumetric_fog_density = 0.01
	env.glow_intensity = 0.6
	env.glow_bloom = 0.05
	env.ssao_radius = 1.2
	world_env = WorldEnvironment.new()
	world_env.environment = env
	_cam_attr = CameraAttributesPractical.new()
	world_env.camera_attributes = _cam_attr
	add_child(world_env)
	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	add_child(sun)
	moon = DirectionalLight3D.new()
	moon.name = "Moon"
	moon.light_color = Color(0.55, 0.62, 0.85)
	moon.shadow_enabled = false
	add_child(moon)
	Settings.apply_graphics(env, sun, get_viewport())
	Settings.changed.connect(func(): Settings.apply_graphics(env, sun, get_viewport()))
	Events.lightning_strike.connect(func(_p): lightning_flash = 1.0)
	if biome == null:
		set_biome(BiomeDB.get_biome(0), true)


func set_biome(b: Biome, instant: bool = false) -> void:
	if b == null:
		return
	biome = b
	if instant:
		_fog = b.fog_color
		_sky_top = b.sky_top
		_sky_hor = b.sky_horizon
		_ground = b.ground_color
		_sun_col = b.sun_color
		_sun_energy = b.sun_energy
		_fog_density = b.fog_density
		_ambient = b.ambient_energy
		_glare = b.glare


func _process(delta: float) -> void:
	if biome == null:
		return
	var k := clampf(delta * palette_blend_speed, 0.0, 1.0)
	_fog = _fog.lerp(biome.fog_color, k)
	_sky_top = _sky_top.lerp(biome.sky_top, k)
	_sky_hor = _sky_hor.lerp(biome.sky_horizon, k)
	_ground = _ground.lerp(biome.ground_color, k)
	_sun_col = _sun_col.lerp(biome.sun_color, k)
	_sun_energy = lerpf(_sun_energy, biome.sun_energy, k)
	_fog_density = lerpf(_fog_density, biome.fog_density, k)
	_ambient = lerpf(_ambient, biome.ambient_energy, k)
	_glare = lerpf(_glare, biome.glare, k)
	lightning_flash = maxf(lightning_flash - delta * 3.0, 0.0)

	var t := Game.time_of_day
	var night := Game.night_factor()
	var day := 1.0 - night
	# sun arc: rises at 0.25, noon at 0.5, sets at 0.75
	var sun_angle := (t - 0.25) * TAU
	sun.rotation = Vector3(-sin(sun_angle) * PI * 0.5 - 0.05, deg_to_rad(30.0), 0)
	moon.rotation = Vector3(-0.9, deg_to_rad(-150.0), 0)
	var dusk := clampf(1.0 - absf(sin(sun_angle)) * 3.0, 0.0, 1.0) * day
	var storm := clampf(storm_intensity + dust_intensity * 0.8, 0.0, 1.0)
	var night_eyed := courier != null and is_instance_valid(courier) and courier.get("data") != null and (courier.data as CourierData).night_vision()

	sun.light_color = _sun_col.lerp(Color(1.0, 0.55, 0.3), dusk * 0.7)
	sun.light_energy = _sun_energy * day * (1.0 - storm * 0.7) + lightning_flash * 3.0
	sun.visible = day > 0.02
	moon.light_energy = 0.12 + night * (0.35 if not night_eyed else 0.9)
	moon.visible = night > 0.02

	var night_sky := Color(0.03, 0.04, 0.08)
	var storm_sky := Color(0.18, 0.19, 0.22) if dust_intensity < 0.1 else Color(0.55, 0.45, 0.32)
	var top := _sky_top.lerp(night_sky, night).lerp(storm_sky, storm * 0.85)
	var hor := _sky_hor.lerp(Color(0.9, 0.5, 0.3), dusk * 0.5).lerp(night_sky * 1.5, night).lerp(storm_sky, storm * 0.8)
	sky_mat.sky_top_color = top + Color.WHITE * lightning_flash * 0.4
	sky_mat.sky_horizon_color = hor
	sky_mat.ground_horizon_color = hor
	sky_mat.ground_bottom_color = _ground.darkened(0.6)
	var fog_col := _fog.lerp(Color(0.04, 0.05, 0.08), night * 0.85).lerp(storm_sky, storm * 0.7)
	if dust_intensity > 0.05:
		fog_col = fog_col.lerp(Color(0.62, 0.52, 0.38), dust_intensity)
	env.fog_light_color = fog_col
	env.fog_density = _fog_density * (1.0 + storm_intensity * 2.5 + dust_intensity * 7.0) * (1.0 + night * 0.5)
	env.ambient_light_energy = _ambient * (0.35 + 0.65 * day) * (1.0 - storm * 0.3)
	env.ambient_light_sky_contribution = 0.8

	# Night-eyed: clear at night, blinding glare in bright sun
	var exposure := 1.0
	if night_eyed:
		exposure = lerpf(1.0 + 0.9 * _glare * day * (1.0 - storm), 1.9, night)
		env.adjustment_enabled = true
		env.adjustment_saturation = lerpf(0.75, 0.5, night)
		_cam_attr.dof_blur_far_enabled = day > 0.5 and storm < 0.5
		_cam_attr.dof_blur_far_distance = lerpf(60.0, 22.0, _glare * day)
		_cam_attr.dof_blur_amount = 0.08
		env.glow_enabled = Settings.quality != Settings.Quality.LOW
		env.glow_hdr_threshold = 0.7
	else:
		env.adjustment_enabled = false
		_cam_attr.dof_blur_far_enabled = false
		env.glow_hdr_threshold = 1.0
	env.tonemap_exposure = exposure
