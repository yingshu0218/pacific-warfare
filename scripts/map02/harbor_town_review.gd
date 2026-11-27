extends Node3D

const DATA: Script = preload("res://scripts/map02/expanded_map_data.gd")
const VIEW: Script = preload("res://scripts/map02/expanded_map_view.gd")
const VIEWS: Array[Dictionary] = [
	{"label":"01  总览：内湾、船厂与西侧小镇","focus":Vector3(2810,30,-4390),"eye":Vector3(1010,1890,1460),"fov":54.0},
	{"label":"02  海面：渡口与港镇的层次","focus":Vector3(2350,43,-4860),"eye":Vector3(-390,72,585),"fov":43.0},
	{"label":"03  坡上：住宅顺坡布置","focus":Vector3(2154,59,-5140),"eye":Vector3(-202,90,-225),"fov":49.0},
	{"label":"04  主街：沿港镇中心看向船厂","focus":Vector3(2255,51,-4915),"eye":Vector3(-206,40,90),"fov":58.0},
]
var chart: Dictionary
var town: Node3D
var map_view: Node3D
var camera: Camera3D
var stage: CloudSeaEnvironment
var overlay: CanvasLayer
var selector: OptionButton
var selected: int = -1

func _ready() -> void:
	chart=DATA.compile()
	stage=CloudSeaEnvironment.new()
	add_child(stage)
	stage.set_terrain(chart)
	map_view=VIEW.new()
	add_child(map_view)
	map_view.build(chart)
	town=map_view.get_node("HarborTown")
	camera=Camera3D.new()
	camera.current=true
	camera.far=70000.0
	add_child(camera)
	_menu()
	select_view(0)

func select_view(index: int) -> void:
	if index < 0 or index >= VIEWS.size(): return
	var view: Dictionary=VIEWS[index]
	camera.fov=view.fov
	camera.near=maxf(.6,(view.eye as Vector3).length()*.012)
	camera.position=(view.focus as Vector3)+(view.eye as Vector3)
	camera.look_at(view.focus)
	stage.update_observer(camera.position)
	selected=index
	selector.select(index)

func _menu() -> void:
	overlay=CanvasLayer.new()
	add_child(overlay)
	var box: PanelContainer=PanelContainer.new()
	box.position=Vector2(24,20)
	overlay.add_child(box)
	var sty: StyleBoxFlat=StyleBoxFlat.new()
	sty.bg_color=Color("#142a34e8")
	sty.set_corner_radius_all(7)
	sty.set_content_margin_all(14)
	box.add_theme_stylebox_override("panel",sty)
	var col: VBoxContainer=VBoxContainer.new()
	box.add_child(col)
	var font: Font=preload("res://assets/fonts/NotoSansCJKsc-Regular.otf")
	var theme_value: Theme=Theme.new()
	theme_value.default_font=font
	theme_value.default_font_size=17
	box.theme=theme_value
	var title: Label=Label.new()
	title.text="青岬港城 · 场景检视"
	title.add_theme_font_size_override("font_size",24)
	col.add_child(title)
	selector=OptionButton.new()
	for view: Dictionary in VIEWS: selector.add_item(view.label)
	selector.item_selected.connect(select_view)
	col.add_child(selector)
	var labels: Label=Label.new()
	labels.text="1–4 切换视角   H 显隐面板"
	col.add_child(labels)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	var code: Key=(event as InputEventKey).physical_keycode
	if code==KEY_H: overlay.visible=not overlay.visible
	elif code>=KEY_1 and code<=KEY_4: select_view(code-KEY_1)
