extends SceneTree
var checks: int = 0
var evidence: Dictionary = {}

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		push_error(message)
		quit(1)
		assert(value, message)

func _initialize() -> void:
	_formation_and_lifecycle()
	_contacts_and_exits()
	_inactive_release()
	_escort()
	var file: FileAccess = FileAccess.open("res://docs/showcase/evidence/S04-training/old-tasks-regression.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(evidence, "\t"))
	print("S04 aircraft tasks PASS checks=", checks)
	quit(0)

func _four() -> Array:
	return [AircraftFixture.spawn("a1", "jp", Vector3(0, 1500, 0)),
		AircraftFixture.spawn("a2", "jp", Vector3(90, 1545, 150)),
		AircraftFixture.spawn("a3", "jp", Vector3(-350, 1630, 330)),
		AircraftFixture.spawn("a4", "jp", Vector3(-260, 1675, 480))]

func _formation_and_lifecycle() -> void:
	var world: SimulationWorld = AircraftFixture.world(_four())
	AircraftFixture.order(world, "patrol", ["a1", "a2", "a3", "a4"], "patrol", "", Vector3(0,1500,-1200), 2500)
	var minimum: float = INF
	var track: Array = []
	for tick: int in range(7200):
		world.step_ticks(1)
		world.drain_events()
		var ids: Array[String] = world.unit_ids()
		for i: int in range(ids.size()):
			for j: int in range(i + 1, ids.size()):
				minimum = minf(minimum, world.get_unit(ids[i]).position_m.distance_to(world.get_unit(ids[j]).position_m))
		if tick % 600 == 0:
			var sample: Dictionary = {"time_s": world.time_s(), "positions": {}}
			for id: String in ids:
				sample.positions[id] = SimData.array3(world.get_unit(id).position_m)
			track.append(sample)
	check(minimum > 25.0, "formation safety minimum " + str(minimum))
	check(world.get_unit("a1").module_data.air_formation.role == "leader", "first pair leader")
	check(world.get_unit("a2").module_data.air_formation.role == "wingman", "first wingman")
	check(world.get_unit("a3").module_data.air_formation.pair_index == 1, "second pair stable slot")
	check(world.get_unit("a3").module_data.air_formation.section_role == "support", "support pair exists")
	evidence.formation = {"minimum_distance_m": minimum, "track": track}
	# A separated wingman must actually close the gap through independent flight.
	world.get_unit("a2").position_m += Vector3(1200, 0, 1400)
	var initial_gap: float = world.get_unit("a2").position_m.distance_to(world.get_unit("a1").position_m)
	AircraftFixture.run(world, 45)
	var final_gap: float = world.get_unit("a2").position_m.distance_to(world.get_unit("a1").position_m)
	check(final_gap < initial_gap * 0.85, "wingman independently rejoins " + str(final_gap))
	evidence.rejoin = {"before_m": initial_gap, "after_m": final_gap}
	# Loss injection tests command membership, not combat damage.
	world.get_unit("a1").active = false
	world.step_ticks(1)
	check(world.get_unit("a2").module_data.air_formation.role == "leader", "survivor takes lead")
	check(world.get_unit("a3").module_data.air_formation.pair_index == 1, "loss does not renumber second pair")
	AircraftFixture.order(world, "split", ["a4"], "regroup", "", world.get_unit("a4").position_m + Vector3(1000,0,-1000), 250)
	world.step_ticks(1)
	check(world.get_unit("a4").active_order_id == "split", "single member reassignment")
	check(world.owned_order_unit_ids("patrol", "aircraft") == ["a2", "a3"], "remaining members retain task")
	AircraftFixture.cancel(world, "patrol")
	world.step_ticks(2)
	check(world.get_unit("a2").active_order_id.is_empty(), "cancel releases old members")
	check(not world.get_unit("a2").module_data.has("aircraft_control"), "cancel removes old steering")
	check(not world.get_unit("a2").module_data.combat_intent.fire, "cancel clears firing")
	check(world.get_unit("a4").active_order_id == "split", "cancel old task preserves reassigned member")
	var regroup: SimulationWorld = AircraftFixture.world(_four())
	AircraftFixture.order(regroup, "assemble", ["a1", "a2", "a3", "a4"], "regroup", "", Vector3(0,1500,-1800), 1300)
	AircraftFixture.run(regroup, 60)
	check(regroup.orders_snapshot()[0].status == "completed", "four regroup completes from actual arrival")
	evidence.lifecycle = "loss_promotion_partial_reassignment_cancel_regroup_passed"

func _contacts_and_exits() -> void:
	var world: SimulationWorld = AircraftFixture.world([AircraftFixture.spawn("a1","jp",Vector3(0,1500,0)), AircraftFixture.spawn("enemy","us",Vector3(0,1500,-1200),"us_f6f5_1944")])
	AircraftFixture.order(world, "attack", ["a1"], "intercept", "enemy")
	world.step_ticks(1)
	check(world.get_unit("a1").task.aircraft.reason == "awaiting_own_contact", "no omniscient pursuit")
	check(world.get_unit("a1").target_id.is_empty(), "unseen enemy not targeted")
	AircraftFixture.contacts(world, "jp", [AircraftFixture.contact("enemy", Vector3(0,1500,-900), Vector3(0,0,-105), world.tick)])
	world.step_ticks(2)
	check(world.get_unit("a1").target_id == "enemy", "observed target uses command queue")
	var last: Vector3 = Vector3(0,1500,-900)
	AircraftFixture.contacts(world, "jp", [AircraftFixture.contact("enemy", last, Vector3(0,0,-105), world.tick, false)])
	world.get_unit("enemy").position_m = Vector3(90000,2000,90000)
	world.step_ticks(2)
	check(world.get_unit("a1").task.aircraft.phase == "search", "stale contact triggers search")
	check(not world.get_unit("a1").module_data.combat_intent.fire and world.get_unit("a1").target_id.is_empty(), "lost contact clears fire and target")
	check(world.get_unit("a1").module_data.aircraft_control.heading_rad < 1.0, "search ignores hidden enemy movement")
	AircraftFixture.run(world, 31)
	check(world.get_unit("a1").task.aircraft.phase == "withdraw", "failed reacquisition withdraws")
	for cause: String in ["fuel", "ammo", "damage"]:
		var initial: Dictionary = {"fuel_kg": 8.0} if cause == "fuel" else {}
		var w: SimulationWorld = AircraftFixture.world([AircraftFixture.spawn("a1", "jp", Vector3(0,1500,0),"jp_a6m5a_1944",0,110,initial)])
		if cause == "ammo":
			for weapon: WeaponState in w.get_unit("a1").weapons.values():
				weapon.remaining_rounds.fill(0)
		if cause == "damage":
			w.get_unit("a1").module_data["damage"] = {"propulsion_factor": 0.35, "control_factor": 0.7, "structure": 20, "structure_max": 100}
		AircraftFixture.order(w, "patrol", ["a1"], "patrol")
		w.step_ticks(1)
		var expected: String = {"fuel":"low_fuel","ammo":"no_ammunition","damage":"severe_damage"}[cause]
		check(w.get_unit("a1").task.aircraft.reason == expected, "actual exit condition " + cause)
		check(not w.get_unit("a1").module_data.combat_intent.fire, "withdraw holds fire")
	var retreat: SimulationWorld = AircraftFixture.world([AircraftFixture.spawn("a1","jp",Vector3(0,1500,0))])
	AircraftFixture.order(retreat,"retreat",["a1"],"retreat","",Vector3(0,1500,-2500),400)
	var events: Array[BattleEvent] = AircraftFixture.run(retreat,40)
	check(not retreat.get_unit("a1").active and bool(retreat.get_unit("a1").module_data.aircraft_motion.exited), "flies into exit area")
	var exits: int = 0
	for event: BattleEvent in events:
		if event.kind == "aircraft_exit":
			exits += 1
			check(not event.data.destroyed and not event.data.landed, "exit is not landing or kill")
	check(exits == 1, "one real exit event")
	evidence.exit_conditions = ["own_contacts", "stale_search", "fuel", "ammo", "severe_damage", "actual_exit_zone"]

func _inactive_release() -> void:
	var world: SimulationWorld = AircraftFixture.world([AircraftFixture.spawn("pilot","jp",Vector3(0,1500,0)),AircraftFixture.spawn("enemy","us",Vector3(0,1500,-900),"us_f6f5_1944")])
	AircraftFixture.order(world,"engage",["pilot"],"engage","enemy")
	AircraftFixture.contacts(world,"jp",[AircraftFixture.contact("enemy",Vector3(0,1500,-900),Vector3(0,0,-105))])
	world.step_ticks(2)
	check(world.get_unit("pilot").target_id == "enemy","release fixture has an applied target")
	world.drain_events()
	world.get_unit("pilot").active = false
	world.step_ticks(2)
	var rejected: int = 0
	for event: BattleEvent in world.drain_events():
		if event.kind == "command_rejected": rejected += 1
	check(rejected == 0,"inactive release submits no illegal clear-target command")
	check(not world.get_unit("pilot").module_data.combat_intent.fire,"inactive release still clears firing intent")
	evidence.inactive_release = "no_invalid_command_and_fire_intent_cleared"

func _escort() -> void:
	var spawns: Array = _four()
	spawns.append(AircraftFixture.spawn("ward", "jp", Vector3(0,800,-400), "us_f6f5_1944"))
	spawns.append(AircraftFixture.spawn("decoy", "us", Vector3(500,1500,-1000), "us_f6f5_1944"))
	var world: SimulationWorld = AircraftFixture.world(spawns)
	AircraftFixture.order(world,"escort",["a1","a2","a3","a4"],"escort","ward",Vector3.ZERO,2500)
	AircraftFixture.contacts(world, "jp", [AircraftFixture.contact("decoy", Vector3(0,1500,-2200))])
	world.step_ticks(1)
	check(world.get_unit("a1").task.aircraft.phase in ["approach","aim","burst"], "attack pair responds to outer threat")
	check(world.get_unit("a3").task.aircraft.phase == "support", "support pair remains guard")
	var guard_position: Vector3 = world.get_unit("a3").position_m
	AircraftFixture.contacts(world, "jp", [AircraftFixture.contact("decoy", Vector3(0,1500,-9000),Vector3(0,0,-140),world.tick)])
	AircraftFixture.run(world, 5)
	check(world.get_unit("a1").task.aircraft.phase == "guard", "decoy outside leash cannot drag attack pair")
	check(world.get_unit("a1").target_id.is_empty(), "leash clears target")
	check(world.get_unit("a3").position_m.distance_to(guard_position) < 1000, "guard path remains finite")
	world.get_unit("ward").active = false
	world.step_ticks(1)
	check(world.get_unit("a1").task.aircraft.reason == "protected_unit_lost", "lost ward switches to explained withdrawal")
	evidence.escort = "outer_threat_attack_pair_guard_pair_leash_return_ward_loss_passed"
