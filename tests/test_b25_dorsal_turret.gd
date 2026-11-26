extends "res://tests/fixtures/combat_test.gd"

const INTERCEPT: String = "res://data/scenarios/s14_intercept_b25.json"
const ATTACK: String = "res://data/scenarios/s14_attack_b25.json"
const HARBOR: String = "res://data/scenarios/s14_expansion_harbor.json"
const INSPECT: String = "res://data/scenarios/s14_expansion_inspect_b25j.json"
const DORSAL: String = "dorsal"

func run_test() -> void:
	_check_live_intercept()
	_check_station_gates()
	_check_other_entries()
	finish("B25G01 dorsal turret")

func _check_live_intercept() -> void:
	var session: FirstPlayableSession = FirstPlayableSession.new()
	if not _load(session, INTERCEPT): return
	var models: Dictionary = {}
	for id: String in ["bomber", "wing"]:
		var path: String = session.catalog.unit(session.units[id].definition_id).model_scene
		var model: Node3D = (load(path) as PackedScene).instantiate()
		root.add_child(model)
		models[id] = model
	var effects: CombatEffects = CombatEffects.new()
	root.add_child(effects)
	var initial: Array = session.units.bomber.weapons.dorsal.remaining_rounds
	var shot_counts: Dictionary = {"bomber": [0, 0], "wing": [0, 0]}
	var barrels_seen: Dictionary = {}
	var first_shot: Dictionary = {}
	var distinct: bool = false
	var tracer_seen: bool = false
	var tracer_verified: bool = false
	var first_interceptor_shot_s: float = -1.0
	var interceptor_shots: int = 0
	var trace: Array[Dictionary] = []
	for step: int in 75 * 60:
		session.world.step_ticks(1)
		var events: Array[BattleEvent] = session.world.drain_events()
		var bomber: UnitState = session.world.get_unit("bomber")
		var wing: UnitState = session.world.get_unit("wing")
		if absf(angle_difference(bomber.weapons.dorsal.train_rad, wing.weapons.dorsal.train_rad)) > 0.4 and bomber.weapons.dorsal.remaining_rounds != wing.weapons.dorsal.remaining_rounds and not distinct:
			models.bomber.apply_state(bomber.snapshot())
			models.wing.apply_state(wing.snapshot())
			expect(not is_equal_approx(_axis(models.bomber).rotation.y, _axis(models.wing).rotation.y), "Two live model instances show different turret poses")
			distinct = true
		for event: BattleEvent in events:
			if event.kind == "fired" and event.entity_id == "fighter" and event.target_id in models:
				if first_interceptor_shot_s < 0.0: first_interceptor_shot_s = event.time_s
				interceptor_shots += 1
			if event.kind != "fired" or not event.weapon_id.ends_with("/dorsal"): continue
			var unit: UnitState = session.world.get_unit(event.entity_id)
			var barrel: int = int(event.data.barrel_index)
			shot_counts[unit.id][barrel] += 1
			barrels_seen[barrel] = true
			if first_shot.is_empty():
				first_shot = event.snapshot()
				var mission: Dictionary = session.world.order_snapshot(unit.active_order_id, unit.faction_id)
				expect(mission.get("order_type") == "bombing", "Defending bomber keeps its original mission")
				var interceptor: UnitState = session.world.get_unit("fighter")
				var intercept_order: Dictionary = session.world.order_snapshot(interceptor.active_order_id, interceptor.faction_id)
				expect(intercept_order.get("order_type") == "intercept", "The normal faction commander actually assigns the intercept")
				expect(event.target_id == interceptor.id, "Dorsal event identifies the actual Zero contact")
			if trace.size() < 4:
				trace.append({"s": event.time_s, "unit": unit.id, "target": event.target_id, "barrel": barrel,
					"train_deg": rad_to_deg(event.data.train_rad), "elevation_deg": rad_to_deg(event.data.elevation_rad),
					"tracer": event.data.tracer, "remaining": unit.weapons.dorsal.remaining_rounds.duplicate()})
			var model: Node3D = models[unit.id]
			model.apply_state(unit.snapshot())
			var muzzle: Marker3D = model.visual.model.guns.dorsal.muzzles[barrel]
			expect(muzzle.global_position.distance_to(event.position_m) < 0.005, "Fired origin aligns with the moving model muzzle for barrel %d" % barrel)
			expect((-muzzle.global_basis.z).angle_to(event.data.muzzle_direction) < 0.0065, "Fired axis aligns with the visible tube within game spread")
			tracer_seen = tracer_seen or bool(event.data.tracer)
			if not tracer_verified and bool(event.data.tracer):
				var pair: Array[BattleEvent] = [event]
				effects.consume(pair, session.world.generation)
				expect(effects.slots.any(func(slot: Dictionary) -> bool: return slot.kind == "tracer" and slot.get("projectile_id") == event.data.projectile_id), "Shared effects consume the actual dorsal tracer event")
				tracer_verified = true
		if tracer_seen and distinct and interceptor_shots > 0 and shot_counts.bomber[0] > 0 and shot_counts.wing[0] > 0 and step >= 60 * 40:
			break
	expect(not first_shot.is_empty(), "Autonomous Zero encounter produces dorsal fire")
	expect(float(first_shot.get("time_s", 0.0)) >= 15.0, "The standard intercept leaves time to select and follow an aircraft")
	expect(interceptor_shots > 0 and absf(first_interceptor_shot_s - float(first_shot.get("time_s", 0.0))) < 6.0, "Both sides exchange fire in the same autonomous encounter")
	expect(barrels_seen.size() == 2 and tracer_seen, "Both barrels fire and actual tracer rounds are emitted")
	expect(distinct, "Autonomous encounter yields independent turret pose and inventory")
	for id: String in models:
		var unit: UnitState = session.world.get_unit(id)
		for barrel: int in 2:
			expect(shot_counts[id][barrel] > 0, "The encounter exercises both barrels on " + id)
			expect(unit.weapons.dorsal.remaining_rounds[barrel] == initial[barrel] - shot_counts[id][barrel], "Inventory matches actual event count for %s barrel %d" % [id, barrel])
	var tick: int = session.world.tick
	var before: Dictionary = session.world.get_unit("bomber").weapons.dorsal.snapshot()
	session.world.set_paused(true)
	session.advance(4.0)
	expect(session.world.tick == tick and session.world.get_unit("bomber").weapons.dorsal.snapshot() == before, "Pause freezes turret and inventory")
	expect(session.restart(), "Ordinary restart succeeds")
	expect(session.units.bomber.weapons.dorsal == session.units.wing.weapons.dorsal.merged({"id":"bomber/dorsal"}, true), "Restart restores the same independent default setup")
	expect(session.units.bomber.weapons.dorsal.remaining_rounds == initial and is_zero_approx(session.units.bomber.weapons.dorsal.train_rad), "Restart restores ammunition and neutral traverse")
	var replay: BattleEvent
	for step: int in int(first_shot.get("tick", 0)):
		session.world.step_ticks(1)
		for event: BattleEvent in session.world.drain_events():
			if replay == null and event.kind == "fired" and event.weapon_id.ends_with("/dorsal"):
				replay = event
	expect(replay != null and replay.tick == int(first_shot.tick) and replay.data == first_shot.data, "Restart repeats the first real shot and its geometry")
	print("B25G01 live ", JSON.stringify(trace))
	print("B25G01 intercept exchange ", {"first_zero_s": first_interceptor_shot_s, "zero_rounds": interceptor_shots, "dorsal_rounds": shot_counts})
	effects.free()
	for model: Node3D in models.values(): model.free()

func _axis(model: Node3D) -> Node3D:
	return model.visual.model.guns.dorsal.yaw

func _check_station_gates() -> void:
	var session: FirstPlayableSession = FirstPlayableSession.new()
	if not _load(session, INTERCEPT): return
	var world: SimulationWorld = session.world
	var targeting: CombatTargeting
	var weapons: CombatWeapons
	for module: SimulationModule in world._modules:
		if module is CombatTargeting: targeting = module
		elif module is CombatWeapons: weapons = module
	var unit: UnitState = world.get_unit("bomber")
	var station: WeaponState = unit.weapons.dorsal
	var transform: Transform3D = unit.world_transform()
	var eligible: Vector3 = transform * Vector3(135, 140, 300)
	var observed: Dictionary = {"entity_id": "fighter", "domain": "aircraft", "position_m": eligible,
		"velocity_mps": unit.velocity_mps, "observed_time_s": world.time_s(), "fresh": true, "valid": true}
	# A controlled contact fixture for gates. The live test uses the real sensor scan.
	weapons.intelligence.records["us"] = {"fighter": observed}
	_check_gate(world, unit, targeting, weapons, "traversing")
	var train: float = station.train_rad
	expect(absf(train) > 0.0, "Turret traverses on a suitable own-faction contact")
	observed.fresh = false
	_check_gate(world, unit, targeting, weapons, "no_contact")
	expect(station.train_rad == train, "Losing contact holds the last actual pose")
	observed.fresh = true
	observed.position_m = transform * Vector3(0, 150, 2000)
	_check_gate(world, unit, targeting, weapons, "out_of_range")
	observed.position_m = transform * Vector3(0, -100, 300)
	_check_gate(world, unit, targeting, weapons, "arc")
	observed.position_m = eligible
	unit.module_data.aircraft_motion.surface_contact = true
	_check_gate(world, unit, targeting, weapons, "grounded")
	unit.module_data.aircraft_motion.erase("surface_contact")
	unit.cease_fire = true
	_check_gate(world, unit, targeting, weapons, "hold_fire")
	unit.cease_fire = false
	unit.module_data.damage.parts["weapon:dorsal"] = 0.0
	_check_gate(world, unit, targeting, weapons, "disabled")
	unit.module_data.damage.parts["weapon:dorsal"] = 1.0
	unit.active = false
	_check_gate(world, unit, targeting, weapons, "disabled")
	unit.active = true
	station.remaining_rounds.assign([0, 0])
	_check_gate(world, unit, targeting, weapons, "empty")
	expect(world.get_unit("wing").weapons.dorsal.remaining_rounds[0] > 0, "Exhausting the leader does not mutate the wing's ammunition")

func _check_gate(world: SimulationWorld, unit: UnitState, targeting: CombatTargeting, weapons: CombatWeapons, expected: String) -> void:
	var before: Array = unit.weapons.dorsal.remaining_rounds.duplicate()
	targeting.fixed_update(world, world.fixed_delta_s())
	weapons.fixed_update(world, world.fixed_delta_s())
	expect(unit.module_data.combat_runtime.mount_status.dorsal == expected, "Dorsal station reports " + expected)
	expect(unit.weapons.dorsal.remaining_rounds == before, "Dorsal stock stays unchanged for " + expected)
	expect(not world.drain_events().any(func(event: BattleEvent) -> bool:
		return event.kind == "fired" and event.weapon_id == "bomber/dorsal"), "No dorsal fired event for " + expected)

func _check_other_entries() -> void:
	var session: FirstPlayableSession = FirstPlayableSession.new()
	if _load(session, ATTACK):
		var bombs: int = 0
		var detonations: int = 0
		var pulled_out: bool = false
		var gunfire: int = 0
		for step: int in 150 * 60:
			session.world.step_ticks(1)
			for event: BattleEvent in session.world.drain_events():
				if event.kind == "bomb_released": bombs += 1
				elif event.kind == "bomb_explosion": detonations += 1
				elif event.kind == "fired" and event.weapon_id.ends_with("/dorsal"): gunfire += 1
			var phase: String = session.world.get_unit("bomber").module_data.get("bombing", {}).get("phase", "")
			pulled_out = pulled_out or phase in ["pullout", "egress", "regroup", "return"]
			if detonations >= 12: break
		expect(bombs == 12 and detonations == 12 and pulled_out, "Normal strike releases the finite load, pulls out and resolves impacts")
		expect(gunfire == 0, "Bombing without enemy aircraft leaves the dorsal guns quiet")
		print("B25G01 attack ", {"bombs": bombs, "explosions": detonations, "pullout": pulled_out, "dorsal_events": gunfire})
	if _load(session, HARBOR):
		var ids: Array[String] = ["us_b25_1", "us_b25_2"]
		for id: String in ids:
			expect(session.world.get_unit(id).weapons.has(DORSAL), "Ordinary Harbor installs the same live station on " + id)
		var first_defense_s: float = -1.0
		var shots: int = 0
		var zeros: int = 0
		var dogfight: int = 0
		var tracked: bool = false
		var fighters: Array[String] = ["jp_a6m5a_1944", "us_f6f5_1944"]
		for step: int in 25 * 60:
			session.world.step_ticks(1)
			var lead: UnitState = session.world.get_unit("us_b25_1")
			tracked = tracked or (not (lead.module_data.combat_runtime.mount_targets.dorsal as String).is_empty() and absf(lead.weapons.dorsal.train_rad) > 0.3)
			for event: BattleEvent in session.world.drain_events():
				if event.kind != "fired": continue
				if event.entity_id in ids and event.weapon_id.ends_with("/dorsal"):
					if first_defense_s < 0.0: first_defense_s = event.time_s
					shots += 1
				elif event.entity_id.begins_with("jp_air_") and event.target_id in ids:
					zeros += 1
				else:
					var source: UnitState = session.world.get_unit(event.entity_id)
					var target: UnitState = session.world.get_unit(event.target_id)
					if source != null and target != null and source.definition_id in fighters and target.definition_id in fighters:
						dogfight += 1
		expect(tracked and shots > 0 and zeros > 0, "Default Harbor includes genuine turret tracking and exchange with the interceptors")
		expect(dogfight > 0, "Default Harbor retains an independent fighter dogfight")
		print("B25G01 Harbor ", {"first_defense_s": first_defense_s, "dorsal_rounds": shots, "zero_rounds_against_b25": zeros, "dogfight_rounds": dogfight})
	if _load(session, INSPECT):
		expect(not session.world.unit_ids().any(func(id: String) -> bool: return session.world.get_unit(id).definition_id == "us_b25j_1944_07"), "Parked B-25 inspection uses the existing static presenter")

func _load(session: FirstPlayableSession, path: String) -> bool:
	var errors: PackedStringArray = session.load_battle(path)
	expect(errors.is_empty(), path + " loads through the normal session: " + str(errors))
	if not errors.is_empty(): return false
	var mode: String = session.scenario.showcase.mode
	var script: Script = preload("res://scripts/showcase/expansion/expansion_missions.gd")
	var director: SimulationModule = script.new(mode) if session.scenario.has("carrier_operations") else ShowcaseMissions.new(mode)
	expect(session.world.register_module(director).accepted, "Ordinary Showcase mission dispatcher installed")
	return true
