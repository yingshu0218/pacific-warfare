extends SceneTree

var checks: Array[Dictionary] = []
var failed: int = 0
var details: Dictionary = {}
const HISTORY: Script = preload("res://scripts/presentation/state/pose_history.gd")
const SEA_MESH: Script = preload("res://scripts/presentation/environment/chart_water_mesh.gd")

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks.append({"passed":ok,"label":label})
	if not ok:failed+=1;printerr("CHECK FAILED ",label)

func key(code: int, pressed: bool, shift: bool = false) -> void:
	var event: InputEventKey=InputEventKey.new()
	event.physical_keycode=code;event.keycode=code;event.pressed=pressed;event.shift_pressed=shift
	Input.parse_input_event(event)
	await process_frame

func mouse_button(pressed: bool) -> void:
	var event: InputEventMouseButton=InputEventMouseButton.new()
	event.position=Vector2(900,450);event.button_index=MOUSE_BUTTON_RIGHT;event.pressed=pressed
	event.button_mask=MOUSE_BUTTON_MASK_RIGHT if pressed else 0
	Input.parse_input_event(event);await process_frame

func mouse_motion(relative: Vector2) -> void:
	var event: InputEventMouseMotion=InputEventMouseMotion.new()
	event.position=Vector2(900,450);event.relative=relative;event.button_mask=MOUSE_BUTTON_MASK_RIGHT
	Input.parse_input_event(event);await process_frame

func run() -> void:
	var game: AllUnitsShowcase=(load("res://showcase/carrier_harbor.tscn") as PackedScene).instantiate() as AllUnitsShowcase
	root.add_child(game);await process_frame;game.set_process(false)
	check(game.running,"normal expanded scene assembles")
	check(not game.guide.active and game.camera.mode=="auto","normal harbor defaults to actual event observation")
	var labels: Array=[]
	for button: Node in game.hud.root.find_children("*","Button",true,false):labels.append((button as Button).text)
	check(labels.has("实际交战") and labels.has("港湾导览"),"combat and optional map tour have explicit visible controls")
	game.choose_exercise(27);game.session.world.set_paused(true)
	game._action("camera","free")
	var tick: int=game.session.world.tick
	var origin: Vector3=game.camera.focus
	await key(KEY_W,true);game._process(.1);await key(KEY_W,false)
	var normal_distance: float=game.camera.focus.distance_to(origin)
	check(normal_distance>1,"W moves in paused ordinary scene without Shift")
	check(not game.guide.active,"keyboard takeover stops director")
	origin=game.camera.focus
	await key(KEY_UP,true);game._process(.1);await key(KEY_UP,false)
	check(absf(game.camera.focus.distance_to(origin)-normal_distance)<.03,"ArrowUp matches W canvas translation")
	origin=game.camera.focus
	await key(KEY_SHIFT,true);await key(KEY_W,true,true);game._process(.1);await key(KEY_W,false);await key(KEY_SHIFT,false)
	check(absf(game.camera.focus.distance_to(origin)/normal_distance-4.0)<.02,"Shift accelerates movement fourfold")
	origin=game.camera.focus
	await key(KEY_Q,true);game._process(.1);await key(KEY_Q,false)
	check(game.camera.focus.y>origin.y,"Q raises observer")
	await key(KEY_E,true);game._process(.1);await key(KEY_E,false)
	check(game.camera.focus.distance_to(origin)<.02,"E lowers observer with no horizontal drift")
	await mouse_button(true)
	var rotation_origin: Vector3=game.camera.position
	var cumulative_yaw: float=0
	for i: int in 5:
		var old_yaw: float=game.camera.yaw
		await mouse_motion(Vector2(300,0));game._process(.01)
		cumulative_yaw+=angle_difference(old_yaw,game.camera.yaw)
	check(absf(cumulative_yaw)>TAU,"right drag spans a full360-degree yaw")
	check(game.camera.position.distance_to(rotation_origin)<.02,"free-look rotates in place without orbiting or takeover jump")
	await mouse_motion(Vector2(0,-400));game._process(.01)
	check(game.camera.pitch<0,"manual orbit can look above the horizon")
	await mouse_button(false)
	await key(KEY_D,true);game.get_window().focus_exited.emit();origin=game.camera.focus;game._process(.1)
	check(game.camera.focus.distance_to(origin)<.001,"focus loss releases held translation")
	await mouse_button(true);game.get_window().focus_exited.emit()
	var held_yaw: float=game.camera.yaw
	await mouse_motion(Vector2(300,0))
	check(is_equal_approx(game.camera.yaw,held_yaw),"focus loss releases drag before returning motion")
	game.hud.speeds.grab_focus();origin=game.camera.focus
	details.focus_before={"owner":str(game.get_viewport().gui_get_focus_owner()),"keys":game.camera.get("_pressed_keys").duplicate(),"focus":SimData.array3(origin),"mode":game.camera.mode}
	await key(KEY_UP,true);game._process(.1);await key(KEY_UP,false)
	details.focus_after={"owner":str(game.get_viewport().gui_get_focus_owner()),"keys":game.camera.get("_pressed_keys").duplicate(),"focus":SimData.array3(game.camera.focus),"mode":game.camera.mode}
	check(game.camera.focus.distance_to(origin)<.001,"focused menu retains arrows without moving camera")
	game.get_viewport().gui_release_focus()
	game.segment_menu.get_popup().popup();origin=game.camera.focus
	await key(KEY_W,true);game._process(.1);await key(KEY_W,false)
	check(game.camera.focus.distance_to(origin)<.001,"open popup retains keyboard input")
	game.segment_menu.get_popup().hide();game.get_viewport().gui_release_focus()
	check(game.session.world.tick==tick,"all manual observation leaves paused simulation unchanged")
	await key(KEY_W,true);game._action("camera","auto");origin=game.camera.focus
	check(not bool(game.camera.get("_dragging")),"mode change releases drag")
	game._action("restart",null);game.session.world.set_paused(true);game.guide.active=false;game._action("camera","free");origin=game.camera.focus;game._process(.1)
	check(game.camera.focus.distance_to(origin)<.001,"restart does not retain held movement")
	check(game.session.presentation_time_s==0,"restart resets presentation clock")
	game.free();await process_frame
	check_quaternions()
	check_simulation_and_pause()
	check_water()
	await check_bomb_birth()
	check_ship_report()
	check_fragment_birth()
	var output: String="res://docs/showcase/evidence/RX02/mechanisms-r1.json"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"details":details},"\t"))
	print("RX02 checks=",checks.size()," failed=",failed);quit(0 if failed==0 else 1)

func check_quaternions() -> void:
	var pose: Vector3=HISTORY._rotation(Vector3(0,3.13,0),Vector3(0,-3.13,0),.5)
	var error: float=Basis.from_euler(pose).get_rotation_quaternion().angle_to(Basis(Vector3.UP,PI).get_rotation_quaternion())
	check(error<.001,"quaternion interpolation crosses Euler wrap through shortest attitude")

func check_simulation_and_pause() -> void:
	var a: FirstPlayableSession=FirstPlayableSession.new();var b: FirstPlayableSession=FirstPlayableSession.new()
	check(a.load_battle("res://data/scenarios/s14_attack_b25.json").is_empty() and b.load_battle("res://data/scenarios/s14_attack_b25.json").is_empty(),"two equal actual production scenarios load")
	# Controlled reader-off comparison; the discarded module has no order handler.
	b.world._modules.erase(b.get("_pose_history"))
	for i: int in 120:a.advance(1.0/120.0);b.world.advance(1.0/120.0,16)
	check(a.world.tick==b.world.tick and a.world.rng.state==b.world.rng.state,"read-only sampler preserves60Hz tick and RNG")
	check(a.world.unit_ids().all(func(id: String)->bool:return a.world.get_unit(id).snapshot()==b.world.get_unit(id).snapshot()),"reader and interpolation preserve every real unit snapshot")
	check(a.world.orders_snapshot()==b.world.orders_snapshot(),"presentation preserves real commander orders")
	a.advance(.003)
	var paused_pose: Dictionary=a.presentation_units.duplicate(true)
	var paused_time: float=a.presentation_time_s
	a.world.set_paused(true)
	for i: int in 12:a.advance(1.0/144.0)
	check(a.presentation_units==paused_pose and a.presentation_time_s==paused_time,"pause freezes the already displayed fractional pose and clock")
	a.world.set_paused(false);a.world.set_time_scale(2.0);a.advance(.01)
	check(a.presentation_time_s>paused_time and a.presentation_time_s<=a.world.time_s(),"2x advances one bounded authoritative presentation clock")
	var before: Dictionary=a.world.get_unit("bomber").snapshot()
	for i: int in 10:a.get("_pose_history").interpolate(a.units,float(i)/10)
	check(a.world.get_unit("bomber").snapshot()==before,"sampling interpolation never writes physical state")
	a.advance(1.0,1)
	check(a.world.pending_ticks()>0 and is_equal_approx(a.presentation_alpha,1.0) and is_equal_approx(a.presentation_time_s,a.world.time_s()),"backlog clamps to latest actual tick instead of extrapolation")
	check(a.restart() and a.presentation_time_s==0 and a.presentation_units.bomber.position_m==a.units.bomber.position_m,"world reset resets history without blending generations")

func check_water() -> void:
	var s: FirstPlayableSession=FirstPlayableSession.new();s.load_battle("res://data/scenarios/s14_expansion_harbor.json")
	var terrain: Dictionary=s.world.shared_state.terrain
	var mesh: ArrayMesh=SEA_MESH.new().build(terrain)
	var vertices: PackedVector3Array=mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var overlap_area: float=0;var land_centroids: int=0;var boundary_triangles: Array=[]
	for i: int in range(0,vertices.size(),3):
		var polygon: PackedVector2Array=PackedVector2Array()
		for j: int in 3:polygon.append(Vector2(vertices[i+j].x,vertices[i+j].z))
		if TerrainQueries.land_data(terrain,(vertices[i]+vertices[i+1]+vertices[i+2])/3):
			land_centroids+=1
			boundary_triangles.append({"area":absf(SEA_MESH._area(polygon)),"points":[SimData.array3(vertices[i]),SimData.array3(vertices[i+1]),SimData.array3(vertices[i+2])]})
		for island: Dictionary in terrain.islands:
			var coast: PackedVector2Array=PackedVector2Array()
			for point: Vector3 in island.outline:coast.append(Vector2(point.x,point.z))
			for intersection: PackedVector2Array in Geometry2D.intersect_polygons(polygon,coast):overlap_area+=absf(SEA_MESH._area(intersection))
	check(land_centroids==0 and overlap_area<1.0,"water triangles have no positive-area land overlap within numerical tolerance")
	check(vertices.size()/3<5000,"exact coast water mesh stays bounded below5000 triangles")
	var at_sea_level: bool=true
	for point: Vector3 in vertices:
		if point.y!=0:at_sea_level=false
	check(at_sea_level,"water remains at real sea level without floating terrain bias")
	details.water={"triangles":vertices.size()/3,"cells":mesh.get_meta("chart_water_cells"),"land_centroids":land_centroids,"overlap_area_m2":overlap_area}
	details.water.boundary_triangles=boundary_triangles

func check_bomb_birth() -> void:
	var s: FirstPlayableSession=FirstPlayableSession.new();s.load_battle("res://data/scenarios/s14_attack_b25.json")
	var model: Node3D=(load(s.catalog.unit("us_b25j_1944_07").model_scene) as PackedScene).instantiate() as Node3D
	root.add_child(model);await process_frame
	var renderer: Node3D=load("res://scripts/showcase/bombing/projectile_view.gd").new()
	root.add_child(renderer)
	var born: Dictionary={};var verified: bool=false;var marker_error: float=INF
	for tick: int in 60*55:
		var events: Array[BattleEvent]=s.advance(1.0/60.0)
		for event: BattleEvent in events:
			if event.kind=="bomb_released" and born.is_empty():born={"id":str(event.data.projectile_id),"tick":event.tick,"slot":int(event.data.slot),"position":event.position_m}
		if born.is_empty():continue
		if s.world.tick==int(born.tick):
			model.apply_state(s.presentation_units.bomber);renderer.present(s,{"bomber":model})
			check(not s.presentation_bombs.has(born.id),"detached bomb is hidden before its actual end-tick birth")
			check(not renderer.get("visuals").has(born.id),"actual bomb renderer has no early duplicate body")
			check(bool(s.presentation_units.bomber.module_data.bomb_rack.slots[int(born.slot)].loaded),"attached bomb remains until same presentation birth time")
		elif s.world.tick==int(born.tick)+1:
			var bomb: Dictionary=s.presentation_bombs.get(born.id,{})
			check(not bomb.is_empty(),"bomb appears at its real birth presentation time")
			model.apply_state(s.presentation_units.bomber)
			renderer.present(s,{"bomber":model})
			marker_error=(model.slot_position(int(born.slot)) as Vector3).distance_to(bomb.position_m)
			check(marker_error<.006 and (bomb.position_m as Vector3).distance_to(born.position)<.006,"same-frame body release marker and detached birth point match within6mm")
			check((renderer.get("visuals")[born.id] as Node3D).global_position.distance_to(born.position)<.006,"actual rendered bomb appears at same-frame birth marker")
			check(not bool(s.presentation_units.bomber.module_data.bomb_rack.slots[int(born.slot)].loaded),"attached slot clears when detached bomb appears")
			verified=true;break
	check(verified,"actual AI sortie reached release during bounded test")
	details.bomb_birth={"verified":verified,"marker_error_m":marker_error}
	model.free();renderer.free();await process_frame

func check_ship_report() -> void:
	# Controlled event-consumer/formatter input, not synthetic production damage.
	var s: FirstPlayableSession=FirstPlayableSession.new();s.load_battle("res://data/scenarios/s14_expansion_harbor.json")
	var event: BattleEvent=BattleEvent.new();event.kind="damage_phase";event.entity_id="jp_bb";event.sequence=1000000;event.data={"phase":"sinking"}
	var events: Array[BattleEvent]=[event];s.consume(events)
	check(s.report().jp.sinking==1 and s.report().jp.sunk==0,"sinking start is counted separately from already sunk")
	event=event.copy();event.sequence+=1;event.data={"phase":"wreck"};events=[event];s.consume(events)
	check(s.report().jp.sinking==0 and s.report().jp.sunk==1,"only actual ship wreck terminal advances sunk counter")
	check(ObserverText.ship_condition({"phase":"disabled","ship":{"flotation":100}}).contains("仍漂浮"),"afloat disabled condition is not labelled sunk")
	var view: Dictionary={"module_data":{"damage":{"propulsion_factor":.6,"control_factor":0,"fire_control_factor":.4},"combat_runtime":{"mount_efficiency":{"one":.8,"two":0}}},"weapons":{"one":{"enabled":true},"two":{"enabled":false}}}
	var summary: String=ObserverText.ship_functions(view)
	check(summary.contains("动力60%") and summary.contains("操舵0%") and summary.contains("火控40%") and summary.contains("1降效/1失效"),"module summary reads independent real factors and per-mount state")
	check(s.report().us.get("sinking",0)==0 and s.report().us.has("sunk"),"report keeps old sunk key and zero default for new sinking key")

func check_fragment_birth() -> void:
	var s: FirstPlayableSession=FirstPlayableSession.new();s.load_battle("res://data/scenarios/s14_intercept_b25.json")
	var born_tick: int=-1;var unit_id: String="";var born_position: Vector3=Vector3.ZERO;var verified: bool=false
	for i: int in 60*65:
		var events: Array[BattleEvent]=s.advance(1.0/60.0)
		for event: BattleEvent in events:
			if event.kind=="aircraft_part_detached" and born_tick<0:born_tick=event.tick;unit_id=event.entity_id;born_position=event.position_m
		if born_tick<0:continue
		var aircraft: Dictionary=s.presentation_units[unit_id].module_data.damage.aircraft
		if s.world.tick==born_tick:
			check(aircraft.detached_parts.is_empty() and aircraft.fragments.is_empty(),"attached part stays until real fragment display birth")
		elif s.world.tick==born_tick+1:
			check(aircraft.detached_parts.size()==1 and aircraft.fragments.size()==1,"part mask and fragment appear at identical presentation time")
			check((aircraft.fragments[0].position_m as Vector3).distance_to(born_position)<.006,"fragment first displayed position matches actual detached anchor")
			verified=true;break
	check(verified,"real interception produces a bounded fragment timing witness")
