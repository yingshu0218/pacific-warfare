extends Node3D
## Isolated art viewer, not a battle scenario.
const MODELS: Array[PackedScene]=[
	preload("res://aircraft/us_archive/f4u1a.tscn"),
	preload("res://aircraft/us_archive/p38j.tscn")]
const VIEWS: Array[Vector3]=[Vector3(12,6.5,-17),Vector3(20,.35,0),Vector3(0,23,-.002),Vector3(-12,7,17)]
@onready var camera: Camera3D=$Camera
@onready var caption: Label=$UI/Caption
var model: Node3D
var view: int=0

func _ready() -> void:
	select_model(0)

func select_model(index: int) -> void:
	if model!=null:
		remove_child(model)
		model.queue_free()
	model=MODELS[index].instantiate() as Node3D
	add_child(model)
	caption.text="%s\n1 Corsair  |  2 Lightning  |  V view  |  exterior only" % model.LABEL
	frame()

func frame() -> void:
	camera.size=float(model.SPAN_M)*1.12
	camera.look_at_from_position(VIEWS[view],Vector3.ZERO,Vector3.FORWARD if view==2 else Vector3.UP)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode==KEY_1: select_model(0)
	elif event.keycode==KEY_2:select_model(1)
	elif event.keycode==KEY_V:
		view=(view+1)%VIEWS.size()
		frame()
