extends "res://tests/fixtures/fleet_test.gd"

func run_test() -> void:
	_slow_and_flagship()
	_ownership_and_cancel()
	_terminal_and_source()
	_surface_task()
	finish("fleet_formation")

func _slow_and_flagship() -> void:
	var world: SimulationWorld = FLEET.world([FLEET.spawn("core", Vector3.ZERO, 5.0, 0.0, "jp_yamato_1944_04"), FLEET.spawn("slow", Vector3(300, 0, 2400), 2.0)],
		[{"id": "fleet", "faction_id": "jp", "member_ids": ["core", "slow"]}])
	world.get_unit("slow").module_data.damage = {"propulsion_factor": 0.25, "control_factor": 1.0}
	FLEET.order(world, "cruise", ["fleet"], "patrol", "", Vector3(0, 0, -15000), 1200.0)
	var start: Vector3 = world.get_unit("slow").position_m
	world.step_ticks(1)
	expect(world.get_unit("slow").position_m.distance_to(start) < 0.1, "Formation assignment does not bind or snap member positions")
	expect(world.get_unit("core").task.ship.reason == "slow_member_reform", "A lagging slow member changes the actual leader's task to reform")
	var tracks: Array[Dictionary] = []
	for sample: int in range(50):
		FLEET.run(world, 10.0)
		tracks.append({"time_s": world.time_s(), "core_m": world.get_unit("core").position_m, "slow_m": world.get_unit("slow").position_m,
			"core_speed": world.get_unit("core").velocity_mps.length(), "slow_speed": world.get_unit("slow").velocity_mps.length()})
	var gap: float = world.get_unit("core").position_m.distance_to(world.get_unit("slow").position_m)
	expect(gap < 1800.0 and gap > 150.0, "Slow ship closes its initial 2.4km lag through actual speed coordination while preserving hull separation")
	world.get_unit("core").active = false
	world.get_unit("core").module_data.damage = {"phase": "disabled", "control_factor": 0.0, "propulsion_factor": 0.0}
	var events: Array[BattleEvent] = FLEET.run(world, 0.1)
	var replaced: bool = false
	for event: BattleEvent in events:
		if event.kind == "fleet_flagship_changed" and event.data.get("previous_id", "") == "core" and event.entity_id == "slow":
			replaced = true
	expect(replaced and world.get_unit("slow").module_data.fleet_formation.leader_id == "slow", "Surviving ship assumes actual order leadership after flagship loss")
	expect(FLEET.record(world, "cruise").execution.core.status == "failed" and FLEET.record(world, "cruise").execution.slow.status == "executing", "Flagship loss releases only the lost member; remaining mission continues")
	evidence["slow_reform"] = {"final_gap_m": gap, "track_10s": tracks, "order": FLEET.record(world, "cruise")}

func _ownership_and_cancel() -> void:
	var world: SimulationWorld = FLEET.world([FLEET.spawn("a", Vector3(-500, 0, 0), 4.0), FLEET.spawn("b", Vector3(500, 0, 0), 4.0)])
	FLEET.order(world, "old", ["a", "b"], "patrol")
	FLEET.run(world, 2.0)
	FLEET.order(world, "new", ["b"], "retreat", "", Vector3(500, 0, -800), 250.0, "human")
	world.step_ticks(1)
	expect(world.get_unit("a").active_order_id == "old" and world.get_unit("b").active_order_id == "new", "Partial human reassignment preserves other members of the old order")
	expect(FLEET.record(world, "old").execution.b.status == "superseded" and FLEET.record(world, "old").execution.a.status == "executing", "Per-member ownership and terminal replacement are truthful")
	FLEET.cancel(world, "old")
	world.step_ticks(2)
	expect(not world.get_unit("a").module_data.has("ship_control") and world.get_unit("b").module_data.has("ship_control"), "Cancelling the old mission clears only its controls, not the reassigned member")
	expect(not world.get_unit("a").module_data.combat_intent.fire and not world.get_unit("a").module_data.combat_intent.allow_aa, "Cancelled mission releases all old combat intent")
	FLEET.run(world, 180.0)
	var new_record: Dictionary = FLEET.record(world, "new")
	expect(new_record.status == "completed" and new_record.execution.b.reason == "withdrawal_area_reached", "The reassigned retreat reaches a real terminal state through navigation")
	expect(not world.get_unit("b").active and world.get_unit("b").module_data.ship_motion.exited and world.get_unit("b").position_m.distance_to(Vector3(500, 0, -800)) <= 250.0, "Completed ship withdrawal exits combat in its actual destination area without reporting a sinking")
	evidence["ownership"] = {"old": FLEET.record(world, "old"), "new": new_record, "b_position_m": world.get_unit("b").position_m}

func _terminal_and_source() -> void:
	var positions: Array[Vector3] = []
	for source: String in ["ai", "human"]:
		var world: SimulationWorld = FLEET.world([FLEET.spawn("ship", Vector3.ZERO, 3.0)])
		FLEET.order(world, "regroup", ["ship"], "regroup", "", Vector3(0, 0, -650), 220.0, source)
		FLEET.run(world, 160.0)
		var record: Dictionary = FLEET.record(world, "regroup")
		expect(record.status == "completed" and record.execution.ship.reason == "regroup_area_reached", "Both sources use actual stable arrival to complete regroup")
		expect(record.execution.ship.module_id == "fleet_tasks" and record.source == source, "AI and human sources share the exact registered executor")
		positions.append(world.get_unit("ship").position_m)
		if source == "human":
			evidence["human_regroup"] = {"order": record, "position_m": positions[-1]}
	expect(positions[0] == positions[1] and positions[0].z < -400.0, "Equivalent AI/human commands produce identical real tracks and terminal results")

func _surface_task() -> void:
	var world: SimulationWorld = FLEET.world([FLEET.spawn("core", Vector3.ZERO, 9.0, 0.0, "jp_yamato_1944_04"), FLEET.spawn("enemy", Vector3(0, 0, -6000), 0.0, 0.0, "us_iowa_bb61_1944_12_28", "us")])
	FLEET.contact(world, "enemy", Vector3(0, 0, -6000))
	FLEET.order(world, "fight", ["core"], "engage", "enemy", Vector3(0, 0, -6000))
	var phases: Dictionary = {}
	var track: Array[Dictionary] = []
	for i: int in range(120):
		FLEET.run(world, 1.0)
		var core: UnitState = world.get_unit("core")
		phases[core.task.ship.phase] = true
		if i % 5 == 0:
			track.append({"time_s": world.time_s(), "position_m": core.position_m, "yaw_rad": core.rotation_rad.y, "phase": core.task.ship.phase})
	expect(phases.has("deploy") and phases.has("broadside"), "Engage changes actual heading from deployment to a broadside gunnery course")
	expect(world.get_unit("core").module_data.combat_intent.fire and world.get_unit("core").target_id == "enemy", "Surface task hands target and fire permission to S05 without changing weapons or damage")
	# Enemy secretly teleports; own stale information remains the last observed point.
	world.get_unit("enemy").position_m = Vector3(30000, 0, 30000)
	FLEET.contact(world, "enemy", Vector3(0, 0, -6000), false)
	FLEET.run(world, 1.0)
	expect(world.get_unit("core").task.ship.phase == "search" and world.get_unit("core").task.ship.goal_m.distance_to(Vector3(0, 0, -6000)) < 1.0, "Lost contact searches its own last observation without following hidden enemy coordinates")
	expect(not world.get_unit("core").module_data.combat_intent.fire and world.get_unit("core").target_id.is_empty(), "Lost contact clears firing and the queued low-level target")
	FLEET.run(world, 33.0)
	expect(FLEET.record(world, "fight").status == "failed" and FLEET.record(world, "fight").execution.core.reason == "contact_not_reacquired", "Unreacquired contact produces a real explanatory failure, not an omniscient kill report")
	evidence["surface"] = {"track_5s": track, "phases": phases, "order": FLEET.record(world, "fight")}
