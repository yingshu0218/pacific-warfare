extends "res://tests/fixtures/combat_test.gd"

const OPS_FIX: Script = preload("res://tests/air_operations/fixture.gd")
var summary: Dictionary = {}

class DelegateProbe extends CarrierMissionDelegate:
	var steps: int = 0
	var releases: int = 0
	func supports(kind: String) -> bool: return kind == "patrol"
	func accept(_world: SimulationWorld, _order: BattleOrder, _ids: Array[String]) -> Dictionary: return {"accepted":true,"reason":"probe_capable"}
	func step(world: SimulationWorld, unit: UnitState, order: Dictionary, _owned: Array[String], _formation: Dictionary) -> void:
		steps += 1
		unit.module_data["aircraft_control"] = {"flight_direction":Vector3.FORWARD,"speed_mps":80.0}
		unit.module_data.carrier_delegated_mission.return_requested = steps >= 600
		unit.module_data.carrier_delegated_mission.return_reason = "probe_actual_task_complete"
		world.report_order_unit_progress(str(order.order_id),unit.id,"delegated_task %d"%steps,"probe_running")
	func released(_world: SimulationWorld, _order: BattleOrder, _ids: Array[String], _reason: String) -> void: releases += 1

func run_test() -> void:
	_geometry()
	_full_body_fault()
	_delegate()
	_clean_flight_unchanged()
	_clean_roster_flight()
	var file: FileAccess = FileAccess.open("res://docs/showcase/evidence/OPS01/model-resume-checks.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(OPS_FIX.json_data({"checks":checks,"failures":failures,"summary":summary}),"\t")); file.close()
	finish("OPS01 accepted-model support and mission composition")

func _geometry() -> void:
	var deck: CarrierDeckGeometry = CarrierDeckGeometry.new()
	expect(deck.surface(Vector2(-3,-47.0342864990234)).supported,"Actual internal tail-wheel point remains supported without pose dithering")
	expect(not deck.surface(Vector2(30,-47.0342864990234)).supported,"Stable containment does not enlarge the actual deck boundary")
	var geometry: CarrierAirframeGeometry = CarrierAirframeGeometry.new()
	var parked: Transform3D = geometry.parked_pose()
	var state: Dictionary = {"gear_down":true,"hook_down":true,"flaps_down":true}
	var min_wheel: float = INF; var max_wheel: float = -INF
	for row: Dictionary in geometry.wheel_features(parked.basis,state):
		var y: float = (parked*(row.point_m as Vector3)).y
		min_wheel = minf(min_wheel,y); max_wheel = maxf(max_wheel,y)
	expect(absf(min_wheel) < 0.00001 and absf(max_wheel) < 0.00001,"Three circular tyres solve one physical parked support plane")
	var clearances: Dictionary = {}
	for row: Dictionary in geometry.body_features(parked.basis,state):
		clearances[row.id] = (parked*(row.point_m as Vector3)).y
		expect(float(clearances[row.id]) > 0.0,"Actual mesh/disc clears deck in parked configuration: "+str(row.id))
	var lowered: Dictionary = geometry.hook_at(parked.origin,parked.basis,state,{},0.0)
	expect(lowered.free_tip_m.y < -0.2 and lowered.tip_m.y >= 0.019,"Free hook and deck-constrained tip are distinct without moving aircraft")
	var damage: Dictionary = {"aircraft":{"detached_parts":["wing_left","tail"]}}
	expect(geometry.wheel_features(parked.basis,state,damage).size() == 1,"CPU contacts exclude actual detached wheel hosts")
	expect(not geometry.hook_at(parked.origin,parked.basis,state,damage,0.0).available,"Detached tail cannot supply an arresting hook")
	var level: Basis = Basis.IDENTITY
	var origin: Vector3 = Vector3(0,geometry.support_height(level,state),0)
	var disc_y: float = INF
	for row: Dictionary in geometry.body_features(level,state):
		if row.id == "propeller_disc": disc_y = (origin+row.point_m).y
	expect(disc_y < -0.3,"Level short-gear pose is correctly unsafe for the full rotating propeller disc")
	summary.geometry = {"park_pitch_rad":parked.basis.get_euler().x,"park_height_m":parked.origin.y,"clearances_m":clearances,"constrained_hook":lowered}

func _full_body_fault() -> void:
	var f: Dictionary = OPS_FIX.build()
	var world: SimulationWorld = f.world
	OPS_FIX.sortie(world,["hellcat_1"])
	var triggered: bool = false
	var impact: Dictionary = {}
	var records: Array[Dictionary] = []
	for i: int in 60*800:
		world.step_ticks(1)
		var s: Dictionary = f.operations.roster.hellcat_1
		if not triggered and s.phase == "approach" and (s.local_m as Vector3).z < 450.0:
			# A bounded erroneous pilot body-pitch command, no position set.
			s["configuration_pitch_command_deg"] = -2.0; triggered = true
		for event: BattleEvent in world.drain_events():
			if event.kind == "unit_surface_contact": impact = event.snapshot()
		if triggered:
			var unit: UnitState = world.get_unit("hellcat_1")
			records.append({"tick":world.tick,"position_m":unit.position_m,"rotation_rad":unit.rotation_rad,"phase":s.phase,"damage_phase":unit.module_data.damage.phase})
		if not impact.is_empty(): break
	expect(triggered and not impact.is_empty(),"Wrong nose attitude reaches a real physical contact from continuous approach")
	expect(str(impact.get("data",{}).get("reason","")).begins_with("carrier_deck_collision:airframe_first_contact:"),"Body/propeller contact wins before imaginary wheel touchdown")
	expect(f.operations.roster.hellcat_1.touchdown_count == 0,"Airframe strike does not increment a successful wheel recovery")
	expect(not world.get_unit("hellcat_1").active,"Original DM consumes the actual airframe strike")
	var wreck: UnitState = world.get_unit("hellcat_1")
	var previous_y: float = (world.get_unit("essex").world_transform().affine_inverse()*wreck.position_m).y
	var initial_basis: Basis = wreck.world_transform().basis
	var previous_basis: Basis = initial_basis
	var maximum_settle_step: float = 0.0
	var maximum_rate: float = 0.0
	var minimum_clearance: float = INF
	var settle_records: Array[Dictionary] = []
	for i: int in 360:
		world.step_ticks(1); world.drain_events()
		var y: float = (world.get_unit("essex").world_transform().affine_inverse()*wreck.position_m).y
		maximum_settle_step = maxf(maximum_settle_step,absf(y-previous_y)); previous_y = y
		var basis: Basis = wreck.world_transform().basis
		maximum_rate = maxf(maximum_rate,CarrierConfigurationAttitude.angular_velocity(previous_basis,basis,1.0/60.0).length()); previous_basis = basis
		var relative: Transform3D = world.get_unit("essex").world_transform().affine_inverse()*wreck.world_transform()
		for row: Dictionary in f.operations.airframe.resting_features(relative.basis,f.operations.roster.hellcat_1,wreck.module_data.damage,float(wreck.module_data.aircraft_motion.propeller_phase_rad)):
			minimum_clearance = minf(minimum_clearance,(relative*(row.point_m as Vector3)).y-15.85)
		settle_records.append({"tick":world.tick,"time_s":world.time_s(),"local_m":relative.origin,"rotation_rad":relative.basis.get_euler(),"support":wreck.module_data.get("carrier_deck_contact",{}).duplicate(true)})
	var pose: Transform3D = world.get_unit("essex").world_transform().affine_inverse()*wreck.world_transform()
	var clearance: float = INF
	for row: Dictionary in f.operations.airframe.resting_features(pose.basis,f.operations.roster.hellcat_1,wreck.module_data.damage,float(wreck.module_data.aircraft_motion.propeller_phase_rad)):
		clearance = minf(clearance,(pose*(row.point_m as Vector3)).y-15.85)
	expect(absf(clearance) < 0.002,"Stopped wreck rests on its surviving actual mesh instead of the empty rotating-disc envelope")
	expect(maximum_settle_step < 0.08 and not wreck.active,"Wreck settles continuously without restoring flight or changing the damage outcome")
	var diagnostics: Dictionary = wreck.module_data.carrier_deck_contact.get("settling_diagnostics",{})
	expect(bool(diagnostics.get("stable",false)) and float(diagnostics.get("projection_error_m",INF)) <= CarrierWreckSettling.STABILITY_TOLERANCE_M and float(diagnostics.get("support_span_m",0)) > 1.0,"Final actual multi-point support contains the remaining mass-center gravity projection")
	expect(maximum_rate <= CarrierWreckSettling.MAX_RATE_RADPS+0.005 and initial_basis.y.distance_to(pose.basis.y) > 0.05,"Gravity tips the unbalanced wreck with a bounded continuous angular rate")
	expect(minimum_clearance >= -0.002,"Surviving body and actual propeller mesh never penetrate the deck during tipping")
	expect(wreck.module_data.damage.aircraft.detached_parts.size() == 3 and f.operations._base_reason(world) == "wreck_on_flight_deck" and f.operations.fuel_delivered_kg == 0.0,"Settling preserves DM breakage, deck blockage and no-service outcome")
	var final_settle: Dictionary = {"remaining_mesh_clearance_m":clearance,"minimum_clearance_during_settle_m":minimum_clearance,"maximum_tick_step_m":maximum_settle_step,"maximum_angular_rate_radps":maximum_rate,"final_local_m":pose.origin,"rotation_rad":pose.basis.get_euler(),"diagnostics":diagnostics}
	world.get_unit("essex").active = false
	for i: int in 90: world.step_ticks(1); world.drain_events()
	expect(not wreck.module_data.has("carrier_deck_contact") and wreck.position_m.y < pose.origin.y-2.0,"Loss of the mother ship removes stable support and resumes original terminal falling")
	summary.wreck_settle = final_settle
	var file: FileAccess = FileAccess.open("res://docs/showcase/evidence/OPS01/airframe-first-contact.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(OPS_FIX.json_data({"impact":impact,"samples":records,"settle_samples":settle_records,"settle_final":final_settle,"after_carrier_loss":wreck.snapshot()}),"\t")); file.close()

func _delegate() -> void:
	var f: Dictionary = OPS_FIX.build()
	var world: SimulationWorld = f.world
	var delegate: DelegateProbe = DelegateProbe.new()
	f.tasks.set("mission_delegate",delegate)
	OPS_FIX.sortie(world,["hellcat_1"],"delegate_order")
	for i: int in 60*100:
		world.step_ticks(1); world.drain_events()
		if f.operations.roster.hellcat_1.phase == "return": break
	expect(delegate.steps == 600,"One task executor delegates the airborne mission and observes its real completion")
	expect(f.operations.roster.hellcat_1.reason == "probe_actual_task_complete","OPS receives explicit task completion instead of imposing the patrol timer")
	OPS_FIX.cancel(world,"delegate_order"); world.step_ticks(1); world.drain_events()
	expect(delegate.releases == 1,"Cancellation reaches the same delegated task exactly once")
	var count: int = 0
	for id: String in world.snapshot().modules:
		if id == "aircraft_tasks": count += 1
	expect(count == 1,"Mission composition keeps exactly one aircraft-domain executor")

func _clean_flight_unchanged() -> void:
	var worlds: Array[SimulationWorld] = []
	for bridge_enabled: bool in [false,true]:
		var world: SimulationWorld = SimulationWorld.new()
		var spawn: Dictionary = AircraftFixture.spawn("pilot","us",Vector3(0,1200,0),"us_f6f5_1944",0,89.4)
		expect(world.configure(AircraftFixture.catalog(),{"id":"OPS_clean_comparison","seed":52,"tick_hz":60,"factions":["us","jp"],"spawns":[spawn]}).is_empty(),"Configure clean force comparison")
		world.register_module(AircraftTasks.new())
		if bridge_enabled:
			var bridge: AircraftMotion = load("res://scripts/air_operations/flight_bridge.gd").new()
			bridge.set("operations",CarrierOperations.new())
			world.register_module(bridge)
		else: world.register_module(AircraftMotion.new())
		var ids: Array[String] = ["pilot"]
		AircraftFixture.order(world,"clean_patrol",ids,"patrol")
		worlds.append(world)
	for i: int in 1200:
		for world: SimulationWorld in worlds: world.step_ticks(1); world.drain_events()
	expect(worlds[0].snapshot() == worlds[1].snapshot(),"No carrier configuration preserves the original healthy aircraft state exactly")

func _clean_roster_flight() -> void:
	var worlds: Array[SimulationWorld] = []
	for native: bool in [true,false]:
		var f: Dictionary = OPS_FIX.build()
		var world: SimulationWorld = f.world
		var unit: UnitState = world.get_unit("hellcat_1")
		unit.position_m = Vector3(0,1200,0); unit.velocity_mps = Vector3(0,0,-89.4); unit.rotation_rad = Vector3.ZERO
		var s: Dictionary = f.operations.roster.hellcat_1
		s.on_deck = false; s.phase = "mission"; s.gear_down = false; s.flaps_down = false; s.hook_down = false; s.angle_of_attack_rad = 0.0
		if native:
			world._modules.erase(f.flight)
			world.register_module(AircraftMotion.new())
		else: (f.flight as AircraftMotion).reset(world)
		OPS_FIX.sortie(world,["hellcat_1"],"clean_roster")
		worlds.append(world)
	var maximum: float = 0.0
	for i: int in 1200:
		for world: SimulationWorld in worlds: world.step_ticks(1); world.drain_events()
		var a: UnitState = worlds[0].get_unit("hellcat_1"); var b: UnitState = worlds[1].get_unit("hellcat_1")
		maximum = maxf(maximum,a.position_m.distance_to(b.position_m)+a.velocity_mps.distance_to(b.velocity_mps)+a.rotation_rad.distance_to(b.rotation_rad))
	expect(maximum == 0.0,"Clean mission in the OPS roster exactly retains original physical motion and attitude")
	summary.clean_roster_maximum_error = maximum
