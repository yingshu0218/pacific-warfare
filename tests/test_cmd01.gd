extends "res://tests/fixtures/combat_test.gd"

const FLEET: Script = preload("res://tests/fixtures/fleet_fixture.gd")

func run_test() -> void:
	_surface_reassignment()
	_air_pair_commitment()
	_external_missions()
	_contact_recognition()
	finish("CMD01")

func _surface_reassignment() -> void:
	var world: SimulationWorld = FLEET.world([
		FLEET.spawn("core", Vector3.ZERO, 7.0, 0.0, "jp_yamato_1944_04"),
		FLEET.spawn("screen", Vector3(-400, 0, 450), 7.0),
		FLEET.spawn("enemy", Vector3(40000, 0, 0), 0.0, 0.0, "us_iowa_bb61_1944_12_28", "us"),
		FLEET.spawn("coast", Vector3(-2500, 20, 0), 0.0, 0.0, "us_5in51_mk13mod4_1945", "us")
	], [], true)
	var core: UnitState = world.get_unit("core")
	var screen: UnitState = world.get_unit("screen")
	var coast: Dictionary = _contact("coast", "ground", Vector3(-2500, 20, 0), "coastal_gun", 9000.0)
	var enemy: Dictionary = _contact("enemy", "ship", Vector3(4000, 0, 0), "heavy_surface", 19000.0)
	var far_enemy: Dictionary = enemy.duplicate()
	far_enemy.position_m = Vector3(14000, 0, 0)
	AircraftFixture.contacts(world, "jp", [coast, far_enemy])
	FLEET.run(world, 1.0)
	var shore_order_id: String = core.active_order_id
	expect(FLEET.record(world, shore_order_id).get("intent") == "shore_battery_threat", "In-range shore gun takes priority over a distant surface track")
	expect(screen.target_id == "coast", "Screen may suppress the threatening battery from its escort station")
	var live_enemy: UnitState = world.get_unit("enemy")
	live_enemy.position_m = Vector3(-40000, 0, 0)
	AircraftFixture.contacts(world, "jp", [coast, enemy])
	FLEET.run(world, 6.0)
	var ship_order_id: String = core.active_order_id
	var ship_order: Dictionary = FLEET.record(world, ship_order_id)
	var shore_order: Dictionary = FLEET.record(world, shore_order_id)
	expect(ship_order.get("target_id") == "enemy" and ship_order.get("intent") == "surface_threat" and core.target_id == "enemy", "A newly known surface threat overrides a shore order within the normal cooldown")
	expect(screen.target_id == "enemy", "Escort uses the same surface priority as the flagship")
	expect(shore_order.get("status") == "superseded" and shore_order.get("replacement_order_id") == ship_order_id, "The former shore order links to its surface replacement")
	expect(core.task.ship.goal_m.x > -2000.0, "Helm uses the observed ship position while the real enemy is far to the west")

	# A replacement should be prompt when another observed threat survives the loss.
	enemy.fresh = false
	AircraftFixture.contacts(world, "jp", [enemy, coast])
	FLEET.run(world, 6.0)
	expect(core.target_id == "coast" and FLEET.record(world, core.active_order_id).get("intent") == "shore_battery_threat", "Lost enemy track allows a replacement before its cooldown expires")
	var final_order_id: String = core.active_order_id
	coast.fresh = false
	coast.observed_time_s = world.time_s()
	AircraftFixture.contacts(world, "jp", [enemy, coast])
	FLEET.run(world, 6.0)
	expect(core.active_order_id == final_order_id and core.task.ship.phase == "search" and core.target_id.is_empty(), "Without a fresh alternative the executor searches the last known position and holds fire")
	FLEET.run(world, 34.0)
	expect(FLEET.record(world, final_order_id).get("reason") == "all_assignments_released:contact_not_reacquired", "Exhausted search appears as failure in the command timeline")

func _air_pair_commitment() -> void:
	var spawns: Array = []
	for i: int in 4:
		spawns.append(AircraftFixture.spawn("fighter_%d" % i, "jp", Vector3(-2500 + 1550 * i, 2000, -2000)))
	spawns.append(AircraftFixture.spawn("bomber_a", "us", Vector3(-20000, 2400, 0), "us_b25j_1944_07"))
	spawns.append(AircraftFixture.spawn("bomber_b", "us", Vector3(-21000, 2400, 0), "us_b25j_1944_07"))
	spawns.append(AircraftFixture.spawn("fighter_a", "us", Vector3(-20000, 2400, 1000), "us_f6f5_1944"))
	spawns.append(AircraftFixture.spawn("fighter_b", "us", Vector3(-21000, 2400, 1000), "us_f6f5_1944"))
	var settings: FleetConfig = FLEET.config()
	settings.data.policy.air_threat_radius_m = 12000.0
	var world: SimulationWorld = FLEET.world(spawns, [
		{"id": "pair_1", "faction_id": "jp", "member_ids": ["fighter_0", "fighter_1"]},
		{"id": "pair_2", "faction_id": "jp", "member_ids": ["fighter_2", "fighter_3"]}
	], true, false, settings)
	var bomber: Dictionary = _contact("bomber_a", "aircraft", Vector3(-3800, 2100, -2000), "level_bomber")
	var fighter: Dictionary = _contact("fighter_a", "aircraft", Vector3(900, 2100, -2000), "fighter")
	AircraftFixture.contacts(world, "jp", [bomber, fighter])
	FLEET.run(world, 1.0)
	var lead: UnitState = world.get_unit("fighter_0")
	var wing: UnitState = world.get_unit("fighter_1")
	var cover: UnitState = world.get_unit("fighter_2")
	var intercept_id: String = lead.active_order_id
	var cover_id: String = cover.active_order_id
	expect(FLEET.record(world, intercept_id).get("recipient_ids") == ["pair_1"] and FLEET.record(world, intercept_id).get("intent") == "intercept_bomber", "First real pair receives the bomber intercept")
	expect(FLEET.record(world, cover_id).get("recipient_ids") == ["pair_2"] and FLEET.record(world, cover_id).get("intent") == "intercept_fighter_cover", "Second real pair receives the fighter engagement")
	FLEET.run(world, 22.0)
	bomber.position_m = Vector3(1600, 2500, -4800)
	fighter.position_m = Vector3(3300, 2400, -5100)
	var bomber_b: Dictionary = _contact("bomber_b", "aircraft", Vector3(-3850, 2100, -2600), "level_bomber")
	var fighter_b: Dictionary = _contact("fighter_b", "aircraft", Vector3(-3750, 2100, -2800), "fighter")
	AircraftFixture.contacts(world, "jp", [bomber, fighter, bomber_b, fighter_b])
	FLEET.run(world, 8.0)
	expect(lead.active_order_id == intercept_id and wing.active_order_id == intercept_id and cover.active_order_id == cover_id,
		"An already engaged pair keeps the same order after geometry and candidate rankings change beyond cooldown")
	var modules: Dictionary = world.snapshot().modules
	var roster: Array = modules.aircraft_tasks.get("rosters", {}).get(intercept_id, [])
	expect(roster == ["fighter_0", "fighter_1"], "Actual executor retains the original lead and wingman roster")

	bomber.fresh = false
	bomber.observed_time_s = world.time_s()
	AircraftFixture.contacts(world, "jp", [bomber, fighter, bomber_b])
	FLEET.run(world, 6.0)
	expect(lead.active_order_id == intercept_id and lead.task.aircraft.phase == "search" and cover.active_order_id == cover_id,
		"Brief loss uses the active order's search while the second pair continues its original engagement")
	FLEET.run(world, 18.0)
	expect(lead.active_order_id == wing.active_order_id and FLEET.record(world, lead.active_order_id).get("target_id") == "bomber_b",
		"Sustained loss permits a new bomber mission with both members of the pair")
	expect(cover.active_order_id == cover_id, "Bomber task changes do not restart the fighter engagement")

func _external_missions() -> void:
	var world: SimulationWorld = FLEET.world([
		FLEET.spawn("ship", Vector3.ZERO, 8.0, 0.0, "jp_yamato_1944_04"),
		FLEET.spawn("retreating_ship", Vector3(-600, 0, 0)),
		AircraftFixture.spawn("flight", "jp", Vector3(0, 1800, 1000)),
		AircraftFixture.spawn("hidden", "us", Vector3(0, 1800, -2500), "us_f6f5_1944")
	], [], true)
	FLEET.order(world, "human_patrol", ["ship"], "patrol", "", Vector3.ZERO, 2000.0, "human")
	FLEET.order(world, "ordered_retreat", ["retreating_ship"], "retreat", "", Vector3(-10000, 0, 0))
	FLEET.order(world, "independent_air", ["flight"], "patrol", "", Vector3(0, 1800, 1000))
	FLEET.run(world, 7.0)
	expect(world.get_unit("ship").active_order_id == "human_patrol", "Commander respects human ownership")
	expect(world.get_unit("retreating_ship").active_order_id == "ordered_retreat", "A ship in ordered withdrawal is never pulled back into combat")
	expect(world.get_unit("flight").active_order_id == "independent_air", "An independent AI flight preserves its own active mission")
	expect(world.orders_snapshot("jp").all(func(order: Dictionary) -> bool: return order.target_id != "hidden"), "An unobserved enemy aircraft never becomes a command target")

func _contact_recognition() -> void:
	var settings: CombatConfig = FIX.config()
	settings.data.unit_profiles.us_f6f5_1944.visual_m = 1000.0
	settings.data.unit_profiles.us_f6f5_1944.radar_aircraft_m = 6000.0
	var arena: Dictionary = FIX.arena([
		FIX.spawn("sensor", "us", Vector3(0, 1500, 0)),
		FIX.spawn("enemy", "jp", Vector3(0, 1500, -2200), "jp_a6m5a_1944")
	], settings)
	var world: SimulationWorld = arena.world
	world.step_ticks(1)
	var radar: Dictionary = CombatContacts.find(world, "us", "enemy")
	expect(radar.get("sensor") == "radar" and not radar.has("role") and not radar.has("surface_range_m"), "Radar-only sightings carry no visual identification")
	world.get_unit("enemy").position_m.z = -500.0
	world.step_ticks(30)
	var visual: Dictionary = CombatContacts.find(world, "us", "enemy")
	expect(visual.get("sensor") == "visual" and visual.get("role") == "fighter", "Visual identification reports the static aircraft role")
	world.get_unit("enemy").position_m.z = -2200.0
	world.step_ticks(30)
	radar = CombatContacts.find(world, "us", "enemy")
	expect(radar.get("sensor") == "radar" and radar.get("role") == "fighter" and not radar.has("damage") and not radar.has("weapons"),
		"Radar updates of a previously identified track carry only known static capability")

static func _contact(id: String, domain: String, point: Vector3, role: String, surface_range_m: float = 0.0) -> Dictionary:
	return {"entity_id": id, "domain": domain, "position_m": point, "velocity_mps": Vector3.ZERO,
		"observed_tick": 0, "observed_time_s": 0.0, "fresh": true, "valid": true, "role": role, "surface_range_m": surface_range_m}
