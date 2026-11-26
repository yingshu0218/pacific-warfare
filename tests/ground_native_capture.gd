extends SceneTree
## Actual default island battle; normal viewer follow/selection only. No combat injection.
var game: FirstPlayableGame
var audit: Dictionary = {"scope":"Actual default defence scene, viewer camera selections; continuous 30s at10fps, not performance measurement","frames":[],"views":[],"checks":[]}
const DIRECTORY: String = "res://docs/showcase/evidence/S10"

func _initialize() -> void:call_deferred("run")
func check(ok: bool,label_value: String) -> void:
	audit.checks.append({"label":label_value,"passed":ok})
	if not ok:push_error("S10 native: "+label_value)

func tick(count: int) -> Array[BattleEvent]:
	var result: Array[BattleEvent] = []
	for index: int in count:
		game.session.world.step_ticks(1)
		var events: Array[BattleEvent] = game.session.consume_world()
		game.apply_presentation(events);result.append_array(events)
	game.camera.update_view(.1,game.session.world.time_s(),game.session.units,true)
	game.environment_view.update_observer(game.camera.position)
	return result

func draw() -> void:
	await process_frame;await process_frame;RenderingServer.force_draw(false,0)

func save(label_value: String) -> void:
	game.hud.refresh(game.session,game.camera.mode,game.camera.shot_label)
	await draw()
	root.get_texture().get_image().save_png(DIRECTORY.path_join(label_value+".png"))
	audit.views.append({"name":label_value,"time_s":game.session.world.time_s(),"followed_id":game.camera.followed_id,"unit_detail":game.hud.unit_detail.text,"draw_calls":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)})

func run() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	DisplayServer.window_set_size(Vector2i(1280,720));root.content_scale_size=Vector2i(1280,720)
	AudioServer.set_bus_mute(0,true)
	game=(load("res://showcase/island_harbor.tscn") as PackedScene).instantiate() as FirstPlayableGame
	root.add_child(game);game.set_process(false)
	if not game.running:quit(1);return
	check(game.models.size()==15 and game.session.units.size()==15,"four ships, eight aircraft, three ground model instances")
	check(game.recoils.size()==7 and game.wakes.size()==4,"ground recoil without fake ship wakes")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIRECTORY.path_join("sequence")))
	for frame: int in range(300):
		if frame in [0,90,180]:
			var id: String = ["us_coast_01","us_aa_01","jp_bb"][frame/90]
			game.camera.follow(id);game.hud._selected_unit=id
		var events: Array[BattleEvent] = tick(6)
		game.hud.refresh(game.session,game.camera.mode,game.camera.shot_label)
		if frame==15:await save("coast_normal_ui")
		if frame==15:check(not game.hud.map.get_global_rect().intersects(game.hud.cards.us.get_global_rect()),"ground order cards do not overlap normal map")
		if frame==100:await save("aa_normal_ui")
		if frame==210:await save("ship_shore_fire")
		if frame==45:
			var ground_order: Dictionary = {}
			for order: Dictionary in game.session.world.orders_snapshot():
				if order.assigned_unit_ids.has("us_coast_01"):ground_order=order;break
			check(not ground_order.is_empty(),"real ground commander order exists")
			game.hud._select(ground_order)
			await save("ground_order_timeline")
			game.hud.expanded=false;game.hud._layout();game.camera.follow("us_coast_01")
		await draw()
		root.get_texture().get_image().save_png(DIRECTORY.path_join("sequence/frame_%03d.png"%frame))
		audit.frames.append({"frame":frame,"time_s":game.session.world.time_s(),"camera":SimData.array3(game.camera.position),"focus":SimData.array3(game.camera.focus),"followed":game.camera.followed_id,"events":events.filter(func(e: BattleEvent)->bool:return e.kind=="fired" and (game.metadata[e.entity_id].domain=="ground" or e.target_id.begins_with("us_coast"))).map(func(e: BattleEvent)->Dictionary:return e.snapshot())})
	# Real HUD handlers and model reuse over three restarts.
	var model_ids: Array = game.models.values().map(func(n: Node3D)->int:return n.get_instance_id())
	var restarts: Array = []
	for run_index: int in 3:
		game._action("restart",null);tick(120)
		check(game.models.values().map(func(n: Node3D)->int:return n.get_instance_id())==model_ids,"restart reuses exact model instances")
		check(game.session.report().us.ground==3,"ground resets as ground, never aircraft")
		restarts.append({"generation":game.session.world.generation,"models":game.models.size(),"node_count":game.find_children("*","",true,false).size(),"tick":game.session.world.tick})
	audit.restarts=restarts
	game._action("follow","us_aa_01");game.hud._selected_unit="us_aa_01"
	game.hud.refresh(game.session,game.camera.mode,game.camera.shot_label)
	check(not game.hud.unit_detail.text.contains("余油") and not game.hud.unit_detail.text.contains("进水") and game.hud.unit_detail.text.contains("固定阵地"),"normal ground details show applicable actual fields")
	var before: int = game.session.world.tick
	game._action("pause",null);game._process(.5)
	check(game.session.world.tick==before,"normal pause handler freezes ground and world")
	game._action("pause",null)
	game.hud.report_panel.show();await save("ground_report")
	audit.report=game.session.report();audit.effects=game.effects.statistics();audit.counts=game.session.counts
	FileAccess.open(DIRECTORY.path_join("native_capture.json"),FileAccess.WRITE).store_string(JSON.stringify(audit,"\t"))
	var passed: bool = audit.checks.all(func(c: Dictionary)->bool:return c.passed)
	game.free();print("S10_NATIVE ",audit.checks.size()," checks,300 continuous frames")
	quit(0 if passed else 1)
