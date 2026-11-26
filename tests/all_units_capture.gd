extends SceneTree

var game: AllUnitsShowcase
var directory: String = "res://docs/showcase/evidence/S14/native"
var audit: Dictionary = {"views":[],"frames":[],"checks":[],"scope":"Real scene, fixed ticks, read-only camera. Evidence encoding frequency is not game performance."}

func _initialize() -> void: call_deferred("run")
func draw() -> void:
	await process_frame
	await process_frame
	RenderingServer.force_draw(false,0)

func tick(count: int) -> void:
	game.session.world.step_ticks(count)
	game.apply_presentation(game.session.consume_world())
	game._update_guide(float(count)/60.0)
	game.hud.refresh(game.session,game.camera.mode,game.camera.shot_label)
	game._refresh_guide_ui()

func save(label: String) -> void:
	await draw()
	root.get_texture().get_image().save_png(directory.path_join(label+".png"))
	audit.views.append({"label":label,"time_s":game.session.world.time_s(),"camera":game.camera.position,"focus":game.camera.focus,"guide":game.guide_state.duplicate(true),"units":game.session.units.duplicate(true),"counts":game.session.counts.duplicate()})

func run() -> void:
	root.size = Vector2i(1280,720)
	root.content_scale_size = Vector2i(1280,720)
	game = (load("res://showcase/all_units.tscn") as PackedScene).instantiate() as AllUnitsShowcase
	root.add_child(game)
	game.set_process(false)
	if not game.running: quit(1); return
	audit["sources_before"] = source_hashes()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	if "--air-only" in OS.get_cmdline_user_args():
		await continuous()
		audit["sources_after"] = source_hashes()
		audit["unchanged_inputs"] = audit.sources_before == audit.sources_after
		var air_out: FileAccess = FileAccess.open(directory.path_join("air_capture.json"),FileAccess.WRITE)
		air_out.store_string(JSON.stringify(audit,"\t"))
		game.queue_free()
		await process_frame
		quit()
		return
	tick(120)
	await save("normal_ui")
	for id: String in ["jp_bb","us_bb","jp_dd","us_dd","us_pair_demo_1","jp_air_1","us_sb2c_1","us_coast_01","us_aa_01"]:
		game._action("follow",id)
		tick(1)
		game.camera.update_view(0,game.session.world.time_s(),game.session.units,true)
		hud_subject(id)
		await save(id)
	for index: int in game.gallery.entries.size():
		game.inspect_weapon(index)
		await save("weapon_%d"%index)
	# Viewer controls and the new scenario-switch generation path are exercised
	# on the real assembled scene; they do not inject flight or damage state.
	var before: Dictionary = game.session.world.snapshot()
	game._update_guide(0.25)
	verify(game.session.world.snapshot()==before,"camera/gallery cannot alter simulation")
	game._action("pause",null)
	var paused_tick: int = game.session.world.tick
	game._process(.1)
	verify(game.session.world.tick==paused_tick,"pause stops simulation in new scene")
	game._action("pause",null)
	game._action("speed",2.0)
	verify(is_equal_approx(game.session.world.time_scale,2.0),"viewer speed controls same clock")
	var generation: int = game.session.world.generation
	game.choose_exercise(4)
	verify(game.session.world.generation==generation+1 and game.models.size()==19,"selection resets generation and reuses 19 models")
	generation = game.session.world.generation
	game._action("restart",null)
	verify(game.session.world.generation==generation+1 and game.session.world.tick==0,"restart uses production reset")
	game._action("follow","us_sb2c_1")
	verify(game.camera.followed_id=="us_sb2c_1" and not game.guide.active,"SB2C normal follow takes camera control")
	hud_subject("us_sb2c_1")
	verify(game.hud.unit_detail.text.contains("SB2C"),"normal unit detail shows SB2C")
	game.hud.cinema = false
	game.hud._layout()
	game._refresh_guide_ui()
	game.hud.expanded = true
	game.hud._layout()
	game.hud.refresh(game.session,game.camera.mode,game.camera.shot_label)
	await save("real_orders")
	verify(game.hud.cards.jp.visible and game.hud.cards.us.visible and game.hud.timeline_panel.visible,"both real command streams remain accessible")
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--continuous": await continuous()
	audit["sources_after"] = source_hashes()
	audit["unchanged_inputs"] = audit.sources_before == audit.sources_after
	var out: FileAccess = FileAccess.open(directory.path_join("capture.json"),FileAccess.WRITE)
	out.store_string(JSON.stringify(audit,"\t"))
	game.queue_free()
	await process_frame
	quit()

func verify(ok: bool,label: String) -> void:
	audit.checks.append({"label":label,"passed":ok})
	if not ok: push_error("S14 scene: "+label)

func hud_subject(id: String) -> void:
	game.hud._selected_unit = id
	game.hud.refresh(game.session,game.camera.mode,game.camera.shot_label)
	game._refresh_guide_ui()

func continuous() -> void:
	game.hud.cinema = true
	game.hud.expanded = false
	game.hud._layout()
	for mode_index: int in [1,2,3,4]:
		game.choose_exercise(mode_index)
		var mode: String = game.exercise
		var path: String = directory.path_join(mode)
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))
		# 24s at 10 frames/s, real simulation steps between every captured frame.
		for frame: int in 240:
			tick(6)
			await draw()
			var filename: String = path.path_join("frame_%04d.png"%frame)
			root.get_texture().get_image().save_png(filename)
			var planes: Dictionary = {}
			for id: String in game.session.units:
				var unit: Dictionary = game.session.units[id]
				if not unit.module_data.has("aircraft_motion"): continue
				var flight: Dictionary = unit.module_data.aircraft_motion
				planes[id] = {"active":unit.active,"position_m":SimData.array3(unit.position_m),"velocity_mps":SimData.array3(unit.velocity_mps),"rotation_rad":SimData.array3(unit.rotation_rad),"flight":flight.duplicate(true),"task":unit.task.duplicate(true),"formation":unit.module_data.get("air_formation",{}).duplicate(true)}
			audit.frames.append({"mode":mode,"frame":frame,"time_s":game.session.world.time_s(),"guide":game.guide_state.duplicate(true),"units":planes,"camera":SimData.array3(game.camera.position)})

func source_hashes() -> Dictionary:
	var result: Dictionary = {}
	for path: String in ["res://scripts","res://scenes","res://data","res://ui","res://aircraft","res://showcase","res://iowa/scripts","res://iowa/scenes"]: hash_tree(path,result)
	return result

func hash_tree(path: String, result: Dictionary) -> void:
	for file: String in DirAccess.get_files_at(path):
		if file.get_extension() in ["gd","tscn","gdshader","json"]:
			var file_path: String = path.path_join(file)
			result[file_path] = FileAccess.get_sha256(file_path)
	for directory_name: String in DirAccess.get_directories_at(path):
		if directory_name in ["screenshots","evidence","references","target"]: continue
		hash_tree(path.path_join(directory_name),result)
