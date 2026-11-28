extends MeshInstance3D

## Pure presentation. Occupies a finite horizontal layer rather than the sky dome.
const BASE_M := 1050.0
const TOP_M := 2600.0
const HALF_EXTENT_M := 45000.0
const WIND_MPS := Vector2(6.3, 4.0)

## Set before adding this node to the environment.
@export var base_m: float = BASE_M
@export var top_m: float = TOP_M
@export var cloud_reach_m: float = 22000.0
@export var footprint_scale: float = 1.0
@export var density_gain: float = 1.0

static var _cloud_detail: NoiseTexture3D
var cloud_material: ShaderMaterial
var visual_time_s: float = 0.0

func _ready() -> void:
	name = "QingjiaCloudLayer"
	var volume := BoxMesh.new()
	volume.size = Vector3(HALF_EXTENT_M * 2.0, maxf(400.0,top_m - base_m), HALF_EXTENT_M * 2.0)
	mesh = volume
	position.y = base_m + volume.size.y * 0.5
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	cloud_material = ShaderMaterial.new()
	cloud_material.shader = preload("res://scripts/qingjia/cloud_layer.gdshader")
	cloud_material.set_shader_parameter("cloud_detail", _shared_noise())
	cloud_material.set_shader_parameter("cloud_bottom", base_m)
	cloud_material.set_shader_parameter("cloud_top", base_m + volume.size.y)
	cloud_material.set_shader_parameter("cloud_extent", HALF_EXTENT_M)
	cloud_material.set_shader_parameter("wind_mps", WIND_MPS)
	cloud_material.set_shader_parameter("cloud_reach_m", clampf(cloud_reach_m,8000.0,32000.0))
	cloud_material.set_shader_parameter("footprint_scale", clampf(footprint_scale,0.55,1.3))
	cloud_material.set_shader_parameter("density_gain", clampf(density_gain,0.15,1.3))
	material_override = cloud_material

static func _shared_noise() -> NoiseTexture3D:
	if _cloud_detail != null: return _cloud_detail
	var fbm := FastNoiseLite.new()
	fbm.seed = 80125
	fbm.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	fbm.frequency = 0.088
	fbm.fractal_octaves = 3
	_cloud_detail = NoiseTexture3D.new()
	_cloud_detail.width = 64
	_cloud_detail.height = 64
	_cloud_detail.depth = 64
	_cloud_detail.seamless = true
	_cloud_detail.noise = fbm
	return _cloud_detail

func advance(time_s: float) -> void:
	if time_s == visual_time_s: return
	visual_time_s = time_s
	cloud_material.set_shader_parameter("scene_time", time_s)
