extends SceneTree

const IDS: Array[String] = ["jp_harbor_aa_service","jp_harbor_aa_ridge","jp_airfield_aa"]
const SOURCE: String = "res://data/scenarios/s14_expansion_harbor.json"
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty() or args.has("scene"): _scene()
	for id: String in IDS:
		if args.is_empty() or args.has(id): _probe(id)
	print("PORT07 failures=",failures)
	quit(1 if failures else 0)

func _scene() -> void:
	var game: FirstPlayableGame=(load("res://showcase/carrier_harbor.tscn") as PackedScene).instantiate()
	root.add_child(game)
	game.set_process(false)
	_check(game.running,"actual harbor entry starts")
	if not game.running: return
	var ids: Dictionary = {}
	for id: String in IDS:
		var unit: UnitState = game.session.world.get_unit(id)
		var model: GroundUnitModel = game.models.get(id)
		_check(unit!=null and model!=null,"registered model "+id)
		if unit==null or model==null: continue
		ids[str(unit.module_data.ground_initial.site_id)] = true
		_check(unit.faction_id=="jp" and unit.weapons.size()==1,"independent faction unit "+id)
		_check(model.mount_sockets().size()==1,"visual mount "+id)
		_check(absf(model.position.y-TerrainQueries.height_m(game.session.world,unit.position_m))<.05,"grounded "+id)
	_check(ids.size()==3,"three separate sites")
	_check(game.map_view.has_node("HarborTown"),"town still loaded")
	game.free()

func _probe(id: String) -> void:
	var scenario: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	var chart: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(scenario.environment.terrain_path))
	var deployment: Dictionary={}
	for item: Dictionary in scenario.ground_deployments:
		if item.id==id: deployment=item
	if deployment.is_empty(): _check(false,"fixture deployment");return
	var site: Dictionary={}
	for item: Dictionary in chart.deployment_sites:
		if item.id==deployment.site_id: site=item
	var at: Vector3=SimData.vec3(site.position_m)
	# Controlled game target in each separate QA run. No authored hit, forced
	# fire or test change to the battle's ships/aircraft.
	var opponent: Dictionary={"id":"qa_air","faction_id":"us","unit_definition_id":"us_f6f5_1944",
		"position_m":SimData.array3(at+Vector3(0,350,920)),"rotation_rad":[0,0,0],"velocity_mps":[0,0,-100]}
	scenario["spawns"]=[opponent]
	scenario["groups"]=[]
	scenario["ground_deployments"]=[deployment]
	for key: String in ["carrier_operations","bombing_goals","aircraft_tasks_script","fleet_overrides"]: scenario.erase(key)
	scenario.presentation.names={"qa_air":"QA",id:"defence"}
	var path: String="user://port07_"+id+".json"
	var file: FileAccess=FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify(scenario))
	file.close()
	var session: FirstPlayableSession=FirstPlayableSession.new()
	var errors: PackedStringArray=session.load_battle(path)
	_check(errors.is_empty(),id+" init "+str(errors))
	if not errors.is_empty(): return
	var fired: int=0
	var active_task: bool=false
	for i: int in 25*60:
		session.world.step_ticks(1)
		var unit: UnitState=session.world.get_unit(id)
		active_task=active_task or not unit.task.get("ground",{}).is_empty()
		for event: BattleEvent in session.world.drain_events():
			if event.entity_id==id and event.kind=="fired" and event.target_id=="qa_air": fired+=1
		if fired>0: break
	_check(active_task and fired>0,id+" independent game fire")
	print("PORT07 probe ",id," active=",active_task," fire=",fired)

func _check(ok: bool,msg: String) -> void:
	if ok: return
	failures+=1
	push_error("PORT07 "+msg)
