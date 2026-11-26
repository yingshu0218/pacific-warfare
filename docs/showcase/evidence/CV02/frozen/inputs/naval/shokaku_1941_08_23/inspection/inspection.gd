extends Node3D
## Isolated static review, bounded auto-capture, or Chrome fixture; never root UI.
const H: Script = preload("res://naval/shokaku_1941_08_23/geometry.gd")
const G: Script = preload("res://scripts/naval/destroyers/mesh_tools.gd")
const MODEL: PackedScene = preload("res://naval/shokaku_1941_08_23/shokaku.tscn")
const FIXTURE: Script = preload("res://naval/shokaku_1941_08_23/inspection/deck_fixtures.gd")
const VIEWS: Array[Dictionary] = [
	{"id":"type89_open_module","eye":Vector3(8,5,-10),"target":Vector3(0,1.2,0),"size":9.5},
	{"id":"type89_smoke_module","eye":Vector3(9,6,-10),"target":Vector3(0,1.4,0),"size":10.0},
	{"id":"type96_module","eye":Vector3(5,3,-5),"target":Vector3(0,.7,0),"size":5.0},
	{"id":"starboard_side","eye":Vector3(350,17,0),"target":Vector3(0,14,0),"size":180.0},
	{"id":"port_side","eye":Vector3(-350,17,0),"target":Vector3(0,14,0),"size":180.0},
	{"id":"top","eye":Vector3(0,350,0),"target":Vector3.ZERO,"size":180.0},
	{"id":"starboard_bow_quarter","eye":Vector3(230,150,-270),"target":Vector3(0,13,0),"size":180.0},
	{"id":"port_stern_quarter","eye":Vector3(-220,140,260),"target":Vector3(0,13,0),"size":180.0},
	{"id":"starboard_aft_twins","eye":Vector3(57,32,74),"target":Vector3(15,13,59.5),"size":34.0},
	{"id":"downturned_funnels","eye":Vector3(54,26,-11),"target":Vector3(16,12,-12),"size":34.0},
	{"id":"bow_underdeck","eye":Vector3(32,14,-146),"target":Vector3(0,11,-113),"size":37.0},
	{"id":"stern_underdeck","eye":Vector3(-33,15,150),"target":Vector3(0,10,119),"size":37.0},
	{"id":"a6m_forward_park","eye":Vector3(-40,44,-107),"target":Vector3(-1,15.5,-79),"size":38.0},
	{"id":"a6m_actual_wheels","eye":Vector3(-12,15.5,-81),"target":Vector3(-1,15.3,-79),"size":10.5},
	{"id":"three_lifts_and_static_fit","eye":Vector3(0,350,0),"target":Vector3.ZERO,"size":180.0},
	{"id":"d4y2_dimension_proxy_only","eye":Vector3(-26,35,47),"target":Vector3(0,15.4,29),"size":24.0},
	{"id":"forward_elevator_lowered","eye":Vector3(21,39,-64),"target":Vector3(0,8,-43.5),"size":30.0},
]
var ship: Node3D
var fixtures: Node3D
var camera: Camera3D
var module: Node3D
var sea: MeshInstance3D
var label: Label
var current_view: int=6
var command_id: int=0
var frames: int=0
var output: String=""
var capture_views: PackedStringArray=[]
var shadows_disabled: bool=false

func _ready() -> void:
	var world: WorldEnvironment=WorldEnvironment.new()
	var env: Environment=Environment.new()
	env.background_mode=Environment.BG_COLOR; env.background_color=Color("91a4ae")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color=Color("edf1f1"); env.ambient_light_energy=.5
	env.tonemap_mode=Environment.TONE_MAPPER_LINEAR; world.environment=env; add_child(world)
	var sun: DirectionalLight3D=DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-48,-30,0); sun.light_energy=.95; sun.shadow_enabled=true
	sun.directional_shadow_max_distance=650; add_child(sun)
	var ocean: PlaneMesh=PlaneMesh.new(); ocean.size=Vector2(100000,100000)
	sea=MeshInstance3D.new(); sea.mesh=ocean; sea.position.y=-.02
	var material: StandardMaterial3D=G.material(Color("91a4ae"))
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED; material.disable_receive_shadows=true
	sea.material_override=material; add_child(sea)
	ship=MODEL.instantiate() as Node3D; add_child(ship)
	var hull_meshes: Array[MeshInstance3D]=[]
	H.collect_meshes(ship.modules.hull,hull_meshes,[])
	for mesh: MeshInstance3D in hull_meshes:
		var original: StandardMaterial3D=mesh.material_override as StandardMaterial3D
		var water_clip: ShaderMaterial=ShaderMaterial.new()
		water_clip.shader=preload("res://naval/shokaku_1941_08_23/inspection/waterline_clip.gdshader")
		water_clip.set_shader_parameter("surface_color",original.albedo_color)
		mesh.material_override=water_clip
	fixtures=FIXTURE.new() as Node3D; ship.add_child(fixtures)
	camera=Camera3D.new(); camera.projection=Camera3D.PROJECTION_ORTHOGONAL; camera.near=.5; camera.far=2000; camera.current=true; add_child(camera)
	var canvas: CanvasLayer=CanvasLayer.new(); add_child(canvas)
	var banner: ColorRect=ColorRect.new(); banner.color=Color(.85,.9,.92,.94); banner.size=Vector2(1440,96); canvas.add_child(banner)
	label=Label.new(); label.position=Vector2(24,17); label.add_theme_color_override("font_color",Color("1c3340")); label.add_theme_font_size_override("font_size",20); canvas.add_child(label)
	var args: PackedStringArray=OS.get_cmdline_user_args()
	for i: int in range(args.size()-1):
		if args[i]=="--capture": output=args[i+1]
		elif args[i]=="--views": capture_views=args[i+1].split(",")
	if "--no-shadows" in args: sun.shadow_enabled=false; shadows_disabled=true
	if OS.has_feature("web"): JavaScriptBridge.eval("window.CV02={commands:[],latest:{}}",true)
	_set_view(current_view)
	if not output.is_empty(): call_deferred("_capture")

func _set_view(index: int) -> void:
	current_view=posmod(index,VIEWS.size())
	var view: Dictionary=VIEWS[current_view]
	ship.visible=current_view>=3; sea.visible=current_view>=3
	fixtures.visible=current_view>=12
	if module!=null: remove_child(module); module.free(); module=null
	if current_view<3:
		var scene: PackedScene=load(H.BASE+"weapons/"+("type96" if current_view==2 else "type89")+".tscn") as PackedScene
		module=scene.instantiate() as Node3D; module.set("smokeproof",current_view==1); add_child(module)
	ship.apply_equipment_state("elevator_forward",{"height_m":4.0 if current_view==16 else 14.15})
	(fixtures.aircraft[1].get_parent() as Node3D).position.y=4.0 if current_view==16 else 14.15
	camera.position=view.eye; camera.look_at(view.target,Vector3.RIGHT if current_view in [5,14] else Vector3.UP); camera.size=view.size
	var description: String="Static model / deck fit only; flight operations require OPS01"
	if current_view==15: description="D4Y2 DIMENSION CAGE ONLY - aircraft model is NOT admitted"
	elif current_view in [12,13,14,16]: description="Unmodified 1:1 A6M5a (1944) on Shokaku (1941): static cross-era assembly"
	label.text="SHOKAKU | 1941-08-23 | CV02 | "+str(view.id)+"\n"+description+"  |  Left / Right: cameras"
	_publish()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_RIGHT: _set_view(current_view+1)
		elif event.keycode==KEY_LEFT: _set_view(current_view-1)

func _process(_delta: float) -> void:
	frames+=1
	if OS.has_feature("web"):
		var commands: Array=JSON.parse_string(JavaScriptBridge.eval("JSON.stringify(window.CV02.commands.splice(0))",true)) as Array
		for command: Dictionary in commands:
			command_id=int(command.id)
			if command.kind=="view": _set_view(int(command.value))
			elif command.kind=="elevator": ship.apply_equipment_state(command.elevator_id,{"height_m":float(command.value)})
		_publish()

func _publish() -> void:
	if not OS.has_feature("web"): return
	var heights: Dictionary={}
	for e: Dictionary in ship.deck_definition().elevators: heights[e.id]=ship.deck_surface_at(Vector2(e.center_xz_m[0],e.center_xz_m[1])).height_m
	var data: Dictionary={"model_id":"jp_shokaku_1941_08_23","view":VIEWS[current_view].id,"index":current_view,
		"frames":frames,"command_id":command_id,"sockets":ship.mount_sockets().size(),"elevator_heights":heights,
		"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)}
	JavaScriptBridge.eval("window.CV02.latest="+JSON.stringify(data),true)

func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var records: Array[Dictionary]=[]
	for index: int in range(VIEWS.size()):
		if not capture_views.is_empty() and not str(VIEWS[index].id) in capture_views: continue
		_set_view(index)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var img: Image=get_viewport().get_texture().get_image()
		var path: String=output+"/"+str(VIEWS[index].id)+".png"
		if img.save_png(path)!=OK: push_error("CV02 save failed "+path); get_tree().quit(1); return
		records.append({"id":VIEWS[index].id,"file":path,"size":[img.get_width(),img.get_height()],
			"eye_m":[VIEWS[index].eye.x,VIEWS[index].eye.y,VIEWS[index].eye.z],
			"target_m":[VIEWS[index].target.x,VIEWS[index].target.y,VIEWS[index].target.z],"orthographic_size_m":VIEWS[index].size,
			"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)})
	var file: FileAccess=FileAccess.open(output+"/capture.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"engine":Engine.get_version_info().string,"views":records,"shadows_disabled_for_diagnosis":shadows_disabled,"scope":"Static 1:1 modules/assembly/bearing; D4Y cage only; no takeoff/recovery"},"\t")); file.close()
	print("PASS CV02 captured ",records.size()," native model / deck fit views")
	get_tree().quit(0)
