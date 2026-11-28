extends SceneTree

const LAYER := preload("res://scripts/qingjia/cloud_layer.gd")
var failures: int = 0
var checks: int = 0

func _initialize() -> void: call_deferred("_run")

func expect(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _run() -> void:
	var layer := LAYER.new()
	layer.base_m = 850.0
	layer.top_m = 2050.0
	layer.cloud_reach_m = 18000.0
	layer.footprint_scale = 0.85
	root.add_child(layer)
	var volume: AABB = layer.mesh.get_aabb()
	expect(layer.name == "QingjiaCloudLayer", "Volume has stable scene identity")
	expect(is_equal_approx(layer.position.y + volume.position.y,850.0), "Configured bottom controls finite geometry")
	expect(is_equal_approx(layer.position.y + volume.end.y,2050.0), "Configured top controls finite geometry")
	expect(is_equal_approx(float(layer.cloud_material.get_shader_parameter("cloud_reach_m")),18000.0), "Finite ray reach uses configured distance")
	expect(is_equal_approx(float(layer.cloud_material.get_shader_parameter("footprint_scale")),0.85), "Cloud scale is scene-tunable")
	expect(layer.get_child_count() == 0, "Layer adds no actor, collider or light")
	expect(layer.gi_mode == GeometryInstance3D.GI_MODE_DISABLED and layer.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "Clouds do not drive scene lighting or shadows")
	layer.advance(60.0)
	expect(is_equal_approx(float(layer.cloud_material.get_shader_parameter("scene_time")),60.0), "Shader consumes supplied absolute time")
	layer.advance(0.0)
	expect(is_equal_approx(float(layer.cloud_material.get_shader_parameter("scene_time")),0.0), "Scene reset also resets cloud drift")
	var alternate := LAYER.new()
	root.add_child(alternate)
	alternate.advance(120.0)
	expect(is_equal_approx(float(layer.cloud_material.get_shader_parameter("scene_time")),0.0), "Each view has independent cloud time")
	alternate.free()
	layer.free()
	print("QJ03 Cloud volume: ",checks," checks, ",failures," failures")
	quit(int(failures>0))
