extends SceneTree

const SCENARIO: String = "res://data/scenarios/qj01_qingjia.json"

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var session: FirstPlayableSession = FirstPlayableSession.new()
	var errors: PackedStringArray = session.load_battle(SCENARIO)
	if not errors.is_empty():
		push_error(str(errors))
		quit(1)
		return
	var events_kept: Array[Dictionary] = []
	while session.ended_reason.is_empty():
		var events: Array[BattleEvent] = session.advance(1.0, 60)
		for event: BattleEvent in events:
			if event.kind == "carrier_operation_phase" or event.kind in ["carrier_touchdown", "carrier_wire_caught", "aircraft_exit"]:
				if event.kind == "carrier_operation_phase" and not event.data.has("sortie_serial") and event.data.get("from") == event.data.get("phase"): continue
				events_kept.append({"kind":event.kind, "entity_id":event.entity_id, "target_id":event.target_id,
					"tick":event.tick, "time_s":event.time_s, "phase":event.data.get("phase", ""),
					"reason":event.data.get("reason", ""), "sortie_serial":event.data.get("sortie_serial", 0),
					"sortie_order_id":event.data.get("sortie_order_id", "")})
		if session.world.tick > session.qingjia_mission.deadline_tick or (session.world.paused and session.ended_reason.is_empty()): break
	var report: Dictionary = session.qingjia_mission.report(session.world)
	var wave: Dictionary = session.world.order_snapshot(report.wave_order_id, "us")
	var retreat: Dictionary = session.world.order_snapshot(report.withdraw_order_id, "us")
	var receipts: Array[Dictionary] = []
	for order: Dictionary in [wave, retreat]:
		receipts.append({"order_id":order.get("order_id", ""), "issuer_id":order.get("issuer_id", ""),
			"received_tick":order.get("received_tick", -1), "recipients":order.get("recipient_ids", []), "status":order.get("status", "")})
	var record: Dictionary = {"scenario":SCENARIO, "method":"FirstPlayableSession.load_battle; natural advance; no view or fixture",
		"engine":Engine.get_version_info().string, "seed":session.world.seed_value, "terminal_tick":session.world.tick,
		"report":report, "order_receipts":receipts, "counts":session.counts, "events":events_kept}
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var passed: bool = session.ended_reason == "qingjia" and report.tick == session.world.tick and session.world.paused
	passed = passed and int(wave.get("received_tick", -1)) > 0 and int(retreat.get("received_tick", -1)) > 0
	if args.size() > 1: passed = passed and report.status == args[1]
	if report.reason == "exit_reached":
		var position: Array = report.carrier_position_m
		var center: Array = report.exit_center_m
		passed = passed and Vector2(position[0] - center[0], position[2] - center[2]).length() <= report.exit_radius_m
		passed = passed and report.tick <= report.deadline_tick
	for row: Dictionary in report.airframes:
		passed = passed and _matches_event(events_kept, report, row, "launch_tick", "airspeed_and_deck_run_complete")
		passed = passed and _matches_event(events_kept, report, row, "recovery_tick", "recovered_and_parked")
	print(JSON.stringify({"report":report, "counts":session.counts, "passed":passed}))
	if not passed:
		push_error("QJ01 natural run did not meet the requested outcome or its evidence does not match")
		quit(1)
		return
	if not args.is_empty():
		var stream: FileAccess = FileAccess.open(args[0], FileAccess.WRITE)
		if stream == null:
			push_error("Cannot write QJ01 natural sample: " + str(FileAccess.get_open_error()))
			quit(1)
			return
		stream.store_string(JSON.stringify(record, "  ") + "\n")
	quit()

func _matches_event(events: Array[Dictionary], report: Dictionary, row: Dictionary, tick_key: String, reason: String) -> bool:
	if int(row[tick_key]) < 0: return true
	for event: Dictionary in events:
		if event.tick == row[tick_key] and event.entity_id == row.unit_id and event.target_id == report.carrier_id \
			and event.reason == reason and event.sortie_order_id == report.wave_order_id and event.sortie_serial == row.sortie_serial:
			return true
	return false
