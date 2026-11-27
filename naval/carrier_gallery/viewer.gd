extends Node3D
const SHIPS: Array[PackedScene] = [
	preload("res://naval/carrier_gallery/enterprise.tscn"),
	preload("res://naval/carrier_gallery/independence.tscn"),
	preload("res://naval/carrier_gallery/akagi.tscn"),
	preload("res://naval/carrier_gallery/zuiho.tscn"),
	preload("res://naval/carrier_gallery/casablanca.tscn"),
	preload("res://naval/carrier_gallery/taiyo.tscn")
]
const VIEWS: Array[Vector3] = [Vector3(1,.61,-1.24),Vector3(-1,.57,.82),Vector3(0,2.1,-.012),Vector3(1,.13,.014)]
@onready var camera: Camera3D = $Camera
@onready var label: Label = $UI/Caption
var ship: Node3D
var view: int = 0

func _ready() -> void:
	select_ship(0)

func select_ship(index: int) -> void:
	if index<0 or index>=SHIPS.size(): return
	if ship != null:
		remove_child(ship)
		ship.queue_free()
	ship = SHIPS[index].instantiate() as Node3D
	add_child(ship)
	label.text = "%s · %s\n1–6 选舰   V 换视角  ·  外观检视 / 未接对局"%[ship.spec.label,ship.spec.year]
	_frame()

func _frame() -> void:
	var focus := Vector3(0,9,0)
	camera.position = focus+VIEWS[view]*260.0
	camera.size = float(ship.spec.length)*(.76 if view==2 else .83)
	camera.look_at(focus,Vector3.UP)
	if view==2: camera.rotate_object_local(Vector3.BACK,PI*.5)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode >= KEY_1 and event.keycode <= KEY_6:
		select_ship(event.keycode-KEY_1)
	elif event.keycode == KEY_V:
		view = (view+1)%VIEWS.size()
		_frame()
