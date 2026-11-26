class_name CloudSeaEnvironment
extends Node3D

## Appearance only. Water, projectiles, aircraft and intelligence use simulation data.
const WIND: Vector2 = Vector2(0.84, 0.54)
const SUN_ROTATION: Vector3 = Vector3(-35, -45, 0)
const HORIZON_COLOR: Color = Color(0.67, 0.77, 0.80)
var sky_material: ShaderMaterial
var water_material: ShaderMaterial
var world_environment: WorldEnvironment
var water: MeshInstance3D
var presentation_time_s: float = 0.0
var clouds_enabled: bool = true
var _observer_position: Vector3 = Vector3.INF

func _ready() -> void:
	name = "CloudSeaEnvironment"
	world_environment = WorldEnvironment.new()
	world_environment.name = "Daylight"
	var environment: Environment = Environment.new()
	var sky: Sky = Sky.new()
	sky_material = ShaderMaterial.new()
	sky_material.shader = preload("res://scripts/presentation/environment/daylight_sky.gdshader")
	sky_material.set_shader_parameter("cloud_noise", preload("res://scripts/presentation/environment/cloud_noise.png"))
	sky_material.set_shader_parameter("wind_direction", WIND)
	sky_material.set_shader_parameter("horizon_color", HORIZON_COLOR)
	# Fixed ambient and disabled environment reflections avoid lighting dependencies
	# on moving clouds; actual cubemap/render cost is measured, not assumed.
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	sky.sky_material = sky_material
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("a7c0cd")
	environment.ambient_light_energy = 0.75
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.fog_enabled = true
	# One distance law for all visible geometry. Finish beyond the islands but
	# before the 70km camera clip, so the plane can meet the sky without a sea-only band.
	environment.fog_mode = Environment.FOG_MODE_DEPTH
	environment.fog_light_color = HORIZON_COLOR
	environment.fog_density = 1.0
	environment.fog_depth_begin = 4000.0
	environment.fog_depth_end = 60000.0
	environment.fog_depth_curve = 1.0
	environment.fog_sky_affect = 0.0
	world_environment.environment = environment
	add_child(world_environment)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = SUN_ROTATION
	sun.light_color = Color("fff0d4")
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 1500.0
	add_child(sun)
	# Directional light emits along -Z; surface-to-sun is +Z.
	var sun_direction: Vector3 = sun.basis.z
	sky_material.set_shader_parameter("sun_direction", sun_direction)
	water = MeshInstance3D.new()
	water.name = "ContinuousSea"
	var plane: PlaneMesh = PlaneMesh.new()
	# Beyond the observer's 70km far plane in every permitted map position.
	# Distance haze reaches the sky color well before clipping.
	plane.size = Vector2(800000, 800000)
	water.mesh = plane
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	water_material = ShaderMaterial.new()
	water_material.shader = preload("res://scripts/presentation/ocean.gdshader")
	water_material.set_shader_parameter("wave_noise", preload("res://scripts/presentation/environment/wave_slopes.png"))
	water_material.set_shader_parameter("wind_direction", WIND)
	water_material.set_shader_parameter("sun_direction", sun_direction)
	water_material.set_shader_parameter("horizon_color", HORIZON_COLOR)
	water.material_override = water_material
	add_child(water)
	advance(0.0)

func advance(time_s: float) -> void:
	# Absolute simulation time freezes on pause, scales with playback, resets to 0.
	if time_s == presentation_time_s: return
	presentation_time_s = time_s
	sky_material.set_shader_parameter("simulation_time", time_s)
	water_material.set_shader_parameter("simulation_time", time_s)

func update_observer(camera_position: Vector3) -> void:
	if camera_position == _observer_position: return
	_observer_position = camera_position
	sky_material.set_shader_parameter("observer_position", camera_position)
	water_material.set_shader_parameter("observer_position", camera_position)

func set_clouds_enabled(value: bool) -> void:
	if value == clouds_enabled: return
	clouds_enabled = value
	sky_material.set_shader_parameter("clouds_enabled", value)

func snapshot() -> Dictionary:
	return {"time_s": presentation_time_s, "sky_time_s": sky_material.get_shader_parameter("simulation_time"),
		"water_time_s": water_material.get_shader_parameter("simulation_time"), "clouds_enabled": clouds_enabled,
		"children": get_child_count(), "sky_id": sky_material.get_instance_id(), "water_id": water_material.get_instance_id()}
