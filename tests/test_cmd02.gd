extends "res://tests/fixtures/combat_test.gd"

const FLEET: Script = preload("res://tests/fixtures/fleet_fixture.gd")
const HARBOR: String = "res://data/scenarios/s14_expansion_harbor.json"

func run_test() -> void:
	_same_situation()
	_automatic_postures()
	_order_gate()
	_strike_reserve()
	finish("CMD02")

func _world(mode: String) -> SimulationWorld:
	var config: FleetConfig = FLEET.config()
	config.data.commanders.jp["postures"] = {"fleet": mode, "air": mode}
	var spawns: Array = [
		FLEET.spawn("core", Vector3.ZERO, 4.0, 0.0, "jp_yamato_1944_04"),
		FLEET.spawn("screen", Vector3(0, 0, 500)),
		FLEET.spawn("near", Vector3(4500, 0, 0), 0.0, 0.0, "us_fletcher_dd445_1942_07_18", "us"),
		FLEET.spawn("heavy", Vector3(8800, 0, 0), 0.0, 0.0, "us_iowa_bb61_1944_12_28", "us"),
		AircraftFixture.spawn("bomber", "us", Vector3(-5300, 1500, 0), "us_b25j_1944_07"),
		AircraftFixture.spawn("raider", "us", Vector3(7600, 1500, 0), "us_f6f5_1944")
	]
	for index: int in 4:
		spawns.append(AircraftFixture.spawn("fighter_%d" % index, "jp", Vector3(-1000.0 + 500.0 * index, 1700.0, -350.0)))
	return FLEET.world(spawns, [
		{"id": "pair_west", "faction_id": "jp", "member_ids": ["fighter_0", "fighter_1"]},
		{"id": "pair_east", "faction_id": "jp", "member_ids": ["fighter_2", "fighter_3"]}
	], true, false, config)

func _contact(id: String, domain: String, point: Vector3, role: String, radius: float = 0.0) -> Dictionary:
	return {"entity_id": id, "domain": domain, "position_m": point, "velocity_mps": Vector3.ZERO,
		"observed_tick": 0, "observed_time_s": 0.0, "fresh": true, "valid": true, "role": role, "surface_range_m": radius}

func _contacts() -> Array:
	return [
		_contact("near", "ship", Vector3(4500, 0, 0), "light_surface", 1300.0),
		_contact("heavy", "ship", Vector3(8800, 0, 0), "heavy_surface", 1800.0),
		_contact("bomber", "aircraft", Vector3(-5300, 1500, 0), "level_bomber"),
		_contact("raider", "aircraft", Vector3(7600, 1500, 0), "fighter"),
	]

func _same_situation() -> void:
	var expected: Dictionary = {
		"offensive": ["heavy", ["bomber", "raider"], 0],
		"balanced": ["near", ["bomber"], 2],
		"conservative": ["", [], 4]
	}
	for mode: String in expected:
		var world: SimulationWorld = _world(mode)
		AircraftFixture.contacts(world, "jp", _contacts())
		world.step_ticks(4)
		var fleet_order: Dictionary = world.order_snapshot(world.get_unit("core").active_order_id, "jp")
		expect(fleet_order.get("target_id") == expected[mode][0] and fleet_order.get("issuer_id") == "jp_fleet_commander"
			and fleet_order.get("status") == "executing" and world.get_unit("core").target_id == expected[mode][0],
			"%s fleet applies the expected actual mission" % mode)
		var intercepts: Array[String] = []
		var guard_count: int = 0
		for order: Dictionary in world.orders_snapshot("jp"):
			if order.issuer_id != "jp_air_commander" or order.status != "executing":
				continue
			if order.order_type == "intercept":
				intercepts.append(order.target_id)
				expect(order.assigned_unit_ids.size() == 2, "%s preserves a real interceptor pair" % mode)
			elif order.order_type == "escort":
				guard_count += order.assigned_unit_ids.size()
		intercepts.sort()
		expect(intercepts == expected[mode][1] and guard_count == expected[mode][2], "%s air dispatches different intercepts and reserves" % mode)
		print("CMD02 ", mode, " executing fleet=", fleet_order.get("order_type"), "/", fleet_order.get("target_id"),
			" air_intercepts=", intercepts, " screen_fighters=", guard_count)

func _automatic_postures() -> void:
	var world: SimulationWorld = _world("auto")
	world.step_ticks(4)
	var first: Dictionary = world.shared_state.command_postures.jp
	expect(first.fleet.posture == "balanced" and first.air.posture == "balanced", "No relevant own contact results in two balanced posts")
	AircraftFixture.contacts(world, "jp", _contacts())
	FLEET.run(world, 6.0)
	expect(first.fleet.posture == "balanced" and first.air.posture == "balanced", "Brief contact does not bypass the decision dwell")
	FLEET.run(world, 6.0)
	expect(first.fleet.posture == "offensive" and first.air.posture == "offensive", "Own new contacts and available force promote both posts")
	var order_before: String = world.get_unit("fighter_0").active_order_id
	for id: String in ["fighter_1", "fighter_2", "fighter_3"]:
		world.get_unit(id).module_data["command_assignment"] = {"phase": "active"}
	FLEET.run(world, 12.0)
	expect(first.fleet.posture == "offensive" and first.air.posture == "conservative", "Air availability loss downgrades only the air post")
	var retained: Dictionary = world.order_snapshot(order_before, "jp")
	expect(retained.get("status") == "executing" and world.get_unit("fighter_0").active_order_id == order_before,
		"An executing raid intercept survives the air posture downgrade")
	for id: String in ["fighter_1", "fighter_2", "fighter_3"]:
		world.get_unit(id).module_data.erase("command_assignment")
	FLEET.run(world, 12.0)
	expect(first.air.posture == "offensive" and first.air.reason == "posture_contact_ready", "Returning available aircraft restore offensive air posture")
	world.get_unit("screen").active = false
	world.get_unit("core").module_data["command_assignment"] = {"phase": "active"}
	FLEET.run(world, 12.0)
	expect(first.fleet.posture == "conservative" and first.air.posture != "conservative", "Surface losses and unavailable escort affect the fleet post independently")
	world.get_unit("core").module_data.erase("command_assignment")
	AircraftFixture.contacts(world, "jp", [])
	FLEET.run(world, 12.0)
	expect(first.fleet.posture == "conservative" and first.air.posture == "balanced", "No contact relaxes the air post while losses still constrain the fleet")
	expect(world.reset() and world.orders_snapshot().is_empty() and world.shared_state.command_postures.jp.air.changed_tick == 0, "Reset clears prior command work and stance changes")
	AircraftFixture.contacts(world, "jp", _contacts())
	world.step_ticks(4)
	var replay: Array[Dictionary] = world.orders_snapshot()
	world.reset()
	AircraftFixture.contacts(world, "jp", _contacts())
	world.step_ticks(4)
	expect(replay == world.orders_snapshot(), "Reset repeats the same actual order IDs, decisions and lifecycle")

func _submit(world: SimulationWorld, id: String, issuer: String, recipients: Array, source: String = "ai") -> Dictionary:
	var order: BattleOrder = BattleOrder.from_data({"order_id": id, "issuer_id": issuer, "faction_id": "jp",
		"source": source, "recipient_ids": recipients, "order_type": "patrol", "area": {"center_m": [0, 1200, 0], "radius_m": 2000}})
	return world.submit_order(order)

func _order_gate() -> void:
	var world: SimulationWorld = _world("offensive")
	expect(_submit(world, "fleet_foreign_role", "jp_fleet_commander", ["pair_west"]).reason == "wrong_command_post_domain", "Fleet post cannot order air groups")
	expect(_submit(world, "air_foreign_role", "jp_air_commander", ["core"]).reason == "wrong_command_post_domain", "Air post cannot order ships")
	expect(_submit(world, "foreign_identity", "us_fleet_commander", ["core"]).reason == "wrong_command_post", "The same gate rejects a foreign post identity")
	expect(_submit(world, "foreign_recipient", "jp_fleet_commander", ["heavy"]).reason == "wrong_faction", "The same gate rejects foreign recipients")
	expect(_submit(world, "human_orders_core", "local_player", ["core"], "human").accepted, "Ordinary human source submits through the common order gate")
	expect(_submit(world, "racing_program", "jp_fleet_commander", ["core"]).accepted, "Second order initially queues while neither mission is active")
	world.step_ticks(4)
	var human: Dictionary = world.order_snapshot("human_orders_core", "jp")
	expect(world.get_unit("core").active_order_id == "human_orders_core" and human.get("status") == "executing", "Human order is executed by the regular ship handler")
	expect(world.order_snapshot("racing_program", "jp").is_empty(), "Dispatch rechecks and rejects an order queued behind the new human assignment")
	expect(_submit(world, "later_program", "jp_fleet_commander", ["core"]).reason == "protected_assignment", "Planner gate protects the existing human assignment after it starts")
	world.get_unit("fighter_0").module_data["carrier_ops"] = {"phase": "standby", "on_deck": true}
	expect(_submit(world, "parked_program", "jp_air_commander", ["pair_west"]).reason == "protected_assignment", "A group order cannot take over an aircraft held on deck")

func _strike_orders(world: SimulationWorld, faction: String = "us") -> Array[Dictionary]:
	return world.orders_snapshot(faction).filter(func(order: Dictionary) -> bool: return order.order_type == "bombing")

func _reserve_us_fighters(world: SimulationWorld, hold: bool) -> void:
	for id: String in ["us_air_1", "us_air_2", "us_air_3", "us_air_4", "us_pair_demo_1", "us_pair_demo_2"]:
		if hold:
			world.get_unit(id).module_data["command_assignment"] = {"phase": "active"}
		else:
			world.get_unit(id).module_data.erase("command_assignment")

func _strike_reserve() -> void:
	var session: FirstPlayableSession = FirstPlayableSession.new()
	var errors: PackedStringArray = session.load_battle(HARBOR)
	expect(errors.is_empty(), "Production harbor session loads")
	if not errors.is_empty():
		return
	var world: SimulationWorld = session.world
	var mission: SimulationModule = load("res://scripts/showcase/expansion/expansion_missions.gd").new("harbor")
	expect(world.register_module(mission).accepted, "Regular harbor initial missions register")
	world.step_ticks(4)
	var strikes: Array[Dictionary] = _strike_orders(world)
	expect(strikes.size() == 2 and strikes.all(func(order: Dictionary) -> bool: return order.issuer_id == "us_air_commander" and order.status == "executing"),
		"Same starting contacts normally dispatch two US goals to their real aviation executor")
	expect(_strike_orders(world, "jp").size() == 1 and _strike_orders(world, "jp")[0].issuer_id == "jp_air_commander",
		"Japanese bombing and fighter orders share their own aviation identity")
	if strikes.size() != 2:
		return
	var strike_id: String = world.get_unit("us_sb2c_1").active_order_id
	_reserve_us_fighters(world, true)
	FLEET.run(world, 12.05)
	expect(world.shared_state.command_postures.us.air.posture == "conservative" and world.get_unit("us_sb2c_1").active_order_id == strike_id,
		"Conservative aviation preserves an already accepted real strike")
	world.reset()
	_reserve_us_fighters(world, true)
	world.step_ticks(4)
	expect(world.shared_state.command_postures.us.air.posture == "conservative" and _strike_orders(world).is_empty(),
		"With the same known goals and contact geometry, a reserve posture delays new US strike dispatch")
	expect(not CombatContacts.find(world, "us", "jp_cv").is_empty(), "Held strike still has its nominal target contact")
	_reserve_us_fighters(world, false)
	FLEET.run(world, 13.1)
	var recovered: Array[Dictionary] = _strike_orders(world)
	expect(world.shared_state.command_postures.us.air.posture != "conservative" and not recovered.is_empty()
		and int(recovered[0].issued_tick) > world.tick_hz * 10 and recovered[0].status == "executing",
		"Readiness recovery reassesses the pending goal and submits a fresh executed bombing order")
	print("CMD02 US strike dispatch: initial=", strikes.map(func(order: Dictionary) -> Array: return order.recipient_ids),
		" after hold/recovery=", recovered.map(func(order: Dictionary) -> Array: return [order.issued_tick, order.recipient_ids]))
