extends SceneTree

const MOTION: Script = preload("res://scripts/behaviors/aircraft/autonomous_fighter_motion.gd")
const EXPANDED: Script = preload("res://scripts/showcase/expansion/expansion_missions.gd")
const SCENES: Array[String] = ["res://data/scenarios/s14_expansion_harbor.json","res://data/scenarios/s14_maneuver.json"]
const TYPES: Array[String] = ["us_f6f5_1944","jp_a6m5a_1944"]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("AIR02 requires a JSON output path")
		quit(1)
		return
	var rules_ok: bool = _check_intent_rules() and _check_order_handoff() and _check_bank_reversal()
	if args.has("rules-only"):
		quit(0 if rules_ok else 1)
		return
	var prefix: String = args[0]
	var seed_value: int = int(args[1]) if args.size() > 1 else 707
	var duration: int = 105
	var failed: bool = not rules_ok
	var results: Array[Dictionary] = []
	for path: String in SCENES:
		var session: FirstPlayableSession = FirstPlayableSession.new()
		var errors: PackedStringArray = session.load_battle(path)
		if not errors.is_empty():
			push_error(str(errors))
			quit(1)
			return
		var world: SimulationWorld = session.world
		var mode: String = session.scenario.showcase.mode
		var module: SimulationModule = EXPANDED.new(mode) if session.scenario.has("carrier_operations") else ShowcaseMissions.new(mode)
		if not world.register_module(module).accepted:
			push_error("Failed to install normal Showcase missions in "+mode)
			quit(1)
			return
		if not world.reset(seed_value):
			push_error("AIR02 could not reset the official scenario")
			quit(1)
			return
		var fighter_ids: Array[String] = []
		var definitions: Dictionary = {}
		for id: String in world.unit_ids():
			var definition: String = world.get_unit(id).definition_id
			definitions[id] = definition
			if definition in TYPES: fighter_ids.append(id)
		var events: Array[Array] = []
		var samples: Array[Array] = []
		var motion_trace: Array[Dictionary] = []
		var previous_motion: Dictionary = {}
		var completed: Dictionary = {}
		var order_replacements: Array[Dictionary] = []
		var peak_body_step_rad: float = 0.0
		var max_motion_clearance_error: float = 0.0
		for idx: int in duration*world.tick_hz:
			world.step_ticks(1)
			for e: BattleEvent in world.drain_events():
				if e.kind == "order_assignments_changed":
					_record_replacements(world, e.data, fighter_ids, order_replacements)
				if e.kind in ["bomb_released", "bomb_contact", "bomb_explosion", "unit_surface_contact", "aircraft_exit"] or (e.kind=="fired" and (e.entity_id in fighter_ids or e.weapon_id.ends_with("/dorsal"))):
					events.append([e.time_s,e.entity_id,e.target_id,e.kind,e.weapon_id])
			for id: String in fighter_ids:
				var u: UnitState = world.get_unit(id)
				var f: Dictionary = u.module_data.get("aircraft_motion",{})
				var a: Dictionary = u.task.get("aircraft",{})
				var motion: Dictionary = f.get("autonomous_maneuver", {})
				if not motion.is_empty():
					var signature: Array = [motion.sequence, motion.phase, motion.status]
					if previous_motion.get(id, []) != signature:
						previous_motion[id] = signature
						motion_trace.append({"id": id, "definition":u.definition_id, "at_s":world.time_s(), "state":motion.duplicate(true)})
						if motion.status == "completed":
							if not completed.has(u.definition_id):
								completed[u.definition_id] = {}
							completed[u.definition_id][motion.kind] = int(completed[u.definition_id].get(motion.kind, 0)) + 1
							if motion.kind == "oblique_roll_arc" and (float(motion.peak_lateral_offset_m) < 130.0 or float(motion.height_span_m) < 160.0):
								push_error("Oblique roll lacked measured lateral or vertical displacement")
								failed = true
							var heading: float = float(motion.arc_turn_rad)
							if motion.kind == "rising_arc" and (float(motion.peak_gain_m) < 235.0 or heading < deg_to_rad(95.0)):
								push_error("Rising arc completed without the actual gain and heading change")
								failed = true
							if motion.kind in ["axial_roll", "oblique_roll_arc"] and float(motion.peak_roll_rad) < deg_to_rad(348.0):
								push_error("Axial roll completed without the actual rotation")
								failed = true
							if motion.kind == "bank_reversal" and (float(motion.initial_turn_rad) < deg_to_rad(29.0) or float(motion.opposite_turn_rad) < deg_to_rad(52.0)):
								push_error("Reversal completed without two established turns")
								failed = true
					if motion.status == "executing" and u.active:
						peak_body_step_rad = maxf(peak_body_step_rad, (f.body_angular_velocity_radps as Vector3).length() * world.fixed_delta_s())
						max_motion_clearance_error = maxf(max_motion_clearance_error, -float(f.height_agl_m))
				if world.tick % 10 != 0:
					continue
				var target_id: String = a.get("target_id","")
				var target: UnitState = world.get_unit(target_id) if target_id in fighter_ids else null
				if not f or not a or not u.active or u.module_data.get("damage",{}).get("phase","operational")!="operational": continue
				if target==null or not target.active or target.faction_id==u.faction_id or target.module_data.get("damage",{}).get("phase","operational")!="operational":continue
				if a.get("phase","") in ["training","withdraw","search"]:continue
				var geometry: Dictionary = a.get("spatial_geometry",{})
				samples.append([world.time_s(),id,target_id,str(a.get("phase","")),str(a.get("maneuver_phase","")),snappedf(u.position_m.x,.01),snappedf(u.position_m.y,.01),snappedf(u.position_m.z,.01),snappedf(rad_to_deg(f.bank_rad),.01),snappedf(rad_to_deg(f.path_pitch_rad),.01),snappedf(u.velocity_mps.y,.01),str(f.safety_state),str(geometry.get("last_exit","")),snappedf(rad_to_deg(f.get("body_roll_rate_radps",0.)),.01)])
		results.append({"scenario":mode,"seed":world.seed_value,"time_s":world.time_s(),"definitions":definitions,"samples":samples,"events":events,"motion_trace":motion_trace,"order_replacements":order_replacements,"completed":completed,"peak_body_step_deg":rad_to_deg(peak_body_step_rad)})
		print(mode, " seed ", seed_value, " completed ", completed, " max body step ", rad_to_deg(peak_body_step_rad))
		# The reference seed must show both profiles in both regular entries.
		# Other seeds can terminate a valid maneuver through normal game state.
		for definition: String in TYPES:
			if seed_value == 707 and completed.get(definition, {}).is_empty():
				push_error("Missing physically completed autonomous motion: " + mode + "/" + definition)
				failed = true
		if peak_body_step_rad > deg_to_rad(4.0) or max_motion_clearance_error > 0.0:
			push_error("Discontinuous body motion or surface penetration")
			failed = true
	var file: FileAccess = FileAccess.open(prefix,FileAccess.WRITE)
	if file == null:
		push_error("Failed to open AIR02 output")
		quit(1)
		return
	file.store_string(JSON.stringify(results)+"\n")
	file.close()
	quit(1 if failed else 0)

func _check_intent_rules() -> bool:
	var unit: UnitState = UnitState.new()
	unit.definition_id = "us_f6f5_1944"
	unit.position_m = Vector3(0, 2400, 0)
	unit.velocity_mps = Vector3.FORWARD * 132.0
	var profile: Dictionary = AircraftPerformance.new().profile(unit.definition_id)
	var flight: Dictionary = {"bank_rad":0.0, "path_pitch_rad":0.0, "height_agl_m":2400.0, "distance_m":2200.0,
		"safety_state":"normal", "exited":false, "body_roll_rate_radps":0.0,
		"autonomous_maneuver":{"next_entry_distance_m":3000.0, "sequence":1}}
	unit.module_data["aircraft_motion"] = flight
	var task: Dictionary = {}
	for second: int in range(10):
		flight.distance_m += 440.0
		MOTION.start(unit, profile, task, float(second), 500.0, Vector3.FORWARD)
	if task.has("autonomous_motion"):
		push_error("Steady flight started a maneuver after crossing the cooldown distance")
		return false
	var climb: Vector3 = AircraftFlightMath.direction(deg_to_rad(65.0), deg_to_rad(27.0))
	if MOTION.select_shape(unit, profile, climb, 500.0) != "oblique_roll_arc":
		push_error("Climb and horizontal turn demand should admit an oblique roll with room")
		return false
	flight.bank_rad = deg_to_rad(55.0)
	var opposite: Vector3 = AircraftFlightMath.direction(deg_to_rad(60.0), 0.0)
	if MOTION.select_shape(unit, profile, opposite, 500.0) != "bank_reversal":
		push_error("Opposite horizontal turn demand should select a reversal")
		return false
	if MOTION.select_shape(unit, profile, Vector3.FORWARD, 500.0) != "axial_roll":
		push_error("Returning from bank to level flight should admit an axial roll")
		return false
	MOTION.start(unit, profile, task, 11.0, 500.0, opposite)
	MOTION.start(unit, profile, task, 11.5, 500.0, opposite)
	if not task.has("autonomous_motion"):
		push_error("Persistent turn demand did not start the requested maneuver")
		return false
	flight.height_agl_m = 220.0
	MOTION.step(unit, profile, task, 11.6)
	if task.has("autonomous_motion") or flight.autonomous_maneuver.status != "aborted" or flight.autonomous_maneuver.reason != "altitude_margin":
		push_error("Loss of clearance failed to publish an abort")
		return false
	flight.height_agl_m = 2400.0
	unit.velocity_mps = Vector3.FORWARD * 65.0
	if not str(MOTION.select_shape(unit, profile, climb, 500.0)).is_empty():
		push_error("Low energy admitted a maneuver")
		return false
	var executor: AircraftTasks = AircraftTasks.new()
	var order: BattleOrder = BattleOrder.new()
	order.order_type = "intercept"
	order.issuer_id = "air_post"
	order.target_id = "fighter_contact"
	order.area = {"center_m":[0.0, 2000.0, 0.0], "radius_m":2500.0}
	var renewal: Dictionary = order.request_data()
	renewal.area.center_m[2] = 250.0
	if not executor._same_fighter_order(order, renewal):
		push_error("Updating an AI track center interrupted the same objective")
		return false
	renewal.target_id = "other_fighter_contact"
	if executor._same_fighter_order(order, renewal):
		push_error("Target change was incorrectly treated as an order refresh")
		return false
	renewal.target_id = order.target_id
	renewal.source = "human"
	if executor._same_fighter_order(order, renewal):
		push_error("Human takeover was incorrectly treated as an AI order refresh")
		return false
	print("AIR02 intent, clearance, energy, and order continuity checks passed")
	return true

func _record_replacements(world: SimulationWorld, previous: Dictionary, fighter_ids: Array[String], rows: Array[Dictionary]) -> void:
	for id: String in fighter_ids:
		var execution: Dictionary = previous.execution.get(id, {})
		if execution.get("reason","") != "replacement_order_received" or int(execution.changed_tick) != world.tick:
			continue
		var replacement: Dictionary = world.order_snapshot(execution.replacement_order_id, previous.faction_id)
		rows.append({"id":id, "time_s":world.time_s(), "order":previous.order_id, "order_type":previous.order_type, "target_id":previous.target_id,
			"replacement":replacement.order_id, "replacement_type":replacement.order_type, "replacement_target_id":replacement.target_id})

func _check_order_handoff() -> bool:
	var start: Vector3 = Vector3(0, 2400, 0)
	var first_point: Vector3 = Vector3(-1500, 3460, -1380)
	var second_point: Vector3 = Vector3(-1900, 3580, -1420)
	var world: SimulationWorld = AircraftFixture.world([
		AircraftFixture.spawn("pilot", "jp", start, "jp_a6m5a_1944", 0.0, 132.0),
		AircraftFixture.spawn("contact_a", "us", first_point, "us_f6f5_1944"),
		AircraftFixture.spawn("contact_b", "us", second_point, "us_f6f5_1944")])
	var first: Dictionary = AircraftFixture.contact("contact_a", first_point)
	var second: Dictionary = AircraftFixture.contact("contact_b", second_point)
	first["role"] = "fighter"
	second["role"] = "fighter"
	AircraftFixture.contacts(world, "jp", [first, second])
	AircraftFixture.order(world, "engage_original", ["pilot"], "intercept", "contact_a", first_point)
	var pilot: UnitState = world.get_unit("pilot")
	var started: Dictionary = {}
	for tick: int in range(90):
		world.step_ticks(1)
		started = pilot.module_data.aircraft_motion.get("autonomous_maneuver", {})
		if started.get("status","") == "executing":
			break
	if started.get("status","") != "executing":
		push_error("Order handoff fixture never executed an autonomous maneuver")
		return false
	AircraftFixture.order(world, "engage_refreshed", ["pilot"], "intercept", "contact_a", first_point + Vector3(60, 0, 20))
	world.step_ticks(1)
	var refreshed: Dictionary = pilot.module_data.aircraft_motion.autonomous_maneuver
	if pilot.active_order_id != "engage_refreshed" or refreshed.status != "executing" or refreshed.sequence != started.sequence or refreshed.started_s != started.started_s:
		push_error("Refreshing an existing objective lost the running maneuver")
		return false
	AircraftFixture.order(world, "different_target", ["pilot"], "intercept", "contact_b", second_point)
	world.step_ticks(1)
	var redirected: Dictionary = pilot.module_data.aircraft_motion.autonomous_maneuver
	if pilot.active_order_id != "different_target" or redirected.status != "aborted" or redirected.reason != "replacement_order_received":
		push_error("Replacing the objective did not release the maneuver")
		return false
	if not world.reset() or world.get_unit("pilot").module_data.aircraft_motion.has("autonomous_maneuver"):
		push_error("Restart retained a terminal maneuver")
		return false
	print("AIR02 actual command refresh, replacement, and reset checks passed")
	return true

func _check_bank_reversal() -> bool:
	for definition: String in TYPES:
		var spawn: Dictionary = AircraftFixture.spawn("pilot", "jp", Vector3(0, 2200, 0), definition, 0.0, 125.0)
		var tilted_up: Vector3 = Vector3.UP.rotated(Vector3.FORWARD, deg_to_rad(55.0))
		spawn.rotation_rad = SimData.array3(AircraftFlightMath.frame(Vector3.FORWARD, tilted_up).get_euler())
		var world: SimulationWorld = AircraftFixture.world([spawn])
		var unit: UnitState = world.get_unit("pilot")
		var f: Dictionary = unit.module_data.aircraft_motion
		var profile: Dictionary = AircraftPerformance.new().profile(definition)
		var task: Dictionary = {}
		var original_turn: Vector3 = AircraftFlightMath.direction(deg_to_rad(-80.0), 0.0)
		var opposite_turn: Vector3 = AircraftFlightMath.direction(deg_to_rad(75.0), 0.0)
		unit.module_data["aircraft_control"] = {"flight_direction":original_turn, "speed_mps":125.0}
		for tick: int in range(25):
			world.step_ticks(1)
			MOTION.start(unit, profile, task, world.time_s(), 0.0, opposite_turn)
			if task.has("autonomous_motion"):
				break
		if not task.has("autonomous_motion") or task.autonomous_motion.kind != "bank_reversal":
			push_error("Opposed heading request did not admit bank reversal for " + definition)
			return false
		for tick: int in range(1450):
			var command: Dictionary = MOTION.step(unit, profile, task, world.time_s())
			if command.is_empty():
				break
			unit.module_data["aircraft_control"] = {"flight_direction":command.direction, "speed_mps":command.speed_mps, "max_bank_rad":deg_to_rad(70.0)}
			world.step_ticks(1)
		var outcome: Dictionary = f.autonomous_maneuver
		if outcome.status != "completed" or float(outcome.initial_turn_rad) < deg_to_rad(29.0) or float(outcome.opposite_turn_rad) < deg_to_rad(52.0):
			push_error("Bank reversal did not establish two physical opposite turns for " + definition + " " + str(outcome))
			return false
		print("AIR02 bank reversal ", definition, " turns deg ", rad_to_deg(outcome.initial_turn_rad), "/", rad_to_deg(outcome.opposite_turn_rad),
			" height range m ", outcome.height_span_m, " lateral m ", outcome.peak_lateral_offset_m)
	return true
