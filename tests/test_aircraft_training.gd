extends "res://tests/fixtures/combat_test.gd"

const TRAIN: Script = preload("res://tests/fixtures/aircraft_training_fixture.gd")
var records: Array[Dictionary] = []

func run_case(definition_id: String, kind: String, direction: int) -> void:
	var world: SimulationWorld = TRAIN.world(definition_id)
	var receipt: Dictionary = TRAIN.order(world,kind,direction)
	expect(receipt.receipt.accepted,"Unified order admission "+definition_id+"/"+kind)
	var unit: UnitState = world.get_unit("pilot")
	var p: Dictionary = AircraftPerformance.new().profile(definition_id)
	var previous: Quaternion = unit.world_transform().basis.get_rotation_quaternion()
	var maximum_step: float = 0
	var maximum_roll_rate: float = 0
	var maximum_load: float = 0
	var minimum_up: float = 1
	var min_pitch: float = 0
	var max_pitch: float = 0
	var min_bank: float = 0
	var max_bank: float = 0
	var reference_roll: float = 0
	var maximum_reference_roll: float = 0
	var samples: Array[Dictionary] = []
	for tick: int in 3700:
		world.step_ticks(1)
		var flight: Dictionary = unit.module_data.aircraft_motion
		var basis: Basis = unit.world_transform().basis
		var q: Quaternion = basis.get_rotation_quaternion()
		maximum_step = maxf(maximum_step,previous.angle_to(q)); previous = q
		maximum_roll_rate = maxf(maximum_roll_rate,absf(float(flight.body_roll_rate_radps)))
		maximum_load = maxf(maximum_load,float(flight.load_factor))
		minimum_up = minf(minimum_up,basis.y.dot(AircraftFlightMath.level_up(unit.velocity_mps.normalized(),basis.y)))
		min_pitch = minf(min_pitch,float(flight.path_pitch_rad));max_pitch = maxf(max_pitch,float(flight.path_pitch_rad))
		min_bank = minf(min_bank,float(flight.bank_rad));max_bank = maxf(max_bank,float(flight.bank_rad))
		reference_roll += float(flight.body_roll_rate_radps)/60
		maximum_reference_roll = maxf(maximum_reference_roll,absf(reference_roll))
		if tick%6 == 0: samples.append({"time_s":world.time_s(),"position_m":unit.position_m,"velocity_mps":unit.velocity_mps,"rotation_rad":unit.rotation_rad,"load_g":flight.load_factor,"bank_rad":flight.bank_rad,"pitch_rad":flight.path_pitch_rad,"training":unit.module_data.get("aircraft_training",{}).duplicate(true)})
		if TRAIN.record(world).status in BattleOrder.TERMINAL: break
	var order_record: Dictionary = TRAIN.record(world)
	var final: Dictionary = unit.module_data.get("aircraft_training",{})
	expect(order_record.status == "completed" and final.get("status","") == "completed",definition_id+" "+kind+" geometry completes, actual="+str(final))
	expect(maximum_roll_rate <= deg_to_rad(float(p.roll_rate_degps))+.001 and maximum_load <= float(p.spatial.operating_load_g)+.001 and maximum_step < deg_to_rad(2),"Existing roll/load/slew limits and continuous pose preserved")
	expect(unit.active and not unit.module_data.has("aircraft_control") and str(final.get("phase","")) == "completed","Completion releases training ownership/control, aircraft stays active")
	if kind == "axial_roll":
		expect(float(final.get("peak_roll_rad",0)) >= TAU and maximum_reference_roll >= TAU and minimum_up < -.95,"Real complete360 roll crosses inverted, independent motion roll integral also exceeds2PI")
		expect(unit.world_transform().basis.y.dot(Vector3.UP) > .98 and float(final.height_change_m) < -20,"Full roll recovers upright after physical gravity/altitude loss")
	elif kind == "bank_turn": expect(absf(float(final.get("heading_change_rad",0))) > deg_to_rad(85) and maxf(absf(min_bank),absf(max_bank)) > deg_to_rad(55),"Coordinated high-bank turn bends the actual heading")
	elif kind == "climb_dive": expect(float(final.get("peak_height_m",0)) >= 2500 and min_pitch < deg_to_rad(-5) and max_pitch > deg_to_rad(5),"Actual climb and dive, not a visual pitch animation")
	elif kind == "roll_reversal": expect(min_bank < deg_to_rad(-55) and max_bank > deg_to_rad(55),"Actual roll reversal establishes both opposite banks")
	elif kind == "split_s": expect(float(final.get("bend_rad",0)) > deg_to_rad(165) and float(final.height_change_m) < -200 and minimum_up < -.95 and min_pitch < deg_to_rad(-70),"Half roll then true gravity/lift half-loop reverses flight path with real altitude loss")
	records.append({"definition_id":definition_id,"maneuver":kind,"direction":direction,"order_status":order_record.status,"final":final,"maximum_step_rad":maximum_step,"maximum_roll_rate_radps":maximum_roll_rate,"maximum_load_g":maximum_load,"minimum_up_dot":minimum_up,"maximum_reference_roll_rad":maximum_reference_roll,"samples":samples})

func run_test() -> void:
	for definition_id: String in ["us_f6f5_1944","jp_a6m5a_1944"]:
		for kind: String in AircraftTraining.KINDS: run_case(definition_id,kind,1 if definition_id == "us_f6f5_1944" else -1)
	var file: FileAccess = FileAccess.open("res://docs/showcase/evidence/S04-training/mechanisms.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(AircraftDamageFixture.json_data({"checks":checks,"failures":failures,"cases":records}),"\t"))
	finish("S04 real aircraft training")
