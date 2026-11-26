extends SceneTree

const DIRECTOR: Script = preload("res://scripts/showcase/expansion/expansion_missions.gd")
var checks: Array[Dictionary] = []
var failed: int = 0
var output: String = "res://s14_integration.json"
var mode: String = "assembly"

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--case="): mode = arg.trim_prefix("--case=")
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks.append({"passed":ok,"label":label})
	if not ok: failed += 1; printerr("CHECK FAILED ",label)

func open_case(case_mode: String) -> FirstPlayableSession:
	var session: FirstPlayableSession = FirstPlayableSession.new()
	var errors: PackedStringArray = session.load_battle("res://data/scenarios/s14_expansion_"+case_mode+".json")
	check(errors.is_empty(),case_mode+" admitted registration "+str(errors))
	if not errors.is_empty(): return session
	check(session.world.register_module(DIRECTOR.new(case_mode)).accepted,"director uses normal high-level command module")
	session.refresh_view(true)
	return session

func run() -> void:
	var result: Dictionary = {}
	if mode == "assembly": result = assembly()
	else: result = cycle(mode)
	result.merge({"mode":mode,"checks":checks,"failed":failed})
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(json_data(result),"\t"))
	print("S14_EXPANSION ",mode," checks=",checks.size()," failed=",failed)
	quit(0 if failed == 0 else 1)

func assembly() -> Dictionary:
	var s: FirstPlayableSession = open_case("carrier_gunnery")
	if failed > 0: return {}
	check(s.world.unit_ids().size()==23,"19 existing +2 carriers +2 actual parked F6F")
	var modules: Dictionary = s.world.snapshot().modules
	check(modules.has("aircraft_tasks") and modules.has("aircraft_motion") and modules.has("carrier_operations") and modules.has("carrier_deck_motion"),"single existing aircraft tasks/motion with OPS/deck writers")
	check(s.world.shared_state.terrain.source.id == "island_harbor_expanded","MAP02 same-source terrain installed")
	var map: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/island_harbor_expanded.json"))
	check(map.deployment_sites.size()==7,"seven real ground sites retained")
	var instances: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/map02/facility_instances.json"))
	check(instances.instances.size()==99,"99 published facilities retained")
	for id: String in ["us_cv","jp_cv"]:
		var unit: UnitState = s.world.get_unit(id)
		var def: UnitDefinition = s.catalog.unit(unit.definition_id)
		var model: Node3D = (load(def.model_scene) as PackedScene).instantiate() as Node3D
		root.add_child(model)
		check(def.mounts.size()==(25 if id=="us_cv" else 14),id+" all model mounts registered")
		for mount: MountSocket in def.mounts:
			for train: float in [0.0,.35,-.35]:
				model.apply_state({"position_m":Vector3.ZERO,"rotation_rad":Vector3.ZERO,"weapons":{mount.id:{"train_rad":train,"elevation_rad":.30}}})
				for i: int in range(mount.muzzle_positions_m.size()):
					var expect: Transform3D = mount.local_muzzle_transform(i,train,.30)
					var actual: Transform3D = model.muzzle_transform_local(mount.id,i)
					check(expect.origin.distance_to(actual.origin)<.006 and expect.basis.z.distance_to(actual.basis.z)<.001,id+" actual model muzzle "+mount.id+"/"+str(i)+" at "+str(train))
		model.free()
	var events: Array = []
	for i: int in range(60*45):
		s.world.step_ticks(1)
		for event: BattleEvent in s.consume_world():
			if event.kind == "fired" and event.entity_id in ["us_cv","jp_cv"]: events.append(event.snapshot())
	for id: String in ["us_cv","jp_cv"]:
		check(events.any(func(e: Dictionary) -> bool: return e.entity_id == id),id+" actual combat firing, not decorative")
		check(float(s.world.get_unit(id).module_data.ship_motion.distance_m)>20,id+" original ShipMotion displacement")
	var partial: FirstPlayableSession = open_case("carrier_partial")
	partial.world.step_ticks(35);partial.consume_world()
	check(partial.orders.any(func(o: Dictionary) -> bool: return o.status == "failed" and o.reason == "carrier_complete_wave_required"),"unified executor rejection of partial deck wave")
	for id: String in ["us_deck_1","us_deck_2"]:
		check(str(partial.world.get_unit(id).module_data.carrier_ops.phase)=="standby","partial wave keeps "+id+" actually parked")
	var old: FirstPlayableSession = FirstPlayableSession.new()
	for case_mode: String in AllUnitsShowcase.MODES:
		check(old.load_battle("res://data/scenarios/s14_"+case_mode+".json").is_empty(),"preserved old mode "+case_mode)
		check(old.world.unit_ids().size()==19,"old mode has19 units "+case_mode)
	return {"carrier_fired_events":events,"partial_orders":partial.orders,"partial_journal":partial.journal}

func cycle(case_mode: String) -> Dictionary:
	var s: FirstPlayableSession = open_case(case_mode)
	if failed > 0: return {}
	var ops: CarrierOperations = s.carrier_operations as CarrierOperations
	var events: Array = []
	var trace: Array = []
	var recent_events: Array = []
	var start_ids: Array = ops.roster.keys()
	var completed: bool = false
	for tick: int in range(60*2600):
		s.world.step_ticks(1)
		# Production advances several fixed ticks per copied view. Preserve every
		# physics tick/event while avoiding60 redundant23-unit snapshots/second.
		var drained: Array[BattleEvent] = []
		if tick%30 == 0: drained = s.consume_world()
		for event: BattleEvent in drained:
			if event.kind == "order_execution_changed": continue
			recent_events.append(event.snapshot())
			while recent_events.size()>120: recent_events.pop_front()
			if event.kind.begins_with("carrier_") or (event.entity_id in start_ids or event.target_id in start_ids) and event.kind in ["unit_surface_contact","unit_impact","hit","damaged","damage_phase","aircraft_exit","order_status_changed"]: events.append(event.snapshot())
		if tick%120 == 0:
			var units: Dictionary = {}
			for id: String in start_ids:
				var u: UnitState = s.world.get_unit(id)
				units[id]={"position_m":u.position_m,"velocity_mps":u.velocity_mps,"rotation_rad":u.rotation_rad,"ops":u.module_data.carrier_ops.duplicate(true),"fuel_kg":u.module_data.aircraft_motion.fuel_kg,"active":u.active}
			trace.append({"time_s":s.world.time_s(),"units":units,"fuel_stock_kg":ops.fuel_stock_kg,"ammo_stock_rounds":ops.ammo_stock_rounds})
			if tick%3600==0: print("CYCLE_PROGRESS ",case_mode," t=",s.world.time_s()," ",ops.roster)
		var ready: bool = true
		for id: String in start_ids:
			var state: Dictionary = ops.roster[id]
			if int(state.recoveries)<2 or str(state.phase)!="standby" or not bool(state.get("service_done",false)): ready = false
		if ready:
			for event: BattleEvent in s.consume_world():
				if event.kind.begins_with("carrier_"): events.append(event.snapshot())
			completed = true; break
		if start_ids.any(func(id: String) -> bool: return str(ops.roster[id].phase) in ["lost","diverted"]):
			for event: BattleEvent in s.consume_world():
				recent_events.append(event.snapshot())
				events.append(event.snapshot())
			break
	check(completed,"same actual aircraft completes2 takeoffs,2 recoveries and finite services")
	check(ops.roster.keys()==start_ids,"aircraft identity retained for second wave")
	check(ops.fuel_stock_kg<2000 and ops.fuel_stock_kg>=0 and ops.ammo_stock_rounds>=0,"finite mother fuel/ammo stock conserved")
	for id: String in start_ids:
		check(events.any(func(e: Dictionary) -> bool: return e.entity_id==id and e.kind=="carrier_wire_caught"),id+" real tailhook wire capture")
		check(s.world.get_unit(id).active,id+" remains actually active after two waves")
	var final_units: Dictionary = {}
	for id: String in start_ids:
		final_units[id] = s.world.get_unit(id).snapshot()
		final_units[id]["terrain_height_m"] = TerrainQueries.height_data(s.world.shared_state.terrain,s.world.get_unit(id).position_m,true)
	return {"time_s":s.world.time_s(),"completed":completed,"operations":ops.snapshot_state(),"orders":s.world.orders_snapshot(),"events":events,"trace":trace,"recent_events":recent_events,"final_units":final_units,"carrier_final":s.world.get_unit("us_cv").snapshot()}

static func json_data(value: Variant) -> Variant:
	if value is Vector3: return SimData.array3(value)
	if value is Dictionary:
		var out: Dictionary = {}
		for key: String in value: out[key] = json_data(value[key])
		return out
	if value is Array:
		var out: Array = []
		for item: Variant in value: out.append(json_data(item))
		return out
	return value
