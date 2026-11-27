extends SceneTree

const G4M: String = "res://data/scenarios/s14_intercept_g4m.json"
const B25: String = "res://data/scenarios/s14_intercept_b25.json"
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var cases: Array[Dictionary] = [
		{"name":"g4m_default","source":G4M,"change":0.0,"direction":0.0},
		{"name":"b25_default","source":B25,"change":0.0,"direction":0.0},
		{"name":"g4m_upper","source":G4M,"change":260.0,"direction":1.0},
		{"name":"g4m_lower","source":G4M,"change":-260.0,"direction":-1.0},
	]
	var selection: PackedStringArray = OS.get_cmdline_user_args()
	for entry: Dictionary in cases:
		if not selection.is_empty() and not selection.has(entry.name): continue
		_probe(entry)
	if selection.is_empty(): _check_clearance_and_fighter_reset()
	print("AIR ENGAGEMENT LAYERS failures=", failures)
	quit(1 if failures > 0 else 0)

func _probe(entry: Dictionary) -> void:
	var path: String = entry.source
	if absf(entry.change) > 0.1:
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		for spawn: Dictionary in data.spawns:
			if spawn.id == "fighter": spawn.position_m[1] += float(entry.change)
		path = "user://air_layer_" + str(entry.name) + ".json"
		var variant: FileAccess = FileAccess.open(path,FileAccess.WRITE)
		variant.store_string(JSON.stringify(data))
		variant.close()
	var session: FirstPlayableSession = FirstPlayableSession.new()
	var errors: PackedStringArray = session.load_battle(path)
	if not errors.is_empty():
		failures += 1
		push_error(str(entry.name) + ": " + str(errors))
		return
	var world: SimulationWorld = session.world
	var modes: Dictionary = {}
	var first_fire: Dictionary = {}
	var first_hit: Dictionary = {}
	var minimum_clearance: float = INF
	for tick: int in range(95*60):
		world.step_ticks(1)
		var fighter: UnitState = world.get_unit("fighter")
		var motion: Dictionary = fighter.module_data.get("aircraft_motion", {})
		minimum_clearance = minf(minimum_clearance,float(motion.get("height_agl_m",fighter.position_m.y)))
		var task: Dictionary = fighter.task.get("aircraft", {})
		var mode: String = str(task.get("maneuver_phase",""))
		if mode.begins_with("bomber_"): modes[mode] = int(modes.get(mode,0))+1
		for event: BattleEvent in world.drain_events():
			if event.entity_id != "fighter" or event.target_id not in ["bomber", "wing"]: continue
			var target: UnitState = world.get_unit(event.target_id)
			var sample: Dictionary = {"time":event.time_s,"target":event.target_id,"dy":fighter.position_m.y-target.position_m.y,"vy":fighter.velocity_mps.y,"mode":mode}
			if event.kind == "fired" and first_fire.is_empty(): first_fire = sample
			if event.kind == "hit" and first_hit.is_empty(): first_hit = sample
		if not first_hit.is_empty() and world.time_s() > float(first_hit.time)+0.3: break
	var direction: float = float(entry.direction)
	var sign_ok: bool = not first_fire.is_empty() and (absf(float(first_fire.dy)) >= 30.0 if direction == 0.0 else float(first_fire.dy) * direction >= 45.0 and float(first_fire.vy) * direction < -2.0)
	var passed: bool = not modes.is_empty() and minimum_clearance > 0.0 and sign_ok and not first_hit.is_empty()
	print(JSON.stringify({"id":entry.name,"pass":passed,"modes":modes,"first_fire":first_fire,"first_hit":first_hit,"min_agl":minimum_clearance}))
	if not passed: failures += 1

func _check_clearance_and_fighter_reset() -> void:
	var world: SimulationWorld = AircraftFixture.world([AircraftFixture.spawn("air_layer_test","us",Vector3(0,1550,0),"us_f6f5_1944",0,114.0)])
	var pilot: UnitState = world.get_unit("air_layer_test")
	var p: Dictionary = AircraftPerformance.new().profile(pilot.definition_id)
	var contact: Dictionary = AircraftFixture.contact("observed",Vector3(0,1800,-1100),Vector3(0,0,-85.0))
	contact["role"] = "level_bomber"
	var result: Dictionary = AirCombatTactics.decide(pilot,p,{},contact,[contact],Vector3.FORWARD,0.0,1480.0)
	var floor_ok: bool = result.mode == "bomber_layer_upper" and not result.permit_fire and (result.direction as Vector3).y > 0.0
	var memory: Dictionary = {}
	contact = AircraftFixture.contact("new_fighter",Vector3(0,1550,-90),Vector3(0,0,-85.0))
	contact["role"] = "fighter"
	var up: Dictionary = AirCombatTactics.decide(pilot,p,{"fighter_passes":1-posmod(pilot.id.hash(),2)},contact,[contact],Vector3.FORWARD,0.0)
	memory["fighter_passes"] = posmod(pilot.id.hash(),2)
	var down: Dictionary = AirCombatTactics.decide(pilot,p,memory,contact,[contact],Vector3.FORWARD,0.0)
	var variety_ok: bool = (up.direction as Vector3).y > 0.0 and (down.direction as Vector3).y < 0.0 and not up.permit_fire and not down.permit_fire
	print("AIR LAYER detailed checks: clearance=",floor_ok," fighter_passes=",variety_ok)
	if not floor_ok or not variety_ok: failures += 1
