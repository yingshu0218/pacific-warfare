extends "res://tests/fixtures/combat_test.gd"

const OUTPUT: String = "res://docs/showcase/evidence/DM01/mechanisms.json"
var evidence: Array[Dictionary] = []

func arena(definition_id: String, altitude: float = 600.0) -> Dictionary:
	return AircraftDamageFixture.arena(definition_id,altitude)

func shoot(a: Dictionary, part: String, count: int, ammo_id: String = "jp_20mm_type99_2_shell") -> void:
	AircraftDamageFixture.shoot(a,part,count,ammo_id)

func collect(world: SimulationWorld, events: Array[BattleEvent], ticks: int) -> void:
	for i: int in ticks:
		world.step_ticks(1)
		events.append_array(world.drain_events())

func of_kind(events: Array[BattleEvent], kind: String, target: String = "") -> Array[BattleEvent]:
	var result: Array[BattleEvent] = []
	for event: BattleEvent in events:
		if event.kind == kind and (target.is_empty() or event.entity_id == target or event.target_id == target): result.append(event)
	return result

func part_case(definition_id: String, part: String) -> void:
	var a: Dictionary = arena(definition_id)
	var world: SimulationWorld = a.world
	var target: UnitState = world.get_unit("target")
	var events: Array[BattleEvent] = []
	world.step_ticks(30)
	world.drain_events()
	var prop_before: float = target.module_data.aircraft_motion.get("propeller_speed_radps",0)
	shoot(a,part,14 if part == "engine" else 6)
	var last_pose: Transform3D = target.world_transform()
	var worst_step: float = 0.0
	var worst_acceleration: float = 0.0
	var previous_velocity: Vector3 = target.velocity_mps
	var continuity: bool = true
	var maximum_pieces: int = 0
	var sampled: Array[Dictionary] = []
	for i: int in 240:
		world.step_ticks(1)
		var step_events: Array[BattleEvent] = world.drain_events()
		events.append_array(step_events)
		for event: BattleEvent in step_events:
			if event.kind == "aircraft_part_detached":
				var expected: Vector3 = target.world_transform() * (event.data.local_anchor_m as Vector3)
				continuity = continuity and expected.distance_to(event.position_m) < .001
				var omega: Vector3 = event.data.angular_velocity_body_radps
				var inherited: Vector3 = target.velocity_mps + (target.world_transform().basis*omega).cross(target.world_transform().basis*(event.data.local_anchor_m as Vector3))
				continuity = continuity and inherited.distance_to(event.data.velocity_mps) < .001
		var angle: float = last_pose.basis.get_rotation_quaternion().angle_to(target.world_transform().basis.get_rotation_quaternion())
		worst_step = maxf(worst_step,angle)
		worst_acceleration = maxf(worst_acceleration,(target.velocity_mps-previous_velocity).length()*60)
		last_pose = target.world_transform()
		previous_velocity = target.velocity_mps
		maximum_pieces = maxi(maximum_pieces,target.module_data.damage.aircraft.fragments.size())
		if i%15 == 0: sampled.append({"time_s":world.time_s(),"position_m":SimData.array3(target.position_m),"rotation_rad":SimData.array3(target.rotation_rad),"velocity_mps":SimData.array3(target.velocity_mps),"phase":target.module_data.damage.phase,"propeller_speed_radps":target.module_data.aircraft_motion.get("propeller_speed_radps",0)})
	var damage: Dictionary = target.module_data.damage
	var hits: Array[BattleEvent] = of_kind(events,"hit","target")
	expect(not hits.is_empty() and hits.all(func(e: BattleEvent) -> bool:return e.data.part_id == part), definition_id+" real swept projectiles hit only "+part)
	expect(of_kind(events,"fired").size() == (14 if part == "engine" else 6) and of_kind(events,"damaged","target").size() == hits.size(), "Fired -> hit -> damaged chain is real and one-time")
	if part == "engine":
		expect(damage.parts.engine == 0 and damage.propulsion_factor == 0 and target.active, definition_id+" engine failure retains control/active glide")
		expect(damage.aircraft.detached_parts.is_empty() and not damage.aircraft.breakup and of_kind(events,"aircraft_breakup").is_empty(), "Engine damage alone never detaches wings")
		expect(target.module_data.aircraft_motion.safety_state == "glide" and target.velocity_mps.length() > 30, "Engine-out keeps forward flight under lift/gravity")
		expect(float(target.module_data.aircraft_motion.propeller_speed_radps) < prop_before and float(target.module_data.aircraft_motion.propeller_speed_radps) > 0, "Propeller coasts continuously to bounded windmilling rate")
		expect(damage.effect_emitters.any(func(e: Dictionary) -> bool:return e.id == "engine_smoke" and (e.anchor_m as Vector3).z < -2), "Genuine engine loss supplies nose smoke emitter")
	else:
		expect(not target.active and damage.phase == "crashing" and damage.aircraft.detached_parts == [part], definition_id+" exact single wing detaches into terminal flight")
		expect(target.weapons.values().all(func(w: WeaponState) -> bool:return not w.enabled), "Terminal aircraft stops all guns")
		var side_prefix: String = "wing_port_" if part == "wing_left" else "wing_starboard_"
		expect(damage.disabled_mounts.any(func(id: String) -> bool:return id.begins_with(side_prefix)), "Detached wing mount is explicitly disabled")
		expect((a.frame as CombatFrame).proxies.target.all(func(box: Dictionary) -> bool:return box.part != part), "Missing wing collision region removed")
		var x: float = -3.8 if part == "wing_left" else 3.8
		var missing: Dictionary = CombatGeometry.moving_boxes(Vector3(x,5,-.3),Vector3(x,-5,-.3),Transform3D.IDENTITY,Transform3D.IDENTITY,a.frame.proxies.target)
		expect(float(missing.fraction) == INF, "A later bullet passes through the actual missing wing region")
		expect(continuity and maximum_pieces == 1 and of_kind(events,"aircraft_part_detached").size() == 1, "Detached mesh begins at exact installed pose and inherited velocity once")
		expect(worst_step < .032 and worst_step > .01 and worst_acceleration < 35, "Bounded continuous angular dynamics and translational acceleration")
		expect(absf((damage.aircraft.angular_velocity_body_radps as Vector3).z) > .2 and target.velocity_mps.y < -10, "Asymmetric wing loss produces rolling descent instead of frozen fall")
		shoot(a,part,1)
		var later_events: Array[BattleEvent] = []
		collect(world,later_events,8)
		expect(of_kind(later_events,"fired").size() == 1 and of_kind(later_events,"hit","target").is_empty(),"Production projectile really traverses the missing wing without interception")
		events.append_array(later_events)
	var event_records: Array[Dictionary] = []
	for event: BattleEvent in events:
		if event.kind in ["fired","hit","damaged","aircraft_part_detached","disabled"]: event_records.append(event.snapshot())
	evidence.append({"definition_id":definition_id,"case":part,"controlled":true,"launch_note":"Existing ammo, production CombatProjectiles.launch; precise test launch is not commander AI or natural combat.","maximum_pieces":maximum_pieces,"maximum_attitude_step_rad":worst_step,"maximum_acceleration_mps2":worst_acceleration,"continuity":continuity,"samples":sampled,"events":event_records})

func breakup_case(definition_id: String) -> void:
	var a: Dictionary = arena(definition_id,130)
	var world: SimulationWorld = a.world
	var target: UnitState = world.get_unit("target")
	var events: Array[BattleEvent] = []
	shoot(a,"structure",1,"us_406mm_mk8_ap")
	collect(world,events,6)
	expect(target.module_data.damage.structure == 0 and target.module_data.damage.aircraft.breakup and target.module_data.damage.aircraft.fragments.size() == 3, definition_id+" lethal real structure hit splits only three modules")
	var impact: BattleEvent
	var maximum: int = 0
	for i: int in 1800:
		world.step_ticks(1)
		var step_events: Array[BattleEvent] = world.drain_events()
		events.append_array(step_events)
		maximum = maxi(maximum,target.module_data.damage.aircraft.fragments.size())
		for event: BattleEvent in step_events:
			if event.kind == "unit_impact": impact = event
		if target.module_data.damage.phase == "wreck":
			expect(target.module_data.damage.effect_emitters.is_empty(),"Surface contact immediately stops all aircraft smoke sources")
			break
	expect(impact != null and impact.data.surface == "sea" and absf(impact.position_m.y) < .001, "Falling aircraft reaches real sea plane before exactly one impact")
	var contact_count: int = of_kind(events,"unit_surface_contact").size()
	var impact_count: int = of_kind(events,"unit_impact").size()
	expect(contact_count == 1 and impact_count == 1 and of_kind(events,"aircraft_breakup").size() == 1 and of_kind(events,"aircraft_part_detached").size() == 3, "Breakup/contact/impact are deduplicated and bounded")
	world.step_ticks(180)
	expect(target.position_m.y < -2.5,"Sea wreck sinks, never stays as a complete floating aircraft")
	world.step_ticks(600)
	expect(target.module_data.damage.phase == "removed" and target.module_data.damage.aircraft.fragments.is_empty(),"Aircraft and fragments reclaimed within bounded lifetime")
	expect(of_kind(world.drain_events(),"unit_impact").is_empty(),"No repeated impact during sinking/removal")
	evidence.append({"definition_id":definition_id,"case":"breakup_and_water","controlled":true,"maximum_pieces":maximum,"surface_contacts":contact_count,"impacts":impact_count,"impact":{} if impact == null else impact.snapshot()})
	world.reset()
	expect(target != world.get_unit("target") and world.get_unit("target").active and world.get_unit("target").module_data.damage.aircraft.detached_parts.is_empty() and a.frame.proxies.target.size() == 5, "Reset rebuilds health, guns, parts and collision proxies")

func tail_and_control_case(definition_id: String) -> void:
	var a: Dictionary = arena(definition_id)
	var events: Array[BattleEvent] = []
	shoot(a,"tail",6)
	collect(a.world,events,8)
	var target: UnitState = a.world.get_unit("target")
	expect(of_kind(events,"hit","target").any(func(e: BattleEvent) -> bool:return e.data.part_id == "tail") and target.module_data.damage.parts.tail == 0 and target.module_data.damage.aircraft.detached_parts == ["tail"], "Real tail-region projectiles alone can detach the tail structure")
	a = arena(definition_id)
	target = a.world.get_unit("target")
	var shots: Array[Dictionary] = []
	for i: int in 200:
		shots.append({"ammo":"us_127mm_5in38_shell","position":target.position_m+Vector3(8,-7.92,-1.67),"direction":Vector3.UP,"fuze":.01})
	(a.launcher as FIX.Launcher).pending = shots
	events.clear()
	collect(a.world,events,5)
	expect(not of_kind(events,"airburst").is_empty() and target.module_data.damage.parts.control == 0 and not target.active, "Genuine close timed flak bursts can destroy functional control")
	expect(target.module_data.damage.structure > 0 and target.module_data.damage.parts.tail == 1 and target.module_data.damage.aircraft.detached_parts.is_empty(), "Blast control loss never invents tail fracture or other detached modules")
	evidence.append({"definition_id":definition_id,"case":"control_distinct_from_tail","controlled":true,"airbursts":of_kind(events,"airburst").size(),"tail_health_after_blast":target.module_data.damage.parts.tail,"control_health_after_blast":target.module_data.damage.parts.control,"structure_after_blast":target.module_data.damage.structure})

func rotating_inheritance_case(definition_id: String) -> void:
	var a: Dictionary = arena(definition_id,2500)
	var world: SimulationWorld = a.world
	var target: UnitState = world.get_unit("target")
	var forward: Vector3 = Vector3(0,sin(deg_to_rad(28)),-cos(deg_to_rad(28)))
	var basis: Basis = AircraftFlightMath.frame(forward,AircraftFlightMath.level_up(forward,Vector3.UP).rotated(forward,deg_to_rad(63)))
	target.rotation_rad = basis.get_euler()
	target.velocity_mps = forward*115
	target.module_data["aircraft_control"] = {"flight_direction":Vector3(0.6,0.5,-0.62).normalized(),"speed_mps":125.0}
	world.step_ticks(20)
	world.drain_events()
	shoot(a,"wing_left",6)
	var found: bool = false
	var measured: Vector3 = Vector3.ZERO
	var omega_error: float = INF
	var velocity_error: float = INF
	for i: int in 12:
		var before: Basis = target.world_transform().basis
		world.step_ticks(1)
		var after: Basis = target.world_transform().basis
		var relative: Quaternion = (before.inverse()*after).get_rotation_quaternion().normalized()
		if relative.w < 0: relative = -relative
		var axis: Vector3 = Vector3(relative.x,relative.y,relative.z)
		var sine: float = axis.length()
		measured = axis*(2*atan2(sine,relative.w)*60/sine) if sine > .00000001 else Vector3.ZERO
		for event: BattleEvent in world.drain_events():
			if event.kind == "aircraft_part_detached":
				found = true
				omega_error = (event.data.angular_velocity_body_radps as Vector3).distance_to(measured)
				var offset: Vector3 = after*(event.data.local_anchor_m as Vector3)
				velocity_error = (event.data.velocity_mps as Vector3).distance_to(target.velocity_mps+(after*measured).cross(offset))
		if found: break
	expect(found and absf(measured.x) > .01 and absf(measured.y) > .01 and absf(measured.z) > .01,"Damage occurs during real combined pitch, bank and heading change")
	expect(omega_error < .0002 and velocity_error < .002,"Detached angular and tangential velocity match measured pre/post body bases, not event self-reconstruction")
	evidence.append({"definition_id":definition_id,"case":"rotating_inheritance","controlled":true,"measured_body_omega_radps":measured,"omega_error_radps":omega_error,"tangential_velocity_error_mps":velocity_error})

func ground_wreck_case() -> void:
	var c: CombatConfig = FIX.config()
	c.data.environment.solids = [{"id":"test_land","surface":"ground","center_m":[0,0,0],"half_extents_m":[2000,3,2000]}]
	var a: Dictionary = FIX.arena([FIX.spawn("shooter","us",Vector3(5000,100,0)),FIX.spawn("target","jp",Vector3(0,100,0))],c,false)
	shoot(a,"structure",1,"us_406mm_mk8_ap")
	var events: Array[BattleEvent] = []
	collect(a.world,events,700)
	var target: UnitState = a.world.get_unit("target")
	expect(target.module_data.damage.phase == "wreck" and absf(target.position_m.y-3) < .001,"Actual aircraft terrain contact remains a stationary land wreck, not sea sinking")
	expect(of_kind(events,"unit_impact").size() == 1 and of_kind(events,"unit_impact")[0].data.surface == "ground","Ground impact classification comes only from real surface sweep")
	expect(target.module_data.damage.aircraft.fragments.all(func(p: Dictionary)->bool:return p.surface == "ground" and absf((p.position_m as Vector3).y-3) < .001),"Detached pieces stop on actual ground before underlying sea")

func schedule_case() -> void:
	var a: Dictionary = arena("us_f6f5_1944")
	var b: Dictionary = arena("us_f6f5_1944")
	shoot(a,"wing_left",6)
	shoot(b,"wing_left",6)
	a.world.step_ticks(240)
	for i: int in 60: b.world.advance(1.0/15.0)
	expect(a.world.get_unit("target").snapshot() == b.world.get_unit("target").snapshot(), "Identical damage input stays identical at fixed-step and 15fps render schedule")
	var before: Dictionary = b.world.get_unit("target").snapshot()
	b.world.set_paused(true)
	for i: int in 90: b.world.advance(1.0/30.0)
	expect(before == b.world.get_unit("target").snapshot(),"Pause freezes angular motion, propeller and fragment lifetime")
	b.world.set_paused(false)
	b.world.set_time_scale(2.0)
	for i: int in 60: b.world.advance(1.0/30.0)
	a.world.step_ticks(240)
	expect(a.world.get_unit("target").snapshot() == b.world.get_unit("target").snapshot(), "2x time scale has identical state at the same simulation tick")

func run_test() -> void:
	for definition_id: String in ["us_f6f5_1944","jp_a6m5a_1944"]:
		for part: String in ["engine","wing_left","wing_right"]: part_case(definition_id,part)
		breakup_case(definition_id)
		tail_and_control_case(definition_id)
		rotating_inheritance_case(definition_id)
	ground_wreck_case()
	schedule_case()
	var file: FileAccess = FileAccess.open(OUTPUT,FileAccess.WRITE)
	file.store_string(JSON.stringify(AircraftDamageFixture.json_data({"checks":checks,"failures":failures,"cases":evidence}),"\t"))
	finish("DM01 aircraft damage")
