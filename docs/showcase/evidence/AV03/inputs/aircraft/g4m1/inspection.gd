extends Node3D
## Bounded evidence stage only. Never a production unit/AI driver.
const MODEL: PackedScene = preload("res://aircraft/g4m1/g4m1.tscn")
const G: Script = preload("res://aircraft/g4m1/geometry.gd")
const MAP_DATA: Script = preload("res://scripts/map02/expanded_map_data.gd")
const MAP_VIEW: Script = preload("res://scripts/map02/expanded_map_view.gd")
var aircraft: Node3D
var camera: Camera3D
var ground: Node3D
var airport: Node3D
var label: Label
var selected: String="quarter"
var output: String=""
var batch: String=""

func _ready() -> void:
	get_viewport().msaa_3d=Viewport.MSAA_4X
	var args: PackedStringArray=OS.get_cmdline_user_args()
	for i: int in range(args.size()-1):
		match args[i]:
			"--view": selected=args[i+1]
			"--capture": output=args[i+1]
			"--batch": batch=args[i+1]
	_stage()
	aircraft=MODEL.instantiate() as Node3D;add_child(aircraft)
	camera=Camera3D.new();camera.far=5000;add_child(camera);camera.current=true
	if not batch.is_empty(): _batch_capture()
	else:
		_view(selected)
		if not output.is_empty():
			await _save(output)
			get_tree().quit()

func _stage() -> void:
	var env: Environment=Environment.new();env.background_mode=Environment.BG_COLOR;env.background_color=Color("c7cfd2")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("e4e6e5");env.ambient_light_energy=0.70
	env.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	var world: WorldEnvironment=WorldEnvironment.new();world.environment=env;add_child(world)
	var sun: DirectionalLight3D=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-42,-28,0);sun.light_energy=0.95;sun.shadow_enabled=true;sun.directional_shadow_max_distance=250.0;add_child(sun)
	var fill: DirectionalLight3D=DirectionalLight3D.new();fill.rotation_degrees=Vector3(20,145,0);fill.light_energy=0.34;add_child(fill)
	ground=G.box(self,"NeutralGround",Vector3(100,0.08,100),Vector3(0,-0.04,0),G.material(Color("b1bcbf")))
	var layer: CanvasLayer=CanvasLayer.new();add_child(layer)
	label=Label.new();label.position=Vector2(24,18);label.add_theme_font_size_override("font_size",21);label.add_theme_color_override("font_color",Color("223c44"));layer.add_child(label)

func _view(id: String) -> void:
	selected=id
	aircraft.transform=Transform3D.IDENTITY
	aircraft.apply_damage_state({"center":true,"left_wing":true,"right_wing":true,"tail":true,"engine_left":true,"engine_right":true})
	aircraft.apply_visual_state({"gear":1.0,"flap":0.0,"payload_mode":"bombs_12x60","dorsal_open":false,"propeller_left_rad":0.0,"propeller_right_rad":0.0,
		"aileron_left_rad":0.0,"aileron_right_rad":0.0,"elevator_left_rad":0.0,"elevator_right_rad":0.0,"rudder_rad":0.0,
		"guns":{"nose":{"yaw_rad":0.0,"elevation_rad":0.0},"tail":{"yaw_rad":0.0,"elevation_rad":0.0},"dorsal":{"yaw_rad":0.0,"elevation_rad":0.52},"waist_left":{"yaw_rad":0.0,"elevation_rad":0.0},"waist_right":{"yaw_rad":0.0,"elevation_rad":0.0}}})
	ground.visible=true
	if airport!=null:airport.visible=false
	var parked: bool=not id.contains("flight") and not id in ["bay","guns","transition","damage"]
	if parked:aircraft.transform=aircraft.get_parked_transform()
	else:
		aircraft.set_flight_configuration();ground.visible=false
	var target: Vector3=aircraft.transform*Vector3(0,0.2,0)
	var offset: Vector3=Vector3(29,22,-39)
	var size: float=21.0
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	match id:
		"side","side_flight":offset=Vector3(35,0,0);size=14.2
		"front","front_flight":offset=Vector3(0,0,-40);size=17.2
		"top_flight":offset=Vector3(0,40,0.001);size=24.0
		"high_rear":offset=Vector3(-25,26,37);size=24.0
		"underside_flight":offset=Vector3(20,-28,-33);size=26.0
		"gear":target=aircraft.transform*Vector3(3.85,-1.25,-4.1);offset=Vector3(9,1,-10);size=7.0
		"tailgear":target=aircraft.transform*Vector3(0,-0.55,7.7);offset=Vector3(10,0.6,2);size=4.5
		"glazing":target=aircraft.transform*Vector3(0,0.7,-6.7);offset=Vector3(10,5,-13);size=10.0
		"bay":target=Vector3(0,-0.8,-1.1);offset=Vector3(8,-11,-7);size=10.0
		"guns":aircraft.apply_visual_state({"dorsal_open":true});target=Vector3(0,0.4,2.9);offset=Vector3(-15,8,20);size=17.0
		"nose_gun":aircraft.transform=Transform3D.IDENTITY;aircraft.set_flight_configuration();ground.visible=false;target=Vector3(0,0,-8.70);offset=Vector3(-7,2,-9);size=4.5
		"dorsal_gun":aircraft.transform=Transform3D.IDENTITY;aircraft.set_flight_configuration();aircraft.apply_visual_state({"dorsal_open":true});ground.visible=false;target=Vector3(0,1.45,-2.35);offset=Vector3(-6,3.5,7);size=4.0
		"waist_gun":aircraft.transform=Transform3D.IDENTITY;aircraft.set_flight_configuration();ground.visible=false;target=Vector3(-1.1,0.2,1.38);offset=Vector3(-8,3,5);size=4.5
		"tail_gun":aircraft.transform=Transform3D.IDENTITY;aircraft.set_flight_configuration();ground.visible=false;target=Vector3(0,0.2,8.9);offset=Vector3(-6,2,8);size=4.8
		"transition":aircraft.apply_visual_state({"gear":0.5,"flap":1.0});offset=Vector3(-23,-14,-26);size=23.0
		"landing":aircraft.apply_visual_state({"flap":1.0});offset=Vector3(-30,7,32);size=23.0
		"ferry":aircraft.apply_visual_state({"payload_mode":"ferry"});offset=Vector3(25,-17,-30);size=24.0;aircraft.transform=Transform3D.IDENTITY;ground.visible=false;target=Vector3.ZERO
		"observer_flight":camera.projection=Camera3D.PROJECTION_PERSPECTIVE;camera.fov=45;offset=Vector3(50,18,-62)
		"damage":aircraft.apply_damage_state({"left_wing":false,"tail":false});offset=Vector3(-27,15,-32);size=23.0
	if id.begins_with("airport_"):
		if airport==null:
			airport=MAP_VIEW.new() as Node3D;add_child(airport);airport.call("build",MAP_DATA.compile());airport.call("advance",0.0)
		airport.visible=true;ground.visible=false
		var station: Vector3=Vector3(6900,8.04,-2400) if id=="airport_runway" else Vector3(6500,8.04,-2510)
		var heading: float=0.0 if id=="airport_runway" else -PI*0.5
		aircraft.transform=Transform3D(Basis(Vector3.UP,heading),station)*aircraft.get_parked_transform()
		target=station+Vector3(0,2.0,0);offset=Vector3(31,17,-39);size=31.0
	camera.size=size;camera.position=target+offset
	camera.look_at(target)
	label.text="G4M1 Model 11 / Kasei 11  |  1942-07  |  "+id.replace("_"," ")+"\n1:1 m  |  native static model inspection"
	if id.begins_with("airport_"):label.text+="\nExisting MAP02 airfield / 8.04 m surface; static fit only, no OPS claim"

func _save(path: String) -> void:
	for i: int in range(5):await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var err: Error=get_viewport().get_texture().get_image().save_png(path)
	if err!=OK:push_error("AV03 capture failed: "+path);get_tree().quit(1);return
	var hashes: Dictionary={}
	for f: String in ["aircraft/g4m1/g4m1.gd","aircraft/g4m1/geometry.gd","aircraft/g4m1/g4m1.tscn","aircraft/g4m1/inspection.gd","aircraft/g4m1/inspection.tscn","project.godot"]:
		hashes[f]=FileAccess.get_sha256("res://"+f)
	if selected.begins_with("airport_"):
		for f: String in ["scripts/map02/expanded_map_data.gd","scripts/map02/expanded_map_view.gd","scripts/presentation/maps/island_harbor_view.gd","scripts/simulation/terrain/terrain_queries.gd","data/maps/island_harbor_expanded.json","data/map02/regions.json"]:hashes[f]=FileAccess.get_sha256("res://"+f)
	var meta: Dictionary={"view":selected,"source_hashes":hashes,"engine":Engine.get_version_info(),"renderer":"gl_compatibility","viewport_px":[get_viewport().size.x,get_viewport().size.y],
		"camera_position_m":[camera.position.x,camera.position.y,camera.position.z],"camera_rotation_rad":[camera.rotation.x,camera.rotation.y,camera.rotation.z],"projection":camera.projection,"size_m":camera.size,"fov_deg":camera.fov,
		"model_position_m":[aircraft.position.x,aircraft.position.y,aircraft.position.z],"model_rotation_rad":[aircraft.rotation.x,aircraft.rotation.y,aircraft.rotation.z],"model_scale":[aircraft.scale.x,aircraft.scale.y,aircraft.scale.z],"visual_state":aircraft.state}
	var file: FileAccess=FileAccess.open(path+".json",FileAccess.WRITE);file.store_string(JSON.stringify(meta,"\t"));file.close()
	print("AV03 saved "+path)

func _batch_capture() -> void:
	var file: FileAccess=FileAccess.open(batch,FileAccess.READ)
	if file==null:push_error("AV03 batch does not exist");get_tree().quit(1);return
	var rows: Array=JSON.parse_string(file.get_as_text());file.close()
	for row: Dictionary in rows:
		_view(row.view)
		await _save(row.path)
	get_tree().quit()
