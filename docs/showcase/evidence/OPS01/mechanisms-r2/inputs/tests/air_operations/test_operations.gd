extends SceneTree

const FIX: Script = preload("res://tests/air_operations/fixture.gd")
var results: Array[Dictionary] = []
var failures: int = 0

func check(ok: bool, name: String, detail: Variant = null) -> void:
	results.append({"passed":ok,"name":name,"detail":detail})
	if not ok: failures += 1; print("OPS01 FAIL ",name," ",detail)

func step(f: Dictionary, seconds: float) -> void:
	for i: int in roundi(seconds*60.0):
		(f.world as SimulationWorld).step_ticks(1)
		(f.world as SimulationWorld).drain_events()

func until_phase(f: Dictionary, id: String, phase: String, limit_s: float = 1000.0) -> bool:
	var world: SimulationWorld = f.world
	for i: int in roundi(limit_s*60.0):
		if f.operations.roster[id].phase == phase: return true
		world.step_ticks(1); world.drain_events()
	return false

func _initialize() -> void:
	_two_aircraft()
	_cancel_and_reassign()
	_wave_off_and_turn()
	_damage_and_fuel()
	_supply_limits()
	_touchdown_gates()
	_hard_deck_contact()
	_respot_cancellation()
	_rigid_pose()
	_base_loss_on_deck()
	_pause_rate_reset()
	var file: FileAccess = FileAccess.open("res://docs/showcase/evidence/OPS01/mechanisms.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(FIX.json_data({"failures":failures,"checks":results}),"\t")); file.close()
	print("OPS01 mechanisms ",results.size()," checks, failures=",failures)
	quit(0 if failures == 0 else 1)

func _two_aircraft() -> void:
	var f: Dictionary = FIX.build(2)
	var world: SimulationWorld = f.world
	var ops: CarrierOperations = f.operations
	check(FIX.sortie(world,["hellcat_1","hellcat_2"]).accepted,"two aircraft use common BattleOrder")
	var min_spacing: float = INF
	var max_ground_error: float = 0.0
	var max_kinematic_error: float = 0.0
	var max_velocity_jump: float = 0.0
	var previous: Dictionary = {}
	var fuel_start: float = 0.0
	for id: String in ops.roster:
		fuel_start += float(world.get_unit(id).module_data.aircraft_motion.fuel_kg)
		# Controlled inventory input, not an invented combat event. No weapon
		# executor runs here; this tests real WeaponState replenishment only.
		for weapon: WeaponState in world.get_unit(id).weapons.values(): weapon.remaining_rounds[0] -= 13
	var premature_refill: bool = false
	var landing_events: Array[Dictionary] = []
	for i: int in 60*1200:
		world.step_ticks(1)
		for event: BattleEvent in world.drain_events():
			if event.kind in ["carrier_touchdown","carrier_wire_caught","carrier_service_completed"]: landing_events.append(event.snapshot())
		var all_deck: bool = true
		for id: String in ops.roster:
			var unit: UnitState = world.get_unit(id)
			var s: Dictionary = ops.roster[id]
			if int(s.recoveries) == 0:
				for weapon: WeaponState in unit.weapons.values():
					if weapon.remaining_rounds[0] != 387: premature_refill = true
			if previous.has(id):
				var old: Dictionary = previous[id]
				max_kinematic_error = maxf(max_kinematic_error,unit.position_m.distance_to((old.p as Vector3)+((old.v as Vector3)+unit.velocity_mps)/120.0))
				max_velocity_jump = maxf(max_velocity_jump,unit.velocity_mps.distance_to(old.v))
			previous[id] = {"p":unit.position_m,"v":unit.velocity_mps}
			if s.on_deck:
				max_ground_error = maxf(max_ground_error,unit.position_m.distance_to(world.get_unit("essex").world_transform()*(s.local_m as Vector3)))
			else: all_deck = false
		if all_deck: min_spacing = minf(min_spacing,world.get_unit("hellcat_1").position_m.distance_to(world.get_unit("hellcat_2").position_m))
		if ops.roster.hellcat_1.recoveries == 1 and ops.roster.hellcat_2.recoveries == 1 and ops.roster.hellcat_1.phase == "standby" and ops.roster.hellcat_2.phase == "standby": break
	check(ops.roster.hellcat_1.recoveries == 1 and ops.roster.hellcat_2.recoveries == 1,"both aircraft complete actual recovery",world.time_s())
	check(min_spacing > 13.0,"deck aircraft do not pass through peers",min_spacing)
	check(max_ground_error < 0.001,"world deck transform exact while grounded",max_ground_error)
	check(max_kinematic_error < 0.06,"no teleport at wheel/flight transitions",max_kinematic_error)
	check(max_velocity_jump < 4.3,"velocity changes bounded including wheel normal impulse",max_velocity_jump)
	check(ops.strip_owner.is_empty() and ops.launch_queue.is_empty() and ops.recovery_queue.is_empty(),"all transient occupations released")
	var fuel_end: float = 0.0
	var burned: float = 0.0
	for id: String in ops.roster:
		fuel_end += float(world.get_unit(id).module_data.aircraft_motion.fuel_kg)
		burned += float(world.get_unit(id).module_data.aircraft_motion.fuel_used_kg)
	check(absf(fuel_start+ops.fuel_delivered_kg-burned-fuel_end) < 0.001,"fuel aircraft and base conservation",fuel_start+ops.fuel_delivered_kg-burned-fuel_end)
	check(absf(float(ops.parameters.fuel_stock_kg)-ops.fuel_delivered_kg-ops.fuel_stock_kg) < 0.001,"finite base fuel stock")
	check(not premature_refill,"ammo never replenished before physical recovery")
	check(ops.ammo_delivered == 156 and ops.ammo_stock_rounds == int(ops.parameters.ammo_stock_rounds)-156,"each real gun reloads once from finite base stock")
	var service_times_valid: bool = true
	for event: Dictionary in landing_events:
		if event.kind != "carrier_service_completed": continue
		var parked_s: float = -1.0
		for row: Dictionary in ops.history:
			if row.unit_id == event.entity_id and row.phase == "servicing": parked_s = float(row.time_s)
		if parked_s < 0 or float(event.time_s)-parked_s < 30.0-0.001: service_times_valid = false
	check(service_times_valid,"service timer begins only at physically parked recovery")
	var delivered: float = ops.fuel_delivered_kg
	step(f,40.0)
	check(is_equal_approx(delivered,ops.fuel_delivered_kg),"no repeated refuelling after service")
	check(FIX.sortie(world,["hellcat_1","hellcat_2"],"second_sortie").accepted,"repeat wave enters same command gate")
	var respot_seen: bool = false
	var minimum_respot_spacing: float = INF
	var previous_positions: Dictionary = {}
	var maximum_respot_error: float = 0.0
	for i: int in 60*1300:
		world.step_ticks(1)
		for event: BattleEvent in world.drain_events():
			if event.kind in ["carrier_touchdown","carrier_wire_caught","carrier_service_completed"]: landing_events.append(event.snapshot())
		for id: String in ops.roster:
			var unit: UnitState = world.get_unit(id)
			if previous_positions.has(id):
				var prev: Dictionary = previous_positions[id]
				maximum_respot_error = maxf(maximum_respot_error,unit.position_m.distance_to((prev.p as Vector3)+((prev.v as Vector3)+unit.velocity_mps)/120.0))
			previous_positions[id] = {"p":unit.position_m,"v":unit.velocity_mps}
			if ops.roster[id].phase == "respotting": respot_seen = true
		if ops.roster.hellcat_1.on_deck and ops.roster.hellcat_2.on_deck: minimum_respot_spacing = minf(minimum_respot_spacing,world.get_unit("hellcat_1").position_m.distance_to(world.get_unit("hellcat_2").position_m))
		if ops.roster.hellcat_1.recoveries == 2 and ops.roster.hellcat_2.recoveries == 2 and ops.roster.hellcat_1.phase == "standby" and ops.roster.hellcat_2.phase == "standby": break
	check(respot_seen and minimum_respot_spacing > 13.0,"continuous crew traction respots both aircraft without crossing",minimum_respot_spacing)
	check(maximum_respot_error < 0.06,"respot and second sortie never teleport",maximum_respot_error)
	check(ops.roster.hellcat_1.recoveries == 2 and ops.roster.hellcat_2.recoveries == 2,"second complete two-aircraft wave recovers and services",world.time_s())
	check(world.unit_ids().size() == 3 and ops.roster.size() == 2,"repeated sorties retain exactly two real aircraft instances")
	var file: FileAccess = FileAccess.open("res://docs/showcase/evidence/OPS01/two-aircraft.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(FIX.json_data({"history":ops.history,"events":landing_events,"final":ops.snapshot_state(),"orders":world.orders_snapshot()}),"\t")); file.close()

func _cancel_and_reassign() -> void:
	var f: Dictionary = FIX.build(2)
	var world: SimulationWorld = f.world
	var ops: CarrierOperations = f.operations
	FIX.sortie(world,["hellcat_1"],"cancel_me"); step(f,7)
	check(FIX.cancel(world,"cancel_me").accepted,"cancel taxi order queued")
	step(f,6)
	check(ops.strip_owner.is_empty() and ops.launch_queue.is_empty(),"cancel frees queue and strip")
	check((ops.roster.hellcat_1.relative_velocity_mps as Vector3).length() < 0.1,"cancelled aircraft brakes to physical stop")
	FIX.sortie(world,["hellcat_1"],"replacement"); step(f,1)
	check(ops.roster.hellcat_1.order_id == "replacement","replacement follows common order ownership")
	var orders: Array[Dictionary] = world.orders_snapshot()
	check(orders[0].status == "cancelled","cancelled command remains terminal in timeline")
	# Loss removes its queue entry; the second aircraft is not recreated.
	world.get_unit("hellcat_1").active = false
	FIX.sortie(world,["hellcat_2"],"survivor"); step(f,35)
	check(ops.roster.hellcat_2.sorties == 1 and ops.roster.hellcat_1.phase == "lost","one loss does not strand next launch")

func _wave_off_and_turn() -> void:
	var f: Dictionary = FIX.build()
	var world: SimulationWorld = f.world
	var ops: CarrierOperations = f.operations
	FIX.sortie(world,["hellcat_1"])
	check(until_phase(f,"hellcat_1","approach"),"approach reached by continuous flight")
	ops.external_block = true; step(f,1)
	check(ops.roster.hellcat_1.phase == "go_around" and ops.strip_owner.is_empty(),"occupied approach waves off and frees clearance")
	ops.external_block = false
	check(until_phase(f,"hellcat_1","approach"),"go around rejoins and actually flies second approach")
	world.get_unit("essex").module_data.ship_control.goal_m = world.get_unit("essex").position_m+Vector3(-20000,0,0)
	step(f,30)
	check(ops.roster.hellcat_1.phase == "go_around" or ops.roster.hellcat_1.phase == "return","real fleet turn interrupts landing")
	check(absf(float(world.get_unit("essex").module_data.ship_motion.turn_rate_radps)) > deg_to_rad(0.3),"carrier turn produced by fleet integrator")
	ops.available = false; step(f,20)
	check(ops.strip_owner.is_empty() and not ops.roster.hellcat_1.on_deck,"unavailable carrier does not snap aircraft aboard")
	check(world.get_unit("hellcat_1").position_m.y > 0.0,"waiting aircraft remains in actual flight")
	var file: FileAccess = FileAccess.open("res://docs/showcase/evidence/OPS01/waveoff.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(FIX.json_data(ops.snapshot_state()),"\t")); file.close()

func _damage_and_fuel() -> void:
	for kind: String in ["partial_engine","disabled_active","empty_fuel","terminal"]:
		var f: Dictionary = FIX.build(2)
		var world: SimulationWorld = f.world
		var damage: CombatDamage = FIX.damage_modules(f)
		FIX.sortie(world,["hellcat_1","hellcat_2"])
		check(until_phase(f,"hellcat_1","mission",100),kind+" enters real airborne state")
		var unit: UnitState = world.get_unit("hellcat_1")
		var before: Vector3 = unit.position_m
		if kind == "partial_engine": unit.module_data.damage.propulsion_factor = 0.35; unit.module_data.damage.parts.engine = 0.35
		elif kind == "disabled_active": unit.module_data.damage.phase = "disabled"
		elif kind == "empty_fuel": unit.module_data.aircraft_motion.fuel_kg = 0.0
		else: damage._disable(world,unit,"control")
		step(f,3)
		check(unit.position_m.distance_to(before) > 30.0,kind+" never freezes after OPS releases",unit.position_m.distance_to(before))
		check(not f.operations.roster.hellcat_1.on_deck and f.operations.strip_owner != "hellcat_1",kind+" has no OPS deck ownership")
		check(f.operations.roster.hellcat_2.sorties == 1,kind+" surviving queue progresses")
		if kind == "terminal": check(unit.module_data.damage.phase == "crashing" and unit.module_data.aircraft_motion.safety_state == "uncontrolled_damage","true terminal uses original DM integrator")
		elif kind == "empty_fuel": check(unit.module_data.aircraft_motion.safety_state == "glide","empty fuel uses inherited glide")
		else: check(f.operations.roster.hellcat_1.phase == "diverted","unfit airborne state remains counted without false loss")

func _touchdown_gates() -> void:
	var f: Dictionary = FIX.build()
	var world: SimulationWorld = f.world
	var unit: UnitState = world.get_unit("hellcat_1")
	var ship: UnitState = world.get_unit("essex")
	var ops: CarrierOperations = f.operations
	ops.strip_owner = unit.id; ops.roster[unit.id].gear_down = true; ops.roster[unit.id].hook_down = true
	unit.velocity_mps = Vector3(0,-2,-49)
	var local: Vector3 = Vector3(-3,18.15,108)
	check(f.ground.touchdown_check(unit,ship,local).accepted,"valid touch envelope admitted")
	for kind: String in ["speed","sink","heading","bank","zone","occupied","hook","elevator"]:
		unit.velocity_mps = Vector3(0,-2,-49); unit.rotation_rad = Vector3.ZERO; unit.module_data.aircraft_motion.bank_rad = 0.0
		ops.external_block = false; ops.roster[unit.id].hook_down = true; ops.deck.elevators.elevator_aft = 15.85
		var point: Vector3 = local
		match kind:
			"speed": unit.velocity_mps.z = -75
			"sink": unit.velocity_mps.y = -7
			"heading": unit.rotation_rad.y = deg_to_rad(12)
			"bank": unit.module_data.aircraft_motion.bank_rad = deg_to_rad(12)
			"zone": point.x = 9
			"occupied": ops.external_block = true
			"hook": ops.roster[unit.id].hook_down = false
			"elevator": point = Vector3(-3,18.15,45); ops.deck.elevators.elevator_aft = 7.926
		check(not f.ground.touchdown_check(unit,ship,point).accepted,"reject invalid contact "+kind)
	check(not ops.deck.footprint_reason(Vector3(0,15.85,45),0.0).is_empty(),"lowered elevator is unsupported flight deck")

func _supply_limits() -> void:
	var f: Dictionary = FIX.build()
	var world: SimulationWorld = f.world
	var ops: CarrierOperations = f.operations
	ops.fuel_stock_kg = 5.0; ops.ammo_stock_rounds = 7
	for weapon: WeaponState in world.get_unit("hellcat_1").weapons.values(): weapon.remaining_rounds[0] -= 10
	FIX.sortie(world,["hellcat_1"])
	check(until_phase(f,"hellcat_1","servicing",800),"limited supply case physically recovers")
	var before: float = world.get_unit("hellcat_1").module_data.aircraft_motion.fuel_kg
	step(f,31)
	check(is_equal_approx(float(world.get_unit("hellcat_1").module_data.aircraft_motion.fuel_kg)-before,5.0),"service cannot create more fuel than base stock")
	check(ops.fuel_stock_kg == 0.0 and ops.ammo_stock_rounds == 0 and ops.ammo_delivered == 7,"finite fuel and ammunition exhaust without negative inventory")

func _pause_rate_reset() -> void:
	var f: Dictionary = FIX.build()
	var world: SimulationWorld = f.world
	FIX.sortie(world,["hellcat_1"]); step(f,16)
	var before: Dictionary = world.snapshot()
	world.set_paused(true); world.advance(2.0)
	check(world.snapshot() == before,"paused world freezes queues and aircraft")
	world.set_paused(false); world.set_time_scale(4); var tick: int = world.tick
	world.advance(0.5)
	check(world.tick-tick == 120,"4x uses fixed ticks without skipping operations")
	world.reset()
	check(world.tick == 0 and f.operations.strip_owner.is_empty() and f.operations.history.is_empty(),"restart clears occupancy timeline and inventory generation")
	check(f.operations.roster.hellcat_1.phase == "standby" and world.get_unit("hellcat_1").position_m == Vector3(-3,18.15,75),"restart restores original parked aircraft once")
	check(f.operations.fuel_stock_kg == f.operations.parameters.fuel_stock_kg,"restart restores new-session supply stock")
	var a: Dictionary = FIX.build()
	var b: Dictionary = FIX.build()
	FIX.sortie(a.world,["hellcat_1"]); FIX.sortie(b.world,["hellcat_1"])
	(b.world as SimulationWorld).set_time_scale(4.0)
	for i: int in 1800:
		(a.world as SimulationWorld).advance(1.0/60.0); (a.world as SimulationWorld).drain_events()
		(b.world as SimulationWorld).advance(1.0/240.0); (b.world as SimulationWorld).drain_events()
	check((a.world as SimulationWorld).snapshot() == (b.world as SimulationWorld).snapshot(),"1x and 4x match complete fixed-tick world and OPS state")

func _hard_deck_contact() -> void:
	var f: Dictionary = FIX.build()
	var world: SimulationWorld = f.world
	var ops: CarrierOperations = f.operations
	FIX.sortie(world,["hellcat_1"])
	var reached: bool = false
	for i: int in 800*60:
		world.step_ticks(1); world.drain_events()
		if ops.roster.hellcat_1.phase == "approach" and (ops.roster.hellcat_1.local_m as Vector3).z < 128.0:
			reached = true; break
	check(reached,"hard contact case reaches near deck by original continuous flight")
	var unit: UnitState = world.get_unit("hellcat_1")
	# One controlled downward impulse too late for a safe wave-off. No pose,
	# contact plane, OPS state or damage outcome is set by the test.
	unit.velocity_mps.y = -10.0
	var minimum_y: float = INF
	var minimum_feature_y: float = INF
	var previous_position: Vector3 = unit.position_m
	var maximum_tick_step: float = 0.0
	var impact_seen: bool = false
	var saved_local: Vector3 = Vector3.ZERO
	var trace: Array[Dictionary] = []
	var events: Array[Dictionary] = []
	for i: int in 180:
		world.step_ticks(1)
		for event: BattleEvent in world.drain_events():
			events.append(event.snapshot())
			if event.kind == "unit_impact" and str(event.data.reason).begins_with("carrier_deck_collision:"): impact_seen = true
		var local: Vector3 = world.get_unit("essex").world_transform().affine_inverse()*unit.position_m
		maximum_tick_step = maxf(maximum_tick_step,unit.position_m.distance_to(previous_position))
		previous_position = unit.position_m
		minimum_y = minf(minimum_y,local.y)
		var relative_pose: Transform3D = world.get_unit("essex").world_transform().affine_inverse()*unit.world_transform()
		for point: Vector3 in CarrierDeckGeometry.contact_points(true): minimum_feature_y = minf(minimum_feature_y,(relative_pose*point).y)
		trace.append({"tick":world.tick,"time_s":world.time_s(),"position_m":unit.position_m,"velocity_mps":unit.velocity_mps,"rotation_rad":unit.rotation_rad,"local_m":local,"ops_phase":ops.roster.hellcat_1.phase,"damage_phase":unit.module_data.damage.phase})
		if unit.module_data.has("carrier_deck_contact"): saved_local = unit.module_data.carrier_deck_contact.local_m
	check(impact_seen and unit.module_data.damage.phase == "wreck" and not unit.active,"late physical contact reaches real CombatDamage terminal outcome")
	check(maximum_tick_step < 1.1,"hard contact has no position jump at impact and support handoff",maximum_tick_step)
	check(minimum_feature_y >= 15.85-0.01,"actual tilted wheel features never penetrate moving deck",minimum_feature_y)
	check(unit.position_m.distance_to(world.get_unit("essex").world_transform()*saved_local) < 0.01,"disabled wreck physically rides moving deck without restoring flight")
	check(ops.roster.hellcat_1.phase == "lost" and not ops.roster.hellcat_1.on_deck and ops.strip_owner.is_empty(),"impact releases OPS ownership, no aircraft resurrection")
	check(ops._base_reason(world) == "wreck_on_flight_deck","physical wreck blocks deck after scheduling slot release")
	check(ops.fuel_delivered_kg == 0.0,"hard-contact loss never receives service")
	var file: FileAccess = FileAccess.open("res://docs/showcase/evidence/OPS01/hard-contact.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(FIX.json_data({"fault":"controlled downward velocity impulse -10m/s near stern, no position/phase/damage set","trace":trace,"events":events,"minimum_origin_local_y":minimum_y,"minimum_wheel_feature_local_y":minimum_feature_y}),"\t")); file.close()

func _respot_cancellation() -> void:
	var f: Dictionary = FIX.build()
	var world: SimulationWorld = f.world
	var ops: CarrierOperations = f.operations
	FIX.sortie(world,["hellcat_1"])
	check(until_phase(f,"hellcat_1","servicing",800),"respot cancellation case completes first physical recovery")
	step(f,31)
	FIX.sortie(world,["hellcat_1"],"respot_cancel")
	check(until_phase(f,"hellcat_1","respotting",30),"repeat sortie begins actual aft deck handling")
	step(f,5)
	check(FIX.cancel(world,"respot_cancel").accepted,"deck handling cancellation follows BattleCommand")
	step(f,5)
	check(ops.strip_owner.is_empty() and (ops.roster.hellcat_1.relative_velocity_mps as Vector3).length() < 0.05,"cancelled crew handling brakes continuously and releases strip")
	FIX.sortie(world,["hellcat_1"],"repeat_after_cancel")
	check(until_phase(f,"hellcat_1","servicing",1100),"single aircraft respots again and completes second recovery")
	step(f,31)
	check(ops.roster.hellcat_1.recoveries == 2 and ops.roster.hellcat_1.sorties == 2,"single-aircraft cycle is repeatable after cancellation")

func _rigid_pose() -> void:
	var f: Dictionary = FIX.build()
	var world: SimulationWorld = f.world
	var ship: UnitState = world.get_unit("essex")
	var unit: UnitState = world.get_unit("hellcat_1")
	ship.position_m = Vector3(1000,3,-2000)
	ship.rotation_rad = Vector3(deg_to_rad(1.5),deg_to_rad(45),deg_to_rad(-1.0))
	var pose: Transform3D = ship.world_transform()
	ship.velocity_mps = Vector3(-sin(ship.rotation_rad.y),0,-cos(ship.rotation_rad.y))*15.0
	ship.module_data.ship_control.goal_m = ship.position_m+pose.basis*Vector3(0,0,-100000)
	unit.position_m = pose*(f.operations.roster.hellcat_1.local_m as Vector3)
	unit.rotation_rad = ship.rotation_rad; unit.velocity_mps = ship.velocity_mps
	f.operations.last_ship_basis = pose.basis
	step(f,10)
	var expected: Transform3D = ship.world_transform()*Transform3D(Basis.IDENTITY,f.operations.roster.hellcat_1.local_m)
	check(unit.position_m.distance_to(expected.origin) < 0.001 and unit.world_transform().basis.is_equal_approx(expected.basis),"parked support consumes full mother translation and attitude")
	check(unit.velocity_mps.distance_to(CarrierDeckGeometry.velocity_at(ship,f.operations.roster.hellcat_1.local_m,f.operations.angular_velocity)) < 0.001,"deck velocity includes actual rigid-body angular contribution")

func _base_loss_on_deck() -> void:
	var f: Dictionary = FIX.build()
	var world: SimulationWorld = f.world
	FIX.sortie(world,["hellcat_1"]); step(f,1)
	(f.damage as CombatDamage)._disable(world,world.get_unit("essex"),"structure")
	var before: Vector3 = world.get_unit("hellcat_1").position_m
	step(f,4)
	var unit: UnitState = world.get_unit("hellcat_1")
	check(not f.operations.roster.hellcat_1.on_deck and f.operations.strip_owner.is_empty(),"lost carrier releases parked aircraft support and scheduling")
	check(unit.position_m.distance_to(before) > 1.0 and unit.position_m.y < before.y,"unsupported aircraft follows actual fall, never stays attached to sinking deck")
	check(f.operations.fuel_delivered_kg == 0.0,"carrier loss does not refill or regenerate parked aircraft")
