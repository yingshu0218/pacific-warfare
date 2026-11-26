extends SceneTree

## Controlled reporting-only cases. These events never enter the formal battle or its captures.
func _initialize() -> void:
	var session: FirstPlayableSession = FirstPlayableSession.new()
	assert(session.load_battle().is_empty())
	var events: Array[BattleEvent] = []
	var cases: Array = [["damage_phase", "jp_bb", {"phase":"sinking"}], ["damage_phase", "jp_dd", {"phase":"disabled"}], ["unit_impact", "jp_air_1", {"destroyed":false}], ["unit_impact", "jp_air_2", {"destroyed":true}], ["aircraft_exit", "jp_air_3", {"destroyed":false}], ["ship_exit", "us_dd", {"destroyed":false, "sunk":false}]]
	for index: int in range(cases.size()):
		var event: BattleEvent = BattleEvent.new()
		event.sequence = index + 1
		event.kind = cases[index][0]
		event.entity_id = cases[index][1]
		event.data = cases[index][2]
		events.append(event)
	session.consume(events)
	var report: Dictionary = session.report()
	assert(report.jp.sunk == 1 and report.jp.disabled == 1 and report.jp.ditched == 1 and report.jp.crashed == 1 and report.jp.withdrawn == 1)
	assert(report.us.withdrawn == 1 and report.us.sunk == 0)
	assert(session.units.jp_bb.module_data.damage.structure > 0, "flooding sink is not inferred from structure")
	session.consume(events)
	assert(session.report() == report, "repeated presentation events are not counted twice")
	assert(session.restart())
	assert(session.outcomes.is_empty())
	print("S07 reporting cases: PASS")
	quit(0)
