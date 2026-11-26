extends SceneTree

const MAIN: PackedScene=preload("res://showcase/carrier_harbor.tscn")
const INDEX: Dictionary={"attack_sb2c":24,"attack_d4y":25,"attack_g4m":26,"attack_b25":27,"intercept_g4m":28,"intercept_b25":29}
var game: AllUnitsShowcase
var mode: String="attack_b25"
var take: String="inventory"
var output: String=""
var frames: int=360
var events: Array=[]
var samples: Array=[]
var installations: Array=[]

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--case="):mode=arg.trim_prefix("--case=")
		if arg.begins_with("--take="):take=arg.trim_prefix("--take=")
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
		if arg.begins_with("--frames="):frames=int(arg.trim_prefix("--frames="))
	call_deferred("run")

func advance(ticks: int, display: bool=true) -> void:
	game.session.world.step_ticks(ticks)
	var current: Array[BattleEvent]=game.session.consume_world()
	for event: BattleEvent in current:
		if event.kind.begins_with("bomb") or event.kind in ["fired","damaged","damage_phase","aircraft_part_detached","unit_surface_contact","unit_impact","order_issued","order_status_changed"]:events.append(event.snapshot())
	if display:
		game.apply_presentation(current);game._update_guide(float(ticks)/60.0);game.hud.refresh(game.session,game.camera.mode,game.camera.shot_label);game._refresh_guide_ui()

func shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var error: Error=root.get_texture().get_image().save_png(output.path_join(name+".png"))
	if error!=OK:push_error("Capture write failed "+str(error))

func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	game=MAIN.instantiate() as AllUnitsShowcase;root.add_child(game)
	await process_frame;game.set_process(false)
	if not game.running:quit(1);return
	if take=="inventory":
		for key: String in INDEX:
			game.choose_exercise(INDEX[key]);advance(60)
			installations.append(check_markers(key));await shot(key)
		game.hud.cinema=false;game.hud.expanded=true;game.hud._layout();advance(5);await shot("actual_orders")
	else:
		game.choose_exercise(INDEX[mode])
		var ready: bool=false
		for i: int in range(1200):
			advance(30,false)
			var unit: UnitState=game.session.world.get_unit("bomber")
			var phase: String=str(unit.module_data.get("bombing",{}).get("phase",""))
			if take=="release" and phase in ["stabilize","dive"] and float(unit.module_data.bomb_rack.bay)>=.99:ready=true
			elif take=="damage" and game.session.world.unit_ids().any(func(id: String)->bool:return game.session.world.get_unit(id).module_data.get("damage",{}).get("phase","")=="crashing"):ready=true
			elif take=="sea":
				for id: String in game.session.world.unit_ids():
					var u: UnitState=game.session.world.get_unit(id)
					if u.module_data.has("bomb_rack") and u.module_data.damage.phase=="crashing" and u.position_m.y<180:ready=true
			if ready:break
			if i%120==0:print("NATIVE_PREROLL ",mode," ",take," ",game.session.world.time_s()," ",phase)
		if not ready:push_error("Actual requested capture phase not reached");game.free();quit(1);return
		for frame: int in range(frames):
			advance(4)
			samples.append({"time_s":game.session.world.time_s(),"units":game.session.units.duplicate(true),"label":game.guide_status.text,"detail":game.get("operation_text").text,"camera_position":game.camera.position,"camera_focus":game.camera.focus,"bombs":bomb_snapshots()})
			await shot("frame_%04d"%frame)
	var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://source-manifest.json"))
	FileAccess.open(output.path_join("capture.json"),FileAccess.WRITE).store_string(JSON.stringify(clean({"mode":mode,"take":take,"fps":15,"frames":samples.size(),"sampling_is_not_performance":true,"samples":samples,"events":events,"installations":installations,"source_manifest":source}),"\t"))
	game.free();await process_frame;quit()

func bomb_snapshots() -> Array:
	var result: Array=[]
	if game.session.bomb_stores==null:return result
	for p: CombatProjectiles.Round in game.session.bomb_stores.projectiles.rounds.values():
		if p.release_mode=="gravity_release":result.append(p.snapshot())
	return result

func check_markers(key: String) -> Dictionary:
	var rows: Array=[];var max_error: float=0
	for id: String in game.session.world.unit_ids():
		var u: UnitState=game.session.world.get_unit(id)
		if not u.module_data.has("bomb_rack"):continue
		var p: Dictionary=game.session.bomb_stores.parameters.aircraft[u.definition_id]
		for i: int in u.module_data.bomb_rack.slots.size():
			var expected: Vector3=u.world_transform()*BombStores.local_slot(p,u.module_data.bomb_rack,i)
			var actual: Vector3=game.models[id].slot_position(i)
			max_error=maxf(max_error,expected.distance_to(actual));rows.append({"unit":id,"slot":i,"expected":expected,"actual":actual})
	if max_error>.006:push_error("Actual integrated release marker mismatch "+key+" "+str(max_error))
	return {"case":key,"slots":rows,"max_error_m":max_error}

static func clean(value: Variant) -> Variant:
	if value is Vector3:return SimData.array3(value)
	if value is Dictionary:
		var result: Dictionary={}
		for key: String in value:result[key]=clean(value[key])
		return result
	if value is Array:
		var result: Array=[]
		for item: Variant in value:result.append(clean(item))
		return result
	return value
