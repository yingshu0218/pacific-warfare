extends "res://tests/fixtures/fleet_test.gd"

func run_test() -> void:
	_fog_and_cadence()
	_air_allocation()
	_human_and_emergencies()
	_capability_and_reset()
	finish("commander")

func _friendly_spawns() -> Array:
	var result: Array = [FLEET.spawn("core", Vector3(-1000, 0, 0), 7.0, 0.0, "jp_yamato_1944_04"), FLEET.spawn("screen", Vector3(-1600, 0, 600), 7.0)]
	for i: int in 4:
		result.append(AircraftFixture.spawn("fighter_%d" % i, "jp", Vector3(-1000 + i * 160, 1500 + i * 30, -700), "jp_a6m5a_1944"))
	return result

func _fog_and_cadence() -> void:
	var original: Array = _friendly_spawns()
	original.append(FLEET.spawn("unknown", Vector3(30000, 0, 20000), 0.0, 0.0, "us_iowa_bb61_1944_12_28", "us"))
	var world: SimulationWorld = FLEET.world(original, [], true)
	var own: Dictionary = world.commander_snapshot("jp")
	world.get_unit("unknown").position_m = Vector3(-50000, 0, -60000)
	world.get_unit("unknown").active = false
	world.get_unit("unknown").module_data.damage = {"phase": "sinking", "structure": 0.0}
	var after: Dictionary = world.commander_snapshot("jp")
	expect(own == after and not own.units.has("unknown") and own.contacts.is_empty(), "Changing unknown enemy location, life and damage cannot change the friendly intelligence snapshot")
	var a: FleetPlanner = FleetPlanner.new(FLEET.config())
	var b: FleetPlanner = FleetPlanner.new(FLEET.config())
	var plans_a: Array = []
	var plans_b: Array = []
	for order: BattleOrder in a.plan(own):
		plans_a.append(order.request_data())
	for order: BattleOrder in b.plan(after):
		plans_b.append(order.request_data())
	expect(plans_a == plans_b and not plans_a.is_empty(), "Same friendly information produces identical high-level decisions regardless of hidden enemy state")
	FLEET.run(world, 60.0)
	expect(world.orders_snapshot("jp").size() == 3, "One-minute no-contact patrol/protection produces three persistent missions, not per-tick command spam")
	var start: Vector3 = world.get_unit("core").position_m
	world.set_paused(true)
	world.advance(20.0)
	expect(world.get_unit("core").position_m == start and world.tick == 3600, "Pause freezes actual movement and commander time")
	evidence["fog"] = {"same_decisions": plans_a, "orders_after_60s": world.orders_snapshot("jp")}

func _air_allocation() -> void:
	var spawns: Array = _friendly_spawns()
	spawns.append(AircraftFixture.spawn("enemy_air", "us", Vector3(1500, 1600, -2000), "us_f6f5_1944", PI, 100.0))
	spawns.append(FLEET.spawn("enemy_ship", Vector3(6000, 0, -2000), 0.0, 0.0, "us_iowa_bb61_1944_12_28", "us"))
	var world: SimulationWorld = FLEET.world(spawns, [{"id": "jp_pair_1", "faction_id": "jp", "member_ids": ["fighter_0", "fighter_1"]},
		{"id": "jp_pair_2", "faction_id": "jp", "member_ids": ["fighter_2", "fighter_3"]}], true)
	var contacts: Array = [AircraftFixture.contact("enemy_air", Vector3(1500, 1600, -2000))]
	contacts.append({"entity_id": "enemy_ship", "domain": "ship", "classification": "ship", "position_m": Vector3(6000, 0, -2000), "velocity_mps": Vector3.ZERO,
		"observed_tick": 0, "observed_time_s": 0.0, "fresh": true, "valid": true})
	AircraftFixture.contacts(world, "jp", contacts)
	FLEET.run(world, 1.0)
	var intercept: Dictionary = {}
	var reserve: Dictionary = {}
	for order: Dictionary in world.orders_snapshot("jp"):
		if order.intent == "intercept_air_threat":
			intercept = order
		if order.intent == "reserve_air_cover":
			reserve = order
	evidence["allocation"] = world.orders_snapshot("jp")
	expect(not intercept.is_empty() and not reserve.is_empty() and intercept.execution.size() == 2 and reserve.execution.size() == 2, "Air threat assigns one real pair to intercept and keeps one real pair protecting the core")
	if intercept.is_empty() or reserve.is_empty():
		return
	expect(intercept.recipient_ids == ["jp_pair_2"] and reserve.recipient_ids == ["jp_pair_1"], "The closer existing pair intercepts and the other pair keeps the screen")
	expect(intercept.execution.get("fighter_2", {}).get("module_id") == "aircraft_tasks" and world.get_unit("fighter_2").module_data.has("aircraft_control"), "Aircraft decisions use the formal S04 executor and actual flight control")
	expect(world.get_unit("screen").task.ship.phase == "air_defence" and world.get_unit("core").task.ship.phase in ["approach", "deploy", "broadside"], "Commander separately schedules surface engagement and naval air defence")
	evidence["allocation"] = world.orders_snapshot("jp")

func _human_and_emergencies() -> void:
	var world: SimulationWorld = FLEET.world(_friendly_spawns(), [], true)
	FLEET.order(world, "human_core", ["core"], "patrol", "", Vector3(0, 0, -5000), 800.0, "human")
	FLEET.run(world, 7.0)
	expect(world.get_unit("core").active_order_id == "human_core", "Program commander respects the live human mission through the same ownership entry")
	world.get_unit("screen").module_data.ship_motion.fuel_fraction = 0.04
	world.get_unit("fighter_0").module_data.aircraft_motion.fuel_kg = 1.0
	world.get_unit("fighter_1").module_data.damage = {"propulsion_factor": 0.3, "control_factor": 0.8, "structure": 1.0, "structure_max": 1.0}
	for weapon: WeaponState in world.get_unit("fighter_2").weapons.values():
		weapon.remaining_rounds.fill(0)
	# Inspect the pure decision output before S04 performs autonomous withdrawal.
	var planner: FleetPlanner = FleetPlanner.new(FLEET.config())
	var reasons: Array[String] = []
	for order: BattleOrder in planner.plan(world.commander_snapshot("jp")):
		if order.order_type == "retreat":
			reasons.append(order.intent)
	expect(reasons.has("low_fuel") and reasons.has("severe_damage") and reasons.has("no_ammunition"), "Own fuel, damage and real inventory each create explanatory retreat choices")
	FLEET.cancel(world, "human_core")
	FLEET.run(world, 6.0)
	expect(not world.get_unit("core").active_order_id.is_empty() and world.get_unit("core").active_order_id != "human_core", "After explicit cancellation the same commander may resume an unowned ship")
	var fleet_world: SimulationWorld = FLEET.world([FLEET.spawn("core", Vector3.ZERO, 7.0, 0.0, "jp_yamato_1944_04"), FLEET.spawn("screen", Vector3(-620, 0, 500), 7.0)], [], true)
	FLEET.run(fleet_world, 3.0)
	fleet_world.get_unit("core").active = false
	fleet_world.get_unit("core").module_data.damage = {"phase": "disabled", "control_factor": 0.0}
	FLEET.run(fleet_world, 4.0)
	var replacement: Dictionary = FLEET.record(fleet_world, fleet_world.get_unit("screen").active_order_id)
	expect(replacement.intent == "flagship_replacement" and replacement.order_type == "patrol", "Flagship loss bypasses ordinary cooldown and produces a new mission for the surviving core")
	evidence["emergency_reasons"] = reasons
	evidence["flagship_replacement"] = replacement
	var depleted_view: Dictionary = fleet_world.commander_snapshot("jp")
	depleted_view.units.screen.active = false
	# Add a surviving aircraft from an actual friendly snapshot, without enemy data.
	depleted_view.units["fighter_3"] = world.get_unit("fighter_3").snapshot()
	var depletion: Array[BattleOrder] = FleetPlanner.new(FLEET.config()).plan(depleted_view)
	var exits_force: bool = false
	for order: BattleOrder in depletion:
		if order.order_type == "retreat" and order.intent == "force_depleted":
			exits_force = true
	expect(exits_force, "Loss of all viable surface cores gives surviving aircraft an explicit force-depleted retreat choice")

func _capability_and_reset() -> void:
	var world: SimulationWorld = FLEET.world([FLEET.spawn("ship", Vector3.ZERO), AircraftFixture.spawn("air", "us", Vector3(2000, 1400, -2000), "us_f6f5_1944")])
	FLEET.order(world, "old", ["ship"], "patrol")
	world.step_ticks(1)
	FLEET.order(world, "unsupported", ["ship"], "intercept", "air")
	world.step_ticks(1)
	expect(FLEET.record(world, "unsupported").status == "failed" and FLEET.record(world, "unsupported").reason == "ship_intercept_unsupported", "Unavailable ship interception fails visibly and truthfully")
	expect(world.get_unit("ship").active_order_id == "old", "Rejected capability check does not steal the old assignment")
	var receipt: Dictionary = world.submit_order(BattleOrder.from_data({"order_id": "invalid", "issuer_id": "test", "faction_id": "jp", "recipient_ids": ["ship"], "order_type": "launch_aircraft"}))
	expect(not receipt.accepted and receipt.reason == "unsupported_order_type", "Unimplemented launch operations are explicitly rejected")
	expect(world.reset() and world.orders_snapshot().is_empty() and not world.get_unit("ship").module_data.ship_motion.exited and not world.get_unit("ship").module_data.has("ship_control"), "Reset clears orders, ownership, helm caches, exit flags and command decisions")
	var config: FleetConfig = FLEET.config()
	var invalid: Dictionary = config.data.duplicate(true)
	invalid.profiles.jp_yamato_1944_04.turn_radius_m = -10.0
	expect(not config.load_data(invalid).is_empty() and float(config.profile("jp_yamato_1944_04").turn_radius_m) > 0.0, "Invalid settings reject atomically and retain the previous valid configuration")
	expect(not FleetSuite.install(world).is_empty(), "Duplicate installation is rejected before mutation")
