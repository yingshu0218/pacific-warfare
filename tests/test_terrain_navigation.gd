extends SceneTree
var failures: PackedStringArray=[]
var results: Dictionary={}
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
func run() -> void:
	var world: SimulationWorld=FleetFixture.world([FleetFixture.spawn("ship",Vector3(-2350,0,-6500),0,-PI*.5)])
	check(BattlefieldTerrain.install(world,"res://data/maps/island_harbor.json").is_empty(),"map installed")
	var goal: Vector3=Vector3(350,0,-6500)
	FleetFixture.order(world,"around_island",["ship"],"regroup","",goal,100)
	var chart: Dictionary=TerrainNavigation.chart(world.shared_state.terrain,115.0*.55+45.0)
	var track: Array=[];var collisions: int=0;var detours: int=0;var brake_samples: int=0
	var previous: Vector3=world.get_unit("ship").position_m
	var max_step: float=0.0
	for tick: int in 72000:
		world.step_ticks(1);world.drain_events()
		var unit: UnitState=world.get_unit("ship")
		max_step=maxf(max_step,previous.distance_to(unit.position_m))
		if TerrainNavigation.blocked(previous,unit.position_m,chart.shapes):collisions+=1
		previous=unit.position_m
		var reason: String=unit.module_data.ship_motion.avoidance_reason
		if reason=="coast_detour":detours+=1
		if reason=="coast_braking":brake_samples+=1
		if tick%120==0:track.append({"time_s":world.time_s(),"position_m":SimData.array3(unit.position_m),"speed_mps":unit.velocity_mps.length(),"reason":reason})
		if unit.position_m.distance_to(goal)<100:break
	check(collisions==0,"continuous hull margin never enters island")
	check(max_step<.31,"no teleport or discontinuous motion")
	check(detours>0,"actual coast_detour state occurred")
	check(world.get_unit("ship").position_m.distance_to(goal)<100,"actual ship finishes detour and reaches goal")
	results.detour={"track":track,"collisions":collisions,"detour_ticks":detours,"brake_ticks":brake_samples,"max_step_m":max_step,"end_distance_m":world.get_unit("ship").position_m.distance_to(goal),"time_s":world.time_s()}
	# A land destination is explicitly blocked, without a false task completion.
	var blocked: SimulationWorld=FleetFixture.world([FleetFixture.spawn("ship",Vector3(0,0,-4000),0,0)])
	BattlefieldTerrain.install(blocked,"res://data/maps/island_harbor.json")
	FleetFixture.order(blocked,"unreachable",["ship"],"regroup","",Vector3(-5500,0,-4900),100)
	blocked.step_ticks(600)
	var unit: UnitState=blocked.get_unit("ship")
	check(unit.velocity_mps.length()<.01 and unit.position_m.distance_to(Vector3(0,0,-4000))<.01,"unreachable destination stops ship")
	check(unit.task.ship.phase=="blocked" and unit.task.ship.reason=="coast_unreachable","real task reports unreachable")
	results.unreachable={"task":FleetFixture.json_data(unit.task.ship),"orders":blocked.orders_snapshot()}
	blocked.drain_events()
	unit.target_id="stale_target_before_loss"
	unit.active=false
	blocked.step_ticks(3)
	var invalid_release_commands: int=0
	for event: BattleEvent in blocked.drain_events():
		if event.kind=="command_rejected" and str(event.data.get("command_id","")).begins_with("ship_target:"):invalid_release_commands+=1
	check(invalid_release_commands==0,"inactive own recipient release sends no invalid clear-target command")
	results.inactive_release_rejections=invalid_release_commands
	results.failures=failures
	var file: FileAccess=FileAccess.open("res://docs/showcase/evidence/S09/navigation_checks.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(results,"\t"));file.close()
	for failure: String in failures:push_error("S09 navigation: "+failure)
	print("S09 actual navigation: ","PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
