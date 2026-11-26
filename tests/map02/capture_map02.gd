extends SceneTree
const ROOT_PATH: String="res://docs/showcase/evidence/MAP02"
var failures: PackedStringArray=[]
var report: Dictionary={"views":[],"frames":[],"scope":"MAP02 independent static inspection; no combat/OPS or Chrome performance claim"}
var viewport: SubViewport
var game: Node3D
var gallery: bool=false
const HASH_PATHS: Array[String]=["data/maps/island_harbor_expanded.json","data/map02/facility_modules.json","data/map02/facility_instances.json","data/map02/regions.json","scripts/map02/expanded_map_data.gd","scripts/map02/expanded_map_view.gd","scripts/map02/map_inspector.gd","scenes/map02/expanded_map.tscn","scenes/map02/facilities.tscn","scripts/simulation/terrain/terrain_queries.gd","scripts/simulation/terrain/terrain_navigation.gd","scripts/presentation/maps/island_harbor_view.gd","scripts/presentation/ocean.gdshader","tests/map02/capture_map02.gd"]
func source_hashes() -> Dictionary:
	var result: Dictionary={}
	for path: String in HASH_PATHS:result[path]=FileAccess.get_sha256("res://"+path)
	return result
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok:failures.append(message)
func draw_frame() -> void:
	await process_frame
	RenderingServer.force_draw(false,0)
func capture(name: String) -> void:
	game.camera.update_view(0,game.preview_time_s,{},true)
	await draw_frame()
	var dir: String=ROOT_PATH.path_join("modules" if gallery else "map")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	check(viewport.get_texture().get_image().save_png(dir.path_join(name+".png"))==OK,"save "+name)
	report.views.append({"name":name,"camera_m":SimData.array3(game.camera.position),"focus_m":SimData.array3(game.camera.focus),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"triangles":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)})
func run() -> void:
	report.source_hashes_before=source_hashes()
	gallery="--gallery" in OS.get_cmdline_user_args()
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	viewport=SubViewport.new();viewport.size=Vector2i(1280,720);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var scene: PackedScene=load("res://scenes/map02/facilities.tscn" if gallery else "res://scenes/map02/expanded_map.tscn")
	game=scene.instantiate() as Node3D;viewport.add_child(game);game.set_process(false)
	await draw_frame()
	check(game.map_view!=null,"assembled view")
	if game.map_view==null:finish();return
	report.map_sha256=FileAccess.get_sha256("res://data/maps/island_harbor_expanded.json")
	report.statistics=game.map_view.statistics
	game.select_point(0)
	await capture("normal_ui")
	game.ui.visible=false
	for i: int in game.points.size():
		game.select_point(i)
		await capture(str(game.points[i].id))
	if not gallery:
		report.cost_visible={"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"triangles":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)}
		# Same scene/resolution/camera: measure static map cost without changing queries.
		game.map_view.hide();await draw_frame()
		report.cost_hidden={"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"triangles":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)}
		game.map_view.show()
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROOT_PATH.path_join("sequence")))
		var shot_ids: Array[String]=["map02_civil_low","map02_naval_low","map02_airfield","map02_fuel"]
		for shot: int in shot_ids.size():
			var selected: int=-1
			for i: int in game.points.size():
				if game.points[i].id==shot_ids[shot]:selected=i
			check(selected>=0,"shot exists")
			if selected<0:continue
			game.select_point(selected)
			for frame: int in 20:
				game.camera.yaw+=.008
				game.set_preview_time((shot*20+frame)/10.0)
				game.camera.update_view(.1,game.preview_time_s,{},true)
				await draw_frame()
				var clearance: float=game.camera.position.y-TerrainQueries.height_data(game.terrain,game.camera.position,true)
				check(clearance>=7.99,"moving inspection camera clears surface")
				viewport.get_texture().get_image().save_png(ROOT_PATH.path_join("sequence/frame_%03d.png"%(shot*20+frame)))
				report.frames.append({"index":shot*20+frame,"shot":shot_ids[shot],"camera_m":SimData.array3(game.camera.position),"clearance_m":clearance,"preview_s":game.preview_time_s})
	var nodes: int=game.get_child_count()
	report.static_children=nodes
	check(int(game.map_view.statistics.static_triangles)<150000,"expanded map triangle budget")
	game.queue_free();await draw_frame()
	check(viewport.get_child_count()==0,"map/modules reclaimed on exit")
	report.reclaimed_on_exit=viewport.get_child_count()==0
	report.source_hashes_after=source_hashes()
	check(report.source_hashes_before==report.source_hashes_after,"capture sources stable throughout run")
	finish()
func finish() -> void:
	report.failures=failures
	var file: FileAccess=FileAccess.open(ROOT_PATH.path_join("module_capture.json" if gallery else "map_capture.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"));file.close()
	for failure: String in failures:push_error("MAP02 capture: "+failure)
	print("MAP02 ","modules" if gallery else "map"," native: ","PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
