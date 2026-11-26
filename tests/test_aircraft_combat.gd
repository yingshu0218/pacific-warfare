extends SceneTree

const EVIDENCE_DIR: String = "res://.local/repairs/20261119_showcase_command/air01"

var checks: int = 0
var failures: int = 0
var evidence: Dictionary = {}

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	for count: int in [2, 4]:
		var world: SimulationWorld = _arena(count)
		var stats: Dictionary = _fight(world, count, 160)
		evidence[str(count) + "v" + str(count)] = stats
		print("S04 real combat ", count, "v", count, " fired=",stats.fired," hit=",stats.hit," damaged=",stats.damaged," min_friend_m=",stats.min_friend_m," reengagements=",stats.reengagements)
		check(int(stats.fired) > 20, "real ammunition fired")
		check(int(stats.hit) > 0 and int(stats.damaged) > 0, "real projectile collision and damage in " + str(count) + "v" + str(count))
		check(stats.fired == stats.inventory_consumed, "every real shot consumes inventory")
		check(int(stats.reengagements) > 0, "actual maneuver returns to engagement")
		check(stats.phases.has("approach") and stats.phases.has("burst") and (stats.phases.has("extend") or stats.phases.has("evade")), "approach fire and break phases")
		check(float(stats.min_friend_m) > 20.0, "combat friend spacing " + str(stats.min_friend_m))
		var permitted_rejections: int = 1 if count == 4 else 0
		var expected_rejections: bool = int(stats.command_rejected) <= permitted_rejections and stats.rejections.all(
			func(rejection: Dictionary) -> bool: return rejection.stale_target_lock)
		check(expected_rejections, "only a single stale aircraft target lock can be rejected in 4v4")
		if count == 4:
			check(bool(stats.split_targets), "two pairs actually engage separate targets")
		var first: Dictionary = world.snapshot()
		first.erase("generation")
		check(world.reset(), "combat reset")
		_issue(world, count)
		var repeated: Dictionary = _fight(world, count, 160)
		var second: Dictionary = world.snapshot()
		second.erase("generation")
		var replay_matches: bool = first == second and stats == repeated
		check(replay_matches, "full combat deterministic after reset")
		stats["replay_matches"] = replay_matches
	_surface_boundary()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(EVIDENCE_DIR))
	var file: FileAccess = FileAccess.open(EVIDENCE_DIR.path_join("s04-combat-final.json"), FileAccess.WRITE)
	check(file != null, "save S04 combat regression evidence")
	if file != null:
		evidence["checks"] = checks
		evidence["failures"] = failures
		file.store_string(JSON.stringify(evidence, "\t") + "\n")
		file.close()
	print("S04 aircraft combat checks=", checks, " failures=", failures)
	quit(0 if failures == 0 else 1)

func _arena(count: int) -> SimulationWorld:
	var spawns: Array = []
	for index: int in range(count):
		var pair: int = index / 2
		var wing: int = index % 2
		var offset: Vector3 = Vector3(-350 * pair + 90 * wing, 1500 + 130 * pair + 45 * wing, 330 * pair + 150 * wing)
		spawns.append(AircraftFixture.spawn("jp_%d" % index,"jp",offset,"jp_a6m5a_1944",0,120))
		spawns.append(AircraftFixture.spawn("us_%d" % index,"us",Vector3(0,0,-3800) + Vector3(-offset.x,offset.y,-offset.z),"us_f6f5_1944",PI,120))
	var world: SimulationWorld = AircraftFixture.world(spawns, true)
	_issue(world, count)
	return world

func _issue(world: SimulationWorld, count: int) -> void:
	var jp: Array[String] = []
	var us: Array[String] = []
	for i: int in range(count):
		jp.append("jp_%d" % i)
		us.append("us_%d" % i)
	AircraftFixture.order(world,"jp_engage",jp,"engage","us_0",Vector3(0,1500,-1800),2000)
	AircraftFixture.order(world,"us_engage",us,"engage","jp_0",Vector3(0,1500,-1800),2000)

func _fight(world: SimulationWorld, count: int, seconds: int) -> Dictionary:
	var stats: Dictionary = {"fired":0,"hit":0,"damaged":0,"disabled":0,"aircraft_exit":0,"command_rejected":0,"inventory_consumed":0,
		"min_friend_m":100000.0,"phases":{},"split_targets":false,"track":[],"first_hits":[],"mount_reasons":{},"reengagements":0,"shot_times_s":[],"previous_phases":{},"rejections":[]}
	var initial_rounds: int = _rounds(world)
	for tick: int in range(seconds * 60):
		world.step_ticks(1)
		for event: BattleEvent in world.drain_events():
			if stats.has(event.kind) and stats[event.kind] is int:
				stats[event.kind] += 1
			if event.kind == "command_rejected":
				stats.rejections.append({"tick":event.tick, "request":event.data.get("request", {}),
					"reason":event.data.get("reason", ""), "stale_target_lock":_stale_target_lock(world, event)})
			if event.kind == "fired" and stats.shot_times_s.size() < 300:
				stats.shot_times_s.append(event.time_s)
			if event.kind == "hit" and stats.first_hits.size() < 5:
				stats.first_hits.append({"tick":event.tick,"shooter":event.entity_id,"target":event.target_id,"weapon":event.weapon_id,"position":SimData.array3(event.position_m),"part":event.data.part_id})
		for id: String in world.unit_ids():
			var unit: UnitState = world.get_unit(id)
			if not unit.active:
				continue
			var phase: String = str(unit.task.get("aircraft",{}).get("phase","none"))
			var previous: String = str(stats.previous_phases.get(id, ""))
			if previous in ["extend", "evade"] and phase in ["aim", "approach", "burst"]:
				stats.reengagements += 1
			stats.previous_phases[id] = phase
			stats.phases[phase] = int(stats.phases.get(phase,0)) + 1
			for other_id: String in world.unit_ids():
				var other: UnitState = world.get_unit(other_id)
				if other.id > unit.id and other.active and other.faction_id == unit.faction_id:
					stats.min_friend_m = minf(float(stats.min_friend_m), unit.position_m.distance_to(other.position_m))
			for status: String in unit.module_data.get("combat_runtime",{}).get("mount_status",{}).values():
				stats.mount_reasons[status] = int(stats.mount_reasons.get(status,0))+1
		if count == 4:
			var a: String = world.get_unit("jp_0").target_id
			var b: String = world.get_unit("jp_2").target_id
			if not a.is_empty() and not b.is_empty() and a != b:
				stats.split_targets = true
		if tick % 600 == 0:
			var sample: Dictionary = {"time_s": world.time_s(),"units":{}}
			for id: String in world.unit_ids():
				var unit: UnitState = world.get_unit(id)
				sample.units[id] = {"position":SimData.array3(unit.position_m),"active":unit.active,"phase":unit.task.get("aircraft",{}).get("phase","none"),"fuel":unit.module_data.aircraft_motion.fuel_kg}
			stats.track.append(sample)
	stats.inventory_consumed = initial_rounds - _rounds(world)
	return stats

func _stale_target_lock(world: SimulationWorld, event: BattleEvent) -> bool:
	var request: Dictionary = event.data.get("request", {})
	if request.get("kind") != BattleCommand.SET_TARGET or request.get("issuer_id") != "aircraft_tasks" or request.get("source") != "ai" or event.data.get("reason") != "invalid_enemy_target":
		return false
	var shooter: UnitState = world.get_unit(str(request.get("entity_id", "")))
	var target: UnitState = world.get_unit(str(request.get("payload", {}).get("target_id", "")))
	if shooter == null or target == null or target.active or shooter.faction_id == target.faction_id:
		return false
	if shooter.faction_id != request.get("faction_id") or shooter.active_order_id != shooter.faction_id + "_engage":
		return false
	# The target is gone in simulation, but its faction contact has yet to expire.
	return not CombatContacts.find(world, shooter.faction_id, target.id).is_empty()

func _rounds(world: SimulationWorld) -> int:
	var total: int = 0
	for id: String in world.unit_ids():
		for weapon: WeaponState in world.get_unit(id).weapons.values():
			for count: int in weapon.remaining_rounds:
				total += count
	return total

func _surface_boundary() -> void:
	var world: SimulationWorld = AircraftFixture.world([AircraftFixture.spawn("ditching","jp",Vector3(0,1,0),"jp_a6m5a_1944",0,70,{"fuel_kg":0})],true)
	world.get_unit("ditching").rotation_rad.x = -0.2
	world.get_unit("ditching").velocity_mps = Vector3(0,-12,-70)
	var events: Array[BattleEvent] = AircraftFixture.run(world,2)
	var contact: int = 0
	var impacts: int = 0
	for event: BattleEvent in events:
		if event.kind == "unit_surface_contact":
			contact += 1
			check(absf(event.position_m.y) < 0.00001, "actual sea intersection")
		if event.kind == "unit_impact":
			impacts += 1
		check(event.kind != "aircraft_exit", "ditching is not safe withdrawal")
	check(contact == 1 and impacts == 1, "single S05 impact from S04 contact")
	check(not world.get_unit("ditching").active and world.get_unit("ditching").module_data.damage.phase == "wreck", "S05 owns wreck")
