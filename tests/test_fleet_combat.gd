extends "res://tests/fixtures/fleet_test.gd"

func run_test() -> void:
	var config: FleetConfig = FLEET.config()
	config.data.commanders.jp = {"patrol_center_m": [-3200, 0, -3000], "patrol_radius_m": 1200.0, "retreat_center_m": [-8500, 0, 5000], "air_retreat_center_m": [-8500, 1500, 5000]}
	config.data.commanders.us = {"patrol_center_m": [3200, 0, -3000], "patrol_radius_m": 1200.0, "retreat_center_m": [8500, 0, 5000], "air_retreat_center_m": [8500, 1500, 5000]}
	var spawns: Array = [FLEET.spawn("jp_core", Vector3(-3500, 0, 0), 8.0, 0.0, "jp_yamato_1944_04"),
		FLEET.spawn("jp_screen", Vector3(-4120, 0, 800), 8.0),
		FLEET.spawn("us_core", Vector3(3500, 0, 0), 8.0, 0.0, "us_iowa_bb61_1944_12_28", "us"),
		FLEET.spawn("us_screen", Vector3(2880, 0, 800), 8.0, 0.0, "us_fletcher_dd445_1942_07_18", "us")]
	var groups: Array = [{"id": "jp_fleet", "faction_id": "jp", "member_ids": ["jp_core", "jp_screen"]}, {"id": "us_fleet", "faction_id": "us", "member_ids": ["us_core", "us_screen"]}]
	for faction: String in ["jp", "us"]:
		var plane_ids: Array[String] = []
		for i: int in 4:
			var id: String = faction + "_fighter_%d" % i
			plane_ids.append(id)
			var position: Vector3 = Vector3((-1800.0 if faction == "jp" else 1800.0) + float(i % 2) * 100.0, 1500.0 + float(i % 2) * 40.0, -2000.0 + float(i / 2) * 450.0)
			spawns.append(AircraftFixture.spawn(id, faction, position, "jp_a6m5a_1944" if faction == "jp" else "us_f6f5_1944", -PI * 0.5 if faction == "jp" else PI * 0.5, 110.0,
				{"withdrawal_center_m": config.data.commanders[faction].air_retreat_center_m, "withdrawal_radius_m": 600.0}))
		groups.append({"id": faction + "_flight", "faction_id": faction, "member_ids": plane_ids})
		groups.append({"id": faction + "_pair_1", "faction_id": faction, "member_ids": plane_ids.slice(0, 2)})
		groups.append({"id": faction + "_pair_2", "faction_id": faction, "member_ids": plane_ids.slice(2)})
	var world: SimulationWorld = FLEET.world(spawns, groups, true, true, config)
	var counts: Dictionary = {}
	var fire_by_domain: Dictionary = {"ship": 0, "aircraft": 0}
	var timeline: Array[Dictionary] = []
	var impacts: Array[Dictionary] = []
	var tracks: Array[Dictionary] = []
	var modules_before: Dictionary = world.snapshot().modules
	for module: String in ["fleet_commander", "fleet_tasks", "ship_motion", "aircraft_tasks", "aircraft_motion", "combat_contacts", "combat_targeting", "combat_weapons", "combat_projectiles", "combat_damage"]:
		expect(modules_before.has(module), "Witness installs the formal suite module: " + module)
	for tick: int in range(7200):
		world.step_ticks(1)
		for event: BattleEvent in world.drain_events():
			counts[event.kind] = int(counts.get(event.kind, 0)) + 1
			if event.kind == "fired":
				var domain: String = "aircraft" if event.entity_id.contains("fighter") else "ship"
				fire_by_domain[domain] += 1
			if event.kind in ["order_issued", "order_status_changed", "order_execution_changed", "fleet_flagship_changed", "ship_exit", "aircraft_exit"]:
				timeline.append({"time_s": event.time_s, "kind": event.kind, "entity_id": event.entity_id, "data": event.data})
			if event.kind in ["hit", "damaged", "disabled", "damage_phase"] and impacts.size() < 80:
				impacts.append({"time_s": event.time_s, "kind": event.kind, "entity_id": event.entity_id, "target_id": event.target_id, "position_m": event.position_m, "data": event.data})
		if tick % 300 == 0:
			var sample: Dictionary = {"time_s": world.time_s(), "units": {}}
			for id: String in world.unit_ids():
				var unit: UnitState = world.get_unit(id)
				sample.units[id] = {"position_m": unit.position_m, "yaw_rad": unit.rotation_rad.y, "speed_mps": unit.velocity_mps.length(), "active": unit.active,
					"phase": unit.module_data.damage.phase, "order_id": unit.active_order_id, "task": unit.task.duplicate(true)}
			tracks.append(sample)
	var damaged: int = 0
	for id: String in world.unit_ids():
		var damage: Dictionary = world.get_unit(id).module_data.damage
		if float(damage.structure) < float(damage.structure_max):
			damaged += 1
	expect(fire_by_domain.ship > 0 and fire_by_domain.aircraft > 0, "Commander missions produce actual formal ship and aircraft gunfire")
	expect(int(counts.get("hit", 0)) > 0 and int(counts.get("damaged", 0)) > 0 and damaged > 0, "Unmodified combat parameters produce real swept projectile hits and persistent damage")
	expect(int(counts.get("airburst", 0)) > 0, "Actual naval air-defence assignments produce timed heavy-AA bursts")
	expect(world.orders_snapshot("jp").size() > 0 and world.orders_snapshot("us").size() > 0 and world.orders_snapshot().size() < 45, "Both commanders make bounded high-level decisions during the full combined-arms witness")
	expect(world.get_unit("jp_core").module_data.ship_motion.distance_m > 300.0 and world.get_unit("us_core").module_data.ship_motion.distance_m > 300.0, "High-level surface missions change both ships' real tracks")
	var final: Dictionary = {}
	for id: String in world.unit_ids():
		var unit: UnitState = world.get_unit(id)
		final[id] = {"position_m": unit.position_m, "active": unit.active, "damage": unit.module_data.damage.duplicate(true), "ship_motion": unit.module_data.get("ship_motion", {}).duplicate(true)}
	evidence.merge({"scenario": "4 ships / 8 aircraft; no durability, damage, hit or weapon overrides", "seed": 606, "duration_s": world.time_s(), "counts": counts,
		"fired_by_domain": fire_by_domain, "damaged_units": damaged, "orders": world.orders_snapshot(), "timeline": timeline, "tracks_5s": tracks, "impact_sample": impacts, "final": final})
	finish("combined_witness")
