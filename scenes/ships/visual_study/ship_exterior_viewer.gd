extends Node3D
## Standalone inspection, no dependency on the showcase simulation.

@export var title: String = "CL-55 CLEVELAND  |  MAY 1944  |  EXTERIOR"
@export var frame_width: float = 206.0

var _camera: Camera3D
var _water: MeshInstance3D


func _ready() -> void:
	var sky := WorldEnvironment.new()
	sky.environment = Environment.new()
	sky.environment.background_mode = Environment.BG_COLOR
	sky.environment.background_color = Color("303e43")
	sky.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	sky.environment.ambient_light_color = Color("b8ccd1")
	sky.environment.ambient_light_energy = 0.74
	add_child(sky)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -35, 0)
	sun.light_energy = 1.25
	add_child(sun)
	_water = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(2500, 2500)
	_water.mesh = plane
	var water := StandardMaterial3D.new()
	water.albedo_color = Color("355660")
	water.roughness = 0.55
	_water.material_override = water
	add_child(_water)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.keep_aspect = Camera3D.KEEP_WIDTH
	_camera.size = frame_width
	_camera.current = true
	add_child(_camera)
	var hud := CanvasLayer.new()
	add_child(hud)
	var label := Label.new()
	label.position = Vector2(24, 18)
	label.add_theme_font_size_override("font_size",24)
	label.text = title + "\n1 Quarter   2 Profile   3 Plan   4 Full hull"
	hud.add_child(label)
	_set_view(1)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode >= KEY_1 and key.keycode <= KEY_4:
		_set_view(key.keycode - KEY_1 + 1)


func _set_view(mode: int) -> void:
	_water.visible = mode != 4
	match mode:
		2:
			_camera.look_at_from_position(Vector3(270,14,0),Vector3(0,14,0))
		3:
			_camera.look_at_from_position(Vector3(0,270,0),Vector3.ZERO,Vector3.RIGHT)
		4:
			_camera.look_at_from_position(Vector3(200,36,-117),Vector3(0,5,0))
		_:
			_camera.look_at_from_position(Vector3(200,89,-113),Vector3(0,10,0))
