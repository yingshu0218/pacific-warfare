extends "res://tests/fixtures/fleet_test.gd"

func run_test() -> void:
	for reason: String in ["propulsion_unavailable", "fuel_exhausted"]:
		var initial: Dictionary = {"fuel_fraction": 0.0 if reason == "fuel_exhausted" else 1.0}
		var world: SimulationWorld = FLEET.world([FLEET.spawn("ship", Vector3.ZERO, 0.0, 0.0, "jp_yukikaze_1942_06", "jp", initial),
			FLEET.spawn("enemy", Vector3(4500, 0, 0), 0.0, 0.0, "us_fletcher_dd445_1942_07_18", "us")], [], true)
		if reason == "propulsion_unavailable":
			world.get_unit("ship").module_data.damage = {"propulsion_factor": 0.0, "control_factor": 1.0}
		FLEET.contact(world, "enemy", Vector3(4500, 0, 0))
		var events: Array[BattleEvent] = FLEET.run(world, 72.0)
		var ship: UnitState = world.get_unit("ship")
		var records: Array[Dictionary] = world.orders_snapshot("jp")
		expect(records.size() == 1 and records[0].order_type == "retreat" and records[0].status == "executing", "A persistently blocked retreat owns one mission instead of recurring failed/reissued orders")
		expect(ship.task.ship.phase == "blocked" and ship.task.ship.reason == reason and records[0].execution.ship.reason == reason, "Actual inability to move is visible in both the unit and S01 per-member execution state")
		expect(ship.active and not ship.module_data.ship_motion.exited and ship.position_m == Vector3.ZERO, "Blocked retreat does not fake withdrawal, movement, disability or sinking")
		expect(ship.module_data.combat_intent.allow_aa and ship.module_data.combat_intent.fire and ship.target_id == "enemy", "Afloat ship retains eligible AA and known-contact surface self-defence despite loss of mobility")
		var exits: int = 0
		var blocked_reports: int = 0
		for event: BattleEvent in events:
			if event.kind == "ship_exit" and event.entity_id == "ship":
				exits += 1
			if event.kind == "order_execution_changed" and event.entity_id == "ship" and event.data.execution.ship.reason == reason:
				blocked_reports += 1
		expect(exits == 0 and blocked_reports == 1, "Blocked state reports one meaningful change and never emits a false exit")
		evidence[reason] = {"order": records[0], "task": ship.task, "position_m": ship.position_m, "blocked_reports": blocked_reports}
	finish("mobility_blocked")
