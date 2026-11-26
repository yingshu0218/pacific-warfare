extends "res://tests/fixtures/combat_test.gd"

const TRAIN: Script = preload("res://tests/fixtures/aircraft_training_fixture.gd")
var records: Array[Dictionary] = []

func reject_case(label: String, world: SimulationWorld, kind: String, options: Dictionary = {}) -> void:
	var submission: Dictionary = TRAIN.order(world,kind,1,"drill",options)
	expect(submission.receipt.accepted,"Schema routes capability check: "+label)
	world.step_ticks(1)
	var result: Dictionary = TRAIN.record(world)
	expect(result.status == "failed" and not result.reason.is_empty(),"Unsafe/unsupported entry rejected with real order reason: "+label)
	expect(not world.get_unit("pilot").module_data.has("aircraft_training"),"Reject does not install a training controller: "+label)
	records.append({"case":label,"status":result.status,"reason":result.reason})

func boundary_case(label: String) -> void:
	var world: SimulationWorld = TRAIN.world()
	var submission: Dictionary = TRAIN.order(world,"axial_roll")
	expect(submission.receipt.accepted,"Boundary case admitted")
	world.step_ticks(60)
	var unit: UnitState = world.get_unit("pilot")
	# Deliberate boundary inputs, not a claimed natural maneuver trajectory.
	match label:
		"low_altitude": unit.position_m.y = 200
		"stall": unit.velocity_mps = unit.velocity_mps.normalized()*20
		"overspeed": unit.velocity_mps = unit.velocity_mps.normalized()*290
		"fuel": unit.module_data.aircraft_motion.fuel_kg = 0
		"power": unit.module_data["damage"] = {"propulsion_factor":0.0}
		"control": unit.module_data["damage"] = {"control_factor":0.0}
		"damage": unit.module_data["damage"] = {"structure":.9,"structure_max":1.0}
	var previous: Quaternion = unit.world_transform().basis.get_rotation_quaternion()
	world.step_ticks(2)
	var state: Dictionary = unit.module_data.aircraft_training
	expect(TRAIN.record(world).status == "failed" and state.status == "aborted","Actual unsafe state aborts within2 ticks: "+label)
	expect(not unit.module_data.get("aircraft_control",{}).has("lift_plane_normal") and previous.angle_to(unit.world_transform().basis.get_rotation_quaternion()) < deg_to_rad(4),"Safety regain is continuous, no forced leveling: "+label)
	records.append({"case":"injected_boundary_"+label,"reason":state.reason,"safety":unit.module_data.aircraft_motion.safety_state})

func replacement_case(cancel: bool) -> void:
	var world: SimulationWorld = TRAIN.world()
	TRAIN.order(world,"axial_roll")
	world.step_ticks(60)
	var unit: UnitState = world.get_unit("pilot")
	var before: Transform3D = unit.world_transform()
	if cancel:
		var command: BattleCommand = BattleCommand.new()
		command.command_id = "cancel_training"
		command.issuer_id = "s14_exercise_director"
		command.source = "human"
		command.faction_id = "us"
		command.kind = BattleCommand.CANCEL_ORDER
		command.payload = {"order_id":"drill","reason":"training_viewer_cancel"}
		var receipt: Dictionary = world.submit_command(command)
		expect(receipt.accepted,"Cancel through unified command admission")
	else: AircraftFixture.order(world,"navigation",["pilot"],"patrol","",Vector3(0,2400,-5000),500)
	world.step_ticks(1)
	expect(TRAIN.record(world).status == ("cancelled" if cancel else "superseded") and unit.module_data.aircraft_training.status == "aborted","New command/cancel releases training and preserves terminal result")
	expect(before.basis.get_rotation_quaternion().angle_to(unit.world_transform().basis.get_rotation_quaternion()) < deg_to_rad(2) and unit.active,"Replacing training never snaps pose or disables healthy aircraft")

func genuine_damage_case() -> void:
	var a: Dictionary = AircraftDamageFixture.arena("us_f6f5_1944",2400)
	var world: SimulationWorld = a.world
	var registered: Dictionary = world.register_module(AircraftTasks.new())
	expect(registered.accepted,"Real damage drill uses same task handler")
	var submitted: Dictionary = TRAIN.order(world,"axial_roll",1,"drill",{},"target")
	expect(submitted.receipt.accepted,"Real damage drill admitted")
	world.step_ticks(45)
	world.drain_events()
	AircraftDamageFixture.shoot(a,"engine",14)
	var hits: int = 0
	for i: int in 12:
		world.step_ticks(1)
		for event: BattleEvent in world.drain_events():
			if event.kind == "hit" and event.target_id == "target": hits += 1
	var unit: UnitState = world.get_unit("target")
	expect(hits>0 and unit.module_data.damage.parts.engine==0 and TRAIN.record(world).status=="failed","Genuine swept engine hits abort the active drill")
	expect(unit.active and unit.module_data.aircraft_motion.safety_state=="glide" and unit.module_data.aircraft_training.status=="aborted","Engine failure hands control to existing glide safety, retains DM behavior")
	records.append({"case":"genuine_engine_projectiles","hits":hits,"training":unit.module_data.aircraft_training,"damage":unit.module_data.damage})

func clock_case() -> void:
	var a: SimulationWorld = TRAIN.world()
	var b: SimulationWorld = TRAIN.world()
	TRAIN.order(a,"axial_roll");TRAIN.order(b,"axial_roll")
	a.step_ticks(240)
	for i: int in 60: b.advance(1.0/15)
	expect(a.get_unit("pilot").snapshot()==b.get_unit("pilot").snapshot(),"Training fixed tick equals15fps external cadence")
	var before: Dictionary = b.get_unit("pilot").snapshot()
	b.set_paused(true)
	for i: int in 60: b.advance(1.0/30)
	expect(before==b.get_unit("pilot").snapshot(),"Pause freezes roll progress and all actual state")
	b.set_paused(false);b.set_time_scale(2)
	for i: int in 60: b.advance(1.0/30)
	a.step_ticks(240)
	expect(a.get_unit("pilot").snapshot()==b.get_unit("pilot").snapshot(),"2x same simulation time is bit-identical")
	b.reset()
	expect(not b.get_unit("pilot").module_data.has("aircraft_training") and not b.get_unit("pilot").module_data.has("aircraft_control"),"Reset clears training memory and controls")
	var receipt: Dictionary = TRAIN.order(b,"axial_roll")
	b.step_ticks(1)
	expect(receipt.receipt.accepted and b.get_unit("pilot").module_data.aircraft_training.status=="executing","Same stable orderID can start again after generation reset")

func run_test() -> void:
	reject_case("low_start",TRAIN.world("us_f6f5_1944",500),"axial_roll")
	reject_case("stall_entry",TRAIN.world("us_f6f5_1944",2400,40),"axial_roll")
	reject_case("fast_entry",TRAIN.world("us_f6f5_1944",2400,230),"bank_turn")
	reject_case("high_altitude_fast_entry",TRAIN.world("us_f6f5_1944",10000,210),"bank_turn")
	reject_case("low_fuel_entry",TRAIN.world("us_f6f5_1944",2400,115,{"fuel_kg":1}),"bank_turn")
	reject_case("split_envelope",TRAIN.world("us_f6f5_1944",1200),"split_s")
	reject_case("invalid_direction",TRAIN.world(),"axial_roll",{"direction":0})
	reject_case("unknown_maneuver",TRAIN.world(),"barrel_roll")
	reject_case("SB2C_base",TRAIN.world("us_sb2c4_1944"),"axial_roll")
	reject_case("SB2C_S14_subclass",TRAIN.world("us_sb2c4_1944",2400,115,{},true),"axial_roll")
	for label: String in ["low_altitude","stall","overspeed","fuel","power","control","damage"]: boundary_case(label)
	var friends: SimulationWorld = AircraftFixture.world([AircraftFixture.spawn("pilot","us",Vector3(0,2400,0),"us_f6f5_1944",0,115),AircraftFixture.spawn("friend","us",Vector3(80,2400,0),"us_f6f5_1944",0,115)])
	TRAIN.order(friends,"axial_roll")
	friends.step_ticks(1)
	expect(TRAIN.record(friends).status=="failed" and friends.get_unit("pilot").module_data.aircraft_training.reason=="training_friendly_conflict","Nearby friendly aircraft aborts a drill without using enemy positions")
	var timed: SimulationWorld = TRAIN.world()
	TRAIN.order(timed,"bank_turn",1,"drill",{"max_duration_s":5})
	timed.step_ticks(330)
	expect(TRAIN.record(timed).status=="failed" and timed.get_unit("pilot").module_data.aircraft_training.reason=="training_timeout","Finite timeout releases a still-incomplete drill")
	replacement_case(false);replacement_case(true)
	genuine_damage_case()
	clock_case()
	var override: SimulationWorld = TRAIN.world("us_f6f5_1944",2400,115,{},true)
	TRAIN.order(override,"bank_turn")
	override.step_ticks(1000)
	expect(TRAIN.record(override).status=="completed","S14 task override inherits the fighter training API with no Session change")
	var file: FileAccess = FileAccess.open("res://docs/showcase/evidence/S04-training/safety.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(AircraftDamageFixture.json_data({"scope":"Boundary state perturbations are explicit tests, not demonstration motion; engine case uses genuine projectiles.","checks":checks,"failures":failures,"cases":records}),"\t"))
	finish("S04 training safety")
