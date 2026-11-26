extends SceneTree

const REVIEW: Script = preload("res://tests/fixtures/dm01_review_stage.gd")
var output: String = "res://.local/dm01-frames/assembly"
var definition_id: String = "us_f6f5_1944"
var case_name: String = "wing_left"
var seconds: float = 8
var include_fx: bool = false
var fps: int = 15

func _initialize() -> void: call_deferred("run")

func run() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	AudioServer.set_bus_mute(0,true)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--definition="): definition_id = arg.get_slice("=",1)
		if arg.begins_with("--case="): case_name = arg.get_slice("=",1)
		if arg.begins_with("--output="): output = arg.get_slice("=",1)
		if arg.begins_with("--seconds="): seconds = float(arg.get_slice("=",1))
		if arg == "--fx": include_fx = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	root.size = Vector2i(1100,700)
	var view: SubViewport = SubViewport.new()
	view.size = Vector2i(1100,700)
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var review: Node3D = REVIEW.new()
	review.definition_id = definition_id
	review.case_name = case_name
	review.include_fx = include_fx
	view.add_child(review)
	var samples: Array[Dictionary] = []
	for frame: int in int(seconds*fps):
		review.advance_steps(60/fps)
		if frame%3 == 0: samples.append(review.snapshot())
		await process_frame
		RenderingServer.force_draw(false,0)
		var error: Error = view.get_texture().get_image().save_png(output.path_join("frame_%04d.png"%frame))
		if error != OK:
			push_error("DM01 PNG capture failed")
			quit(1)
			return
	var final: Dictionary = review.snapshot()
	var counts: Dictionary = final.event_counts
	var valid: bool = int(counts.get("fired",0))>0 and int(counts.get("hit",0))>0 and int(counts.get("damaged",0))>0 and (not include_fx or int(final.peak_effect_meshes)>0)
	if case_name != "engine": valid = valid and int(counts.get("aircraft_part_detached",0))>0
	if case_name == "breakup": valid = valid and int(counts.get("unit_surface_contact",0))==1 and int(counts.get("unit_impact",0))==1 and int(final.peak_visible_effect_kinds.get("water",0))>0
	if not valid:
		push_error("DM01 capture lacks genuine damage/effects: "+str(final))
		quit(1)
		return
	var file: FileAccess = FileAccess.open(output.path_join("capture.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(AircraftDamageFixture.json_data({"scope":"Controlled existing-ammo projectile review, not default/natural AI battle or performance benchmark.","fps":fps,"frames":int(seconds*fps),"resolution":[1100,700],"include_fx":include_fx,"samples":samples,"events":review.event_log}),"\t"))
	print("DM01 native controlled review PASS ",definition_id," ",case_name," frames=",int(seconds*fps)," peak_fragments=",review.maximum_fragments)
	quit(0)
