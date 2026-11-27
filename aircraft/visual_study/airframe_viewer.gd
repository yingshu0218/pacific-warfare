extends Node3D

@export var aircraft_label: String = "TBM-1C   |   Visual study · 1944"

var _camera: Camera3D
var _label: Label


func _ready() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("203444")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("a9bdd0")
	environment.ambient_light_energy = 0.72
	world.environment = environment
	add_child(world)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-50, -35, 0)
	key.light_energy = 1.2
	add_child(key)
	_camera = Camera3D.new()
	_camera.current = true
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = 15.0
	add_child(_camera)
	var ui := CanvasLayer.new()
	add_child(ui)
	_label = Label.new()
	_label.position = Vector2(22, 17)
	_label.add_theme_font_size_override("font_size", 24)
	ui.add_child(_label)
	_set_view(1)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo:
		if key.keycode == KEY_1:
			_set_view(1)
		elif key.keycode == KEY_2:
			_set_view(2)
		elif key.keycode == KEY_3:
			_set_view(3)


func _set_view(view: int) -> void:
	match view:
		2:
			_camera.look_at_from_position(Vector3(22, 0.4, 0), Vector3(0, 0.4, 0))
		3:
			_camera.look_at_from_position(Vector3(0, 24, 0), Vector3.ZERO, Vector3.FORWARD)
		_:
			_camera.look_at_from_position(Vector3(12, 9, -17), Vector3.ZERO)
	_label.text = aircraft_label + "\n1 Quarter    2 Side    3 Plan"
