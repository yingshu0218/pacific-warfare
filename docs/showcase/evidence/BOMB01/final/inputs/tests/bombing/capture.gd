extends SceneTree
const FIX: Script=preload("res://tests/bombing/fixture.gd")
const VIEW: Script=preload("res://scripts/bombing/aircraft_view.gd")
func _initialize() -> void:call_deferred("run")
func build(id: String, case_id: String = "") -> Dictionary:
	if not case_id.is_empty():
		var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/bombing/data/scenarios.json"))
		var case_data: Dictionary=data.cases[case_id]
		var fixture: Dictionary=FIX.arena(case_data.spawns,true,true,null,false,true)
		assert(fixture.world.register_module(load("res://scripts/bombing/commander.gd").new(case_data.goals)).accepted)
		return fixture
	var p: Dictionary=FIX.parameters().aircraft[id]
	var a: Dictionary=FIX.arena([FIX.spawn("bomber","us",Vector3(0,float(p.entry_altitude_m),5500),id,Vector3(0,0,-float(p.attack_mps)))])
	assert(FIX.order(a.world,["bomber"],str(p.mode),"",{"center_m":[0.,0.,0.],"radius_m":300.}).accepted)
	return a
func run() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	AudioServer.set_bus_mute(0,true)
	var case_id: String="";var observed: String="bomber"
	var id: String="us_b25j_1944_07";var out: String="res://.local/native"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--type="):id=arg.get_slice("=",1)
		if arg.begins_with("--case="):case_id=arg.get_slice("=",1)
		if arg.begins_with("--output="):out=arg.get_slice("=",1)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	var find: Dictionary=build(id,case_id);var first_tick: int=-1
	for i: int in 150*60:
		find.world.step_ticks(1)
		for event: BattleEvent in find.world.drain_events():
			if case_id.begins_with("intercept_"):
				if event.kind=="damaged" and event.target_id in ["bomber","wing"]:first_tick=event.tick;observed=event.target_id
			elif event.kind=="bomb_released":first_tick=event.tick
		if first_tick>=0:break
	assert(first_tick>=0,"natural release/damage must occur before capture")
	id=(find.world as SimulationWorld).get_unit(observed).definition_id
	FIX.dispose(find)
	var a: Dictionary=build(id,case_id);var world: SimulationWorld=a.world
	world.step_ticks(maxi(0,first_tick-60));world.drain_events()
	var viewport: SubViewport=SubViewport.new();viewport.size=Vector2i(960,540);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var scene: Node3D=Node3D.new();viewport.add_child(scene)
	var env: WorldEnvironment=WorldEnvironment.new();var settings: Environment=Environment.new();settings.background_mode=Environment.BG_COLOR;settings.background_color=Color("819cad");settings.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;settings.ambient_light_color=Color("bdd1db");settings.ambient_light_energy=.7;settings.tonemap_mode=Environment.TONE_MAPPER_FILMIC;env.environment=settings;scene.add_child(env)
	var light: DirectionalLight3D=DirectionalLight3D.new();light.rotation_degrees=Vector3(-35,-35,0);light.light_energy=1.6;scene.add_child(light)
	var ocean: MeshInstance3D=MeshInstance3D.new();var plane: PlaneMesh=PlaneMesh.new();plane.size=Vector2(100000,100000);ocean.mesh=plane;var material: StandardMaterial3D=StandardMaterial3D.new();material.albedo_color=Color("174659");material.roughness=.6;ocean.material_override=material;scene.add_child(ocean)
	var view: Node3D=VIEW.new(id);scene.add_child(view)
	var peers: Dictionary={}
	for unit_id: String in world.unit_ids():
		if unit_id==observed:continue
		var unit: UnitState=world.get_unit(unit_id)
		var node: Node3D
		if FIX.parameters().aircraft.has(unit.definition_id):node=VIEW.new(unit.definition_id)
		elif world.unit_definition(unit.definition_id).domain=="aircraft":
			node=AircraftAdapter.new();node.set("model_id",unit.definition_id)
		else:node=load(world.unit_definition(unit.definition_id).model_scene).instantiate()
		scene.add_child(node);peers[unit_id]=node
	if world.shared_state.has("terrain"):
		var land: Node3D=load("res://scripts/map02/expanded_map_view.gd").new();scene.add_child(land);land.call("build",world.shared_state.terrain)
	var camera: Camera3D=Camera3D.new();camera.far=120000.;camera.fov=48.;scene.add_child(camera);camera.current=true
	var effects: CombatEffects=load("res://scripts/bombing/effects.gd").new();effects.sound_enabled=false;scene.add_child(effects)
	var overlay: Label=Label.new();overlay.position=Vector2(22,18);overlay.add_theme_font_size_override("font_size",18);overlay.add_theme_color_override("font_shadow_color",Color.BLACK);overlay.add_theme_constant_override("shadow_offset_x",2);overlay.add_theme_constant_override("shadow_offset_y",2);viewport.add_child(overlay)
	var frame_count: int=600 if case_id.begins_with("intercept_") else 390
	var visuals: Dictionary={};var events: Array=[];var samples: Array=[];var comparisons: Array=[];var focus: Vector3=world.get_unit(observed).position_m
	for frame: int in frame_count:
		var batch: Array[BattleEvent]=[]
		for tick: int in 4:
			world.step_ticks(1)
			for event: BattleEvent in world.drain_events():
				batch.append(event)
				if event.kind in ["bomb_released","bomb_source_cleared","bomb_contact","bomb_explosion","bombing_phase","hit","damaged","disabled","aircraft_part_detached","aircraft_breakup","unit_impact"]:events.append(event.snapshot())
				if event.kind=="bomb_released" and event.entity_id==observed:
					view.call("apply",world.get_unit(observed))
					var marker: Vector3=view.call("slot_position",int(event.data.slot))
					comparisons.append({"tick":event.tick,"slot":event.data.slot,"distance_m":marker.distance_to(event.position_m)})
		view.call("apply",world.get_unit(observed))
		for unit_id: String in peers:
			var peer: Node3D=peers[unit_id]
			var unit: UnitState=world.get_unit(unit_id)
			if peer.has_method("apply"):peer.call("apply",unit)
			elif peer.has_method("apply_state"):peer.call("apply_state",unit.snapshot())
			else:peer.position=unit.position_m;peer.rotation=unit.rotation_rad
		for key: String in a.projectiles.rounds:
			var p: CombatProjectiles.Round=a.projectiles.rounds[key]
			if p.release_mode!="gravity_release":continue
			if not visuals.has(key):
				var source: Node3D=view.call("bomb_template",p.slot)
				var bomb: Node3D=source.duplicate() as Node3D;bomb.transform=Transform3D.IDENTITY;bomb.visible=true;scene.add_child(bomb);visuals[key]=bomb
			var bomb: Node3D=visuals[key];bomb.position=p.position_m
			if p.velocity_mps.length()>1:bomb.basis=AircraftFlightMath.frame(p.forward_m,p.up_m)
		for key: String in visuals.keys():
			if not a.projectiles.rounds.has(key):visuals[key].queue_free();visuals.erase(key)
		effects.consume(batch,world.generation);effects.apply_snapshot(world.snapshot());effects.advance(1.0/15.0)
		var age: float=world.time_s()-float(first_tick)/60.
		if case_id.begins_with("intercept_"):
			focus=world.get_unit(observed).position_m
			focus.y=maxf(focus.y,0.0) # Observer stays above actual sea contact.
			camera.position=focus+Vector3(18,8,26)
		elif age<3.6:
			focus=world.get_unit(observed).position_m
			camera.position=focus+world.get_unit(observed).world_transform().basis*Vector3(13,-6,19)
		else:
			if not a.projectiles.rounds.is_empty():focus=(a.projectiles.rounds.values()[0] as CombatProjectiles.Round).position_m
			camera.position=focus+Vector3(8,5,12).lerp(Vector3(45,28,58),clampf((150.0-focus.y)/130.0,0.0,1.0))
		camera.look_at(focus,Vector3.UP)
		var unit: UnitState=world.get_unit(observed)
		overlay.text="%s | t %.2fs | tick %d\n%s | bombs %d/%d | actual fixed 60Hz / capture 15fps"%[id,world.time_s(),world.tick,unit.module_data.bombing.phase,unit.module_data.bomb_rack.remaining,unit.module_data.bomb_rack.slots.size()]
		await process_frame
		RenderingServer.force_draw(false,0)
		assert(viewport.get_texture().get_image().save_png(out.path_join("frame_%05d.png"%frame))==OK)
		samples.append({"frame":frame,"tick":world.tick,"time_s":world.time_s(),"unit":unit.snapshot(),"projectiles":a.projectiles.snapshot_state()})
	var record: Dictionary={"type":id,"case_id":case_id,"observed_unit_id":observed,"fps":15,"frames":frame_count,"first_observed_event_tick":first_tick,"scope":"same natural initial state replay; camera only; actual model and inventory; no interpolation or Chrome claim","slot_comparisons":comparisons,"events":events,"samples":samples}
	var file: FileAccess=FileAccess.open(out.path_join("capture.json"),FileAccess.WRITE);file.store_string(JSON.stringify(FIX.json_data(record)));file.close()
	viewport.queue_free();FIX.dispose(a)
	await process_frame
	print("BOMB01_CAPTURE ",id," frames",frame_count)
	quit()
