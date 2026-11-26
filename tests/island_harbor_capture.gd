extends SceneTree
var game: FirstPlayableGame
var directory: String="res://docs/showcase/evidence/S09"
var audit: Dictionary={"views":[],"continuous_frames":[],"resets":[],"scope":"Native 1280x720, exact map/model/simulation; no browser performance claim"}
var failures: PackedStringArray=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok:failures.append(message)
func tick(count: int=1) -> Array[BattleEvent]:
	var collected: Array[BattleEvent]=[]
	for i: int in count:
		game.session.world.step_ticks(1)
		var events: Array[BattleEvent]=game.session.consume_world()
		game.apply_presentation(events)
		collected.append_array(events)
		game.camera.update_view(1.0/60.0,game.session.world.time_s(),game.session.units,false)
	return collected
func render_frames(count: int=3) -> void:
	# Explicit bounded draw also works when a static, unfocused window is idle.
	for i: int in count:await process_frame
	RenderingServer.force_draw(false, 0.0)
func save_view(label_value: String) -> void:
	game.camera.update_view(0.0,game.session.world.time_s(),game.session.units,true)
	game.hud.refresh(game.session,game.camera.mode,game.camera.shot_label)
	await render_frames()
	var path: String=directory.path_join(label_value+".png")
	check(game.camera.position.y>=TerrainQueries.height_data(game.camera.terrain,game.camera.position,true)+7.99,"camera terrain clearance "+label_value)
	var error: Error=root.get_texture().get_image().save_png(path)
	check(error==OK,"save "+label_value)
	audit.views.append({"name":label_value,"time_s":game.session.world.time_s(),"camera":SimData.array3(game.camera.position),"focus":SimData.array3(game.camera.focus),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"triangles":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)})
func run() -> void:
	audit.source_hashes_start=source_hashes()
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	DisplayServer.window_set_size(Vector2i(1280,720));root.content_scale_size=Vector2i(1280,720)
	AudioServer.set_bus_mute(0,true)
	game=(load("res://showcase/island_harbor.tscn") as PackedScene).instantiate() as FirstPlayableGame
	root.add_child(game);game.set_process(false)
	check(game.running,"actual map scene loads")
	if not game.running:finish();return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory.path_join("sequence")))
	tick(120)
	await save_view("normal_ui")
	game.hud.cinema=true;game.hud._layout()
	game._action("map_location","overview")
	await save_view("overview")
	game._action("follow","jp_bb")
	await save_view("ship_sea")
	game._action("map_location","harbor")
	await save_view("harbor_town")
	game._action("map_location","town")
	await save_view("town")
	game._action("map_location","coast_sites")
	await save_view("coast_site")
	game._action("map_location","ridge_sites")
	await save_view("ridge_site")
	game.camera.locate(Vector3(-3700,10,-2650))
	game.camera.distance_m=700;game.camera.yaw=1.1;game.camera.pitch=.12
	await save_view("low_coast")
	# Same world, camera, resolution, effects and units: toggle appearance only.
	game._action("map_location","overview")
	game.camera.update_view(0,game.session.world.time_s(),game.session.units,true)
	await render_frames()
	var with_map: Dictionary=cost()
	game.map_view.hide();await render_frames()
	var without_map: Dictionary=cost()
	game.map_view.show();await render_frames()
	audit.cost={"with_map":with_map,"without_map":without_map,"static_map":game.map_view.statistics}
	check(float(with_map.draw_calls)-float(without_map.draw_calls)<=150,"map draw budget")
	check(int(game.map_view.statistics.static_triangles)<150000,"map triangle budget")
	# Runtime continuous sequence: ship water, low coast and the inhabited bay.
	for shot: int in 4:
		if shot==0:game._action("follow","jp_bb")
		elif shot==1:
			game.camera.locate(Vector3(-3700,10,-2650));game.camera.distance_m=700;game.camera.yaw=1.1;game.camera.pitch=.12
		elif shot==2:game._action("map_location","harbor")
		else:game._action("follow","us_air_1")
		for frame: int in 24:
			tick(5)
			await render_frames(1)
			var index: int=shot*24+frame
			root.get_texture().get_image().save_png(directory.path_join("sequence/frame_%03d.png"%index))
			audit.continuous_frames.append({"index":index,"sim_s":game.session.world.time_s(),"camera":SimData.array3(game.camera.position),"clearance_m":game.camera.position.y-TerrainQueries.height_data(game.camera.terrain,game.camera.position,true)})
	# Capture actual autonomous events with no edits to orders, damage, ammunition,
	# flight or ship state. Camera following is the only intervention.
	var combat_views: Dictionary={}
	for i: int in 7200:
		var events: Array[BattleEvent]=tick()
		for event: BattleEvent in events:
			var kind: String=""
			if event.kind=="fired" and game.metadata[event.entity_id].domain=="aircraft":kind="air_combat"
			elif event.kind=="airburst":kind="air_defence"
			elif event.kind=="salvo" and event.entity_id.ends_with("bb"):kind="gunnery"
			if kind.is_empty() or combat_views.has(kind):continue
			combat_views[kind]=FleetFixture.json_data(event.snapshot())
			if kind=="air_defence":game.camera.locate(event.position_m);game.camera.distance_m=100;game.camera.pitch=.3
			else:game.camera.follow(event.entity_id)
			game.hud._selected_unit=event.entity_id if game.session.units.has(event.entity_id) else "jp_bb"
			tick(2)
			await save_view(kind)
		if combat_views.size()==3:break
		if i%120==0:await process_frame
	audit.combat_events=combat_views
	check(combat_views.size()==3,"actual gunnery, AA and aircraft fire captured")
	# Real controls and reset retention. Master muted only for this owned test process.
	game.hud.cinema=false;game.hud._layout();await render_frames()
	var sound_position: Vector2=game.hud.sound_button.get_global_rect().get_center()
	var click: InputEventMouseButton=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.position=sound_position;click.pressed=true
	Input.parse_input_event(click);await process_frame
	click=click.duplicate();click.pressed=false;Input.parse_input_event(click);await process_frame
	check(game._sound_enabled,"real click enables sound")
	game.apply_presentation([]); await render_frames(3)
	game.apply_presentation([])
	var playing_before: int=0
	for source: AudioStreamPlayer3D in game.effects.engine_sources:
		if source.playing: playing_before+=1
	check(playing_before>0,"actual engine stream started before pause")
	var key: InputEventKey=InputEventKey.new();key.physical_keycode=KEY_SPACE;key.keycode=KEY_SPACE;key.pressed=true
	Input.parse_input_event(key);await process_frame
	game.apply_presentation([]);await render_frames(3);game.apply_presentation([])
	check(game.session.world.paused and game._sound_enabled,"Space after sound click pauses without sound toggle")
	var paused_sources: int=0
	for source: AudioStreamPlayer3D in game.effects.engine_sources:
		if source.playing:
			check(source.stream_paused,"engine paused while enabled")
			if source.stream_paused: paused_sources+=1
	audit.audio_pause={"playing_before":playing_before,"paused_sources":paused_sources,"world_paused":game.session.world.paused,"sound_enabled":game._sound_enabled}
	check(paused_sources>0,"actual active sources paused")
	key=key.duplicate();key.pressed=false;Input.parse_input_event(key);await process_frame
	game.hud.pause_button.pressed.emit();game.apply_presentation([])
	check(not game.session.world.paused and game._sound_enabled,"pause button resumes with sound enabled")
	var nodes: int=game.get_child_count();var map_instance: int=game.map_view.get_instance_id()
	for iteration: int in 3:
		game._action("restart",null);await render_frames(1)
		check(game.get_child_count()==nodes and game.map_view.get_instance_id()==map_instance,"restart keeps one map and model set")
		check(game._sound_enabled and not game.session.world.paused,"restart preserves sound preference and resets pause")
		audit.resets.append({"generation":game.session.world.generation,"children":game.get_child_count(),"map_instance":game.map_view.get_instance_id(),"map_triangles":game.map_view.statistics.static_triangles,"models":game.models.size(),"terrain_height_m":TerrainQueries.height_m(game.session.world,Vector3(-5200,0,-4630))})
	finish()
func cost() -> Dictionary:
	return {"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"triangles":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"objects":Performance.get_monitor(Performance.OBJECT_COUNT),"static_memory_bytes":Performance.get_monitor(Performance.MEMORY_STATIC)}
func finish() -> void:
	audit.source_hashes_end=source_hashes()
	check(audit.source_hashes_start==audit.source_hashes_end,"runtime sources frozen throughout capture")
	audit.failures=failures
	var file: FileAccess=FileAccess.open(directory.path_join("native_capture.json"),FileAccess.WRITE);file.store_string(JSON.stringify(audit,"\t"));file.close()
	for failure: String in failures:push_error("S09 capture: "+failure)
	print("S09 native capture: ","PASS" if failures.is_empty() else failures)
	if game!=null:game.queue_free()
	quit(0 if failures.is_empty() else 1)

func source_hashes() -> Dictionary:
	var result: Dictionary={}
	for path: String in ["res://data/maps/island_harbor.json", "res://data/scenarios/island_harbor.json", "res://scripts/simulation/terrain/terrain_queries.gd", "res://scripts/simulation/terrain/battlefield_terrain.gd", "res://scripts/simulation/terrain/terrain_navigation.gd", "res://scripts/presentation/maps/island_harbor_view.gd", "res://scripts/presentation/maps/shore.gdshader", "res://scripts/presentation/ocean.gdshader", "res://scripts/game/first_playable.gd", "res://scripts/game/first_playable_session.gd", "res://scripts/presentation/cameras/observer_camera.gd", "res://scripts/behaviors/fleet_formations/fleet_tasks.gd", "res://scripts/simulation/ship_motion/ship_motion.gd", "res://scripts/simulation/aircraft_motion/aircraft_motion.gd", "res://scripts/behaviors/aircraft/aircraft_tasks.gd", "res://scripts/behaviors/aircraft/air_combat_tactics.gd", "res://ui/observer_hud.gd", "res://ui/observer_text.gd", "res://ui/observer_map.gd"]:
		result[path]=FileAccess.get_sha256(path)
	return result
