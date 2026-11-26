extends SceneTree

const SCENARIO: String = "res://data/scenarios/qj01_qingjia.json"
const WAVE: String = "qj01:wave:01"
const FIRST: String = "us_deck_1"
const SECOND: String = "us_deck_2"
const CARRIER: String = "us_cv"

class Inputs extends SimulationModule:
	var action: Callable

	func _init() -> void:
		module_id = "qingjia_test_inputs"
		priority = 899

	func fixed_update(world_ref: RefCounted, _dt: float) -> void:
		if action.is_valid(): action.call(world_ref)

var session: FirstPlayableSession
var inputs: Inputs
var checks: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("run")

func check(passed: bool, label: String) -> void:
	checks.append({"label":label, "passed":passed})
	if not passed: push_error("QJ01: " + label)

func run() -> void:
	session = FirstPlayableSession.new()
	var errors: PackedStringArray = session.load_battle(SCENARIO)
	if not errors.is_empty():
		push_error(str(errors))
		quit(1)
		return
	inputs = Inputs.new()
	check(session.world.register_module(inputs).accepted, "controlled inputs run after damage and immediately before the mission")
	_test_duplicate_unknown()
	_test_no_qualifying_recovery()
	_test_later_sortie_and_other_host()
	_test_boundary()
	_test_manual_and_reset()
	print(JSON.stringify({"checks":checks}))
	quit(0 if checks.all(func(row: Dictionary) -> bool: return row.passed) else 1)

func _restart(callback: Callable, deadline: int = 12) -> void:
	inputs.action = callback
	session.qingjia_mission.window_s = float(deadline) * session.world.fixed_delta_s()
	check(session.restart(), "scenario reset")

func _tick() -> void:
	session.advance(session.world.fixed_delta_s())

func _report() -> Dictionary:
	return session.qingjia_mission.report(session.world)

func _arrival(world: SimulationWorld) -> void:
	world.get_unit(CARRIER).position_m = session.qingjia_mission.exit_center_m - Vector3(session.qingjia_mission.exit_radius_m, 0, 0)

func _operation(world: SimulationWorld, id: String, launch: bool, serial: int = 1, wave: String = WAVE, host: String = CARRIER) -> void:
	var unit: UnitState = world.get_unit(id)
	unit.module_data["carrier_ops"].merge({"carrier_id":host, "sortie_order_id":wave, "sorties":serial, "on_deck":not launch,
		"phase":"climb" if launch else "servicing"}, true)
	world.emit_event("carrier_operation_phase", id, "", unit.position_m,
		{"reason":"airspeed_and_deck_run_complete" if launch else "recovered_and_parked", "sortie_order_id":wave,
			"sortie_serial":serial, "order_id":wave if launch else "valid_recall_order_for_same_sortie"}, host)

func _test_duplicate_unknown() -> void:
	_restart(func(world: SimulationWorld) -> void:
		if world.tick == 1:
			_operation(world, FIRST, true)
			_operation(world, SECOND, true)
		elif world.tick == 2:
			_operation(world, FIRST, false)
			world.get_unit(SECOND).active = false
		elif world.tick == 4:
			_operation(world, FIRST, false)
			_arrival(world))
	_tick()
	check(_report().status == "pending" and session.ended_reason.is_empty() and not session.world.order_snapshot("qj01:withdraw", "us").is_empty(), "accepted ship withdrawal order is not arrival")
	session.advance(10.0, 200)
	var report: Dictionary = _report()
	check(report.status == "partial" and report.withdrawn_count == 1 and session.world.tick == 4, "first actual zone entry pauses the current multi-step frame at 1 of 2")
	check(report.airframes[0].recovery_tick == 2, "duplicate recovery retains the first real tick and never adds a second aircraft")
	check(report.airframes[1].status == "unknown" and report.airframes[1].last_known == "airborne" and report.airframes[1].last_known_tick == 1, "unobserved disappearance preserves last known airborne tick, not a presumed loss")
	var frozen: Dictionary = report.duplicate(true)
	report.airframes[0].recovery_tick = -1
	session.finish()
	check(_report() == frozen and session.ended_reason == "qingjia", "report copies are independent and finish does not overwrite completed outcome")

func _test_no_qualifying_recovery() -> void:
	_restart(func(world: SimulationWorld) -> void:
		if world.tick == 2:
			var outsider: UnitState = world.get_unit("jp_air_1")
			world.emit_event("carrier_operation_phase", outsider.id, "", outsider.position_m,
				{"reason":"recovered_and_parked", "sortie_order_id":WAVE, "sortie_serial":1}, CARRIER)
			world.emit_event("carrier_operation_phase", FIRST, "", outsider.position_m,
				{"reason":"recovered_and_parked", "sortie_order_id":WAVE, "sortie_serial":1}, CARRIER)
			_arrival(world))
	session.advance(1.0)
	var report: Dictionary = _report()
	check(report.status == "partial" and report.withdrawn_count == 0 and report.airframes[0].status == "initial_deck", "deck spawns, no-launch and outsider reports never count")

func _test_later_sortie_and_other_host() -> void:
	_restart(func(world: SimulationWorld) -> void:
		if world.tick == 1:
			_operation(world, FIRST, true)
			_operation(world, SECOND, true)
		elif world.tick == 2:
			_operation(world, FIRST, false)
			_operation(world, SECOND, false)
		elif world.tick == 3:
			_operation(world, FIRST, true, 2, "other_sortie")
		elif world.tick == 4:
			_operation(world, FIRST, false, 2, "other_sortie")
			_operation(world, SECOND, false, 1, WAVE, "jp_cv")
			_arrival(world))
	session.advance(1.0)
	var report: Dictionary = _report()
	check(report.withdrawn_count == 0 and report.airframes[0].recovery_tick == 2 and report.airframes[0].status == "deck_without_qualifying_recovery", "a later sortie cannot inherit the earlier recovery even when back aboard")
	check(report.airframes[1].recovery_tick == 2 and report.airframes[1].status == "other_carrier" and report.airframes[1].carrier_id == "jp_cv", "recovery history does not transfer to another carrier")
	_restart(func(world: SimulationWorld) -> void:
		if world.tick == 1: _operation(world, FIRST, true)
		elif world.tick == 2: _operation(world, FIRST, false)
		elif world.tick == 3:
			_operation(world, FIRST, true, 2, "other_sortie")
			_arrival(world))
	session.advance(1.0)
	report = _report()
	check(report.withdrawn_count == 0 and report.airframes[0].status == "airborne" and report.airframes[0].recovery_tick == 2, "relaunched airframe is still in flight at exit")

func _test_boundary() -> void:
	_restart(func(world: SimulationWorld) -> void:
		if world.tick == 1:
			_operation(world, FIRST, true)
			_operation(world, SECOND, true)
		elif world.tick == 2: _operation(world, FIRST, false)
		elif world.tick == 3:
			_operation(world, FIRST, false)
			_operation(world, SECOND, false)
			_arrival(world), 3)
	session.advance(1.0)
	var report: Dictionary = _report()
	check(report.status == "complete" and report.tick == report.deadline_tick and report.withdrawn_count == 2 and report.airframes[1].recovery_tick == 3, "same-step real recovery and boundary arrival take precedence over inclusive deadline")
	_restart(func(world: SimulationWorld) -> void:
		if world.tick == 4: _arrival(world), 3)
	session.advance(1.0)
	report = _report()
	check(report.status == "failed" and report.reason == "deadline" and session.world.tick == 3, "deadline expires at its exact tick; one-step-late arrival cannot advance or replace it")
	_restart(func(world: SimulationWorld) -> void:
		if world.tick == 3:
			_arrival(world)
			var carrier: UnitState = world.get_unit(CARRIER)
			carrier.active = false
			carrier.module_data.damage.phase = "sinking" , 3)
	session.advance(1.0)
	report = _report()
	check(report.status == "failed" and report.reason == "carrier_lost" and report.carrier_phase == "sinking", "same-step sinking outranks arrival and deadline")

func _test_manual_and_reset() -> void:
	_restart(func(world: SimulationWorld) -> void:
		if world.tick == 1: _operation(world, FIRST, true)
		elif world.tick == 2:
			_operation(world, FIRST, false)
			world.get_unit(SECOND).active = false
			world.emit_event("unit_impact", SECOND, "", Vector3.ZERO, {"destroyed":false}))
	_tick()
	_tick()
	session.finish()
	var report: Dictionary = _report()
	check(report.status == "interrupted" and report.reason == "manual" and report.tick == 2 and report.withdrawn_count == 0 and report.aboard_count == 1 and report.airframes[1].status == "ditched", "manual end freezes real current status without declaring successful withdrawal or a loss for confirmed ditching")
	_restart(Callable())
	report = _report()
	check(report.status == "pending" and report.tick == 0 and report.aboard_count == 0 and report.airframes[0].recovery_tick == -1 and report.airframes[0].launch_tick == -1 and report.airframes[1].status == "initial_deck" and not session.world.paused, "restart resets report, identities' sortie evidence and clock")
