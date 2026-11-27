extends Node3D
## Independent read-only map inspector. No shared Session, units, or combat systems.
const DATA: Script=preload("res://scripts/map02/expanded_map_data.gd")
const VIEW: Script=preload("res://scripts/map02/expanded_map_view.gd")
const SUPPORT_PROPS: Script=preload("res://scripts/map02/harbor_support_props.gd")
@export var gallery_mode: bool=false
var terrain: Dictionary={}
var regions: Dictionary={}
var map_view: IslandHarborView
var camera: ObserverCamera
var ui: CanvasLayer
var selector: OptionButton
var heading: Label
var caption: Label
var points: Array[Dictionary]=[]
var preview_time_s: float=0.0
var paused: bool=false

func _ready() -> void:
	_environment()
	camera=ObserverCamera.new();add_child(camera)
	regions=DATA.regions()
	if gallery_mode:_gallery()
	else:
		terrain=DATA.compile()
		map_view=VIEW.new();add_child(map_view);map_view.build(terrain)
		camera.terrain=terrain
		for p: Dictionary in terrain.source.viewpoints:points.append(p)
		if str(terrain.source.id) == "island_harbor_expanded":
			points.append_array(SUPPORT_PROPS.INSPECTION_POINTS)
	camera.mode="free"
	_ui()
	select_point(0)

func _process(dt: float) -> void:
	if not paused:preview_time_s+=dt
	set_preview_time(preview_time_s)
	camera.update_view(dt,preview_time_s,{},paused)

func set_preview_time(value: float) -> void:
	preview_time_s=value
	if not gallery_mode:
		map_view.advance(value)
		var water: MeshInstance3D=get_node("Map02Water") as MeshInstance3D
		(water.material_override as ShaderMaterial).set_shader_parameter("simulation_time",value)

func _environment() -> void:
	var env: WorldEnvironment=WorldEnvironment.new()
	var e: Environment=Environment.new()
	var sky: Sky=Sky.new();var material: ProceduralSkyMaterial=ProceduralSkyMaterial.new()
	material.sky_top_color=Color("5b92b5");material.sky_horizon_color=Color("b5d0d8");material.ground_horizon_color=Color("b5d0d8")
	sky.sky_material=material;e.background_mode=Environment.BG_SKY;e.sky=sky
	e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;e.ambient_light_color=Color("a7c0cd");e.ambient_light_energy=.75
	e.tonemap_mode=Environment.TONE_MAPPER_LINEAR
	e.fog_enabled=not gallery_mode;e.fog_light_color=Color("aac5cc");e.fog_density=.000012;e.fog_sky_affect=0.0
	env.environment=e;add_child(env)
	var sun: DirectionalLight3D=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-35,-45,0);sun.light_color=Color("fff0d4");sun.light_energy=1.15
	sun.shadow_enabled=true;sun.shadow_bias=.08;sun.shadow_normal_bias=1.5;sun.directional_shadow_max_distance=1500;add_child(sun)
	var plane: PlaneMesh=PlaneMesh.new();plane.size=Vector2(120000,120000)
	var surface: MeshInstance3D=MeshInstance3D.new();surface.mesh=plane;surface.name="Map02Water"
	surface.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if gallery_mode:
		plane.size=Vector2(1600,1300)
		var mat: StandardMaterial3D=StandardMaterial3D.new();mat.albedo_color=Color("9a9f98");mat.roughness=1
		surface.material_override=mat;surface.position.y=-.015
	else:
		var mat: ShaderMaterial=ShaderMaterial.new();mat.shader=preload("res://scripts/presentation/ocean.gdshader");surface.material_override=mat
	add_child(surface)

func _gallery() -> void:
	var library: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/map02/facility_modules.json")).modules
	var objects: Array=[]
	var index: int=0
	for id: String in library:
		var x: float=(index%4-1.5)*180;var z: float=(floori(index/4.0)-1.0)*210
		var max_size: float=70.0
		for part: Dictionary in library[id].parts:
			var p: Vector3=SimData.vec3(part.position_m)+Vector3(x,0,z)
			objects.append({"id":id+"_"+part.id,"kind":"map02_structure","position_m":SimData.array3(p),"size_m":part.size_m,"color":part.color,"map02_shape":part.shape})
			max_size=maxf(max_size,SimData.vec3(part.size_m).length())
		points.append({"id":id,"label":library[id].label,"focus_m":[x,12,z],"distance_m":max_size*2.1,"yaw_rad":.7,"pitch_rad":.38})
		index+=1
	var source: Dictionary={"id":"map02_module_gallery","sea_level_m":0,"bounds_m":[-800,-800,1600,1600],"islands":[],"pads":[],"objects":objects,"roads":[],"deployment_sites":[],"viewpoints":[]}
	var compiled: Dictionary=TerrainQueries.compile(source)
	map_view=VIEW.new();add_child(map_view)
	# Empty shore/vegetation do not need rendering. Use just the same module builder.
	map_view.terrain=compiled
	map_view._surface=SurfaceTool.new();map_view._surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for obj: Dictionary in compiled.source.objects:map_view._object(obj)
	map_view._surface.generate_normals()
	var material: StandardMaterial3D=StandardMaterial3D.new();material.vertex_color_use_as_albedo=true;material.roughness=.93;material.cull_mode=BaseMaterial3D.CULL_DISABLED
	map_view._add_mesh(map_view._surface.commit(),material,"Map02Modules")
	map_view.statistics={"static_triangles":map_view._triangles,"mesh_instances":1,"nodes":2,"materials":1}
	points.push_front({"id":"gallery","label":"设施模块总览","focus_m":[0,0,0],"distance_m":1000,"yaw_rad":.15,"pitch_rad":1.0})

func _ui() -> void:
	ui=CanvasLayer.new();add_child(ui)
	var root: Control=Control.new();root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.mouse_filter=Control.MOUSE_FILTER_IGNORE;ui.add_child(root)
	var theme: Theme=Theme.new();theme.default_font=preload("res://assets/fonts/NotoSansCJKsc-Regular.otf");theme.default_font_size=17;root.theme=theme
	var panel: PanelContainer=PanelContainer.new();panel.position=Vector2(22,18);root.add_child(panel)
	var style: StyleBoxFlat=StyleBoxFlat.new();style.bg_color=Color(.035,.075,.095,.91);style.set_content_margin_all(14);style.set_corner_radius_all(8);panel.add_theme_stylebox_override("panel",style)
	var box: VBoxContainer=VBoxContainer.new();panel.add_child(box)
	heading=Label.new();heading.text="MAP02 · 设施模块" if gallery_mode else "青岬群岛 · 港湾扩展";heading.add_theme_font_size_override("font_size",25);box.add_child(heading)
	caption=Label.new();caption.text="模块几何检视" if gallery_mode else "地图检视 · 阵地未装炮 · 起降作业待接入";box.add_child(caption)
	selector=OptionButton.new();box.add_child(selector)
	for p: Dictionary in points:selector.add_item(str(p.label))
	selector.item_selected.connect(select_point)
	var row: HBoxContainer=HBoxContainer.new();box.add_child(row)
	var pause: Button=Button.new();pause.text="暂停海面";row.add_child(pause);pause.pressed.connect(func() -> void:paused=not paused;pause.text="继续海面" if paused else "暂停海面")
	var hide_ui: Button=Button.new();hide_ui.text="收起面板 (H)";row.add_child(hide_ui);hide_ui.pressed.connect(func() -> void:ui.visible=false)
	var help: Label=Label.new();help.text="右键环绕 / 滚轮缩放 / Shift+WASD移动\nH 显隐面板 · 1–9 区域定位";box.add_child(help)

func select_point(index: int) -> void:
	if index<0 or index>=points.size():return
	var point: Dictionary=points[index].duplicate(true)
	if not terrain.is_empty():
		var focus: Vector3=SimData.vec3(point.focus_m)
		focus.y=maxf(focus.y,TerrainQueries.height_data(terrain,focus,true)+2.0)
		point.focus_m=SimData.array3(focus)
	camera.locate_map(point);camera.mode="free"
	camera.update_view(0,preview_time_s,{},true)
	if selector!=null:selector.select(index)
	if caption!=null:caption.text=str(point.label)+( " · 模块检视" if gallery_mode else " · 空阵地/静态设施")

func _unhandled_input(event: InputEvent) -> void:
	camera.handle_input(event)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode==KEY_H:ui.visible=not ui.visible
		elif event.physical_keycode>=KEY_1 and event.physical_keycode<=KEY_9:select_point(event.physical_keycode-KEY_1)
