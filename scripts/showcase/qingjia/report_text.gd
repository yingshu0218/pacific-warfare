extends RefCounted

const AIRFRAME_STATES: Dictionary = {
	"initial_deck":"在埃塞克斯甲板，尚未起飞", "airborne":"仍在空中", "return":"正在返航",
	"holding":"空中等待甲板", "approach":"进近中", "go_around":"复飞中", "diverted":"退出舰载作业，未确认改降",
	"recovered_aboard":"仍在埃塞克斯甲板", "deck_without_qualifying_recovery":"在甲板，不计入本次回收",
	"other_carrier":"在其他母舰", "withdrawn":"已离开战区", "crashing":"失控坠落中，未确认落点",
	"ditched":"已确认迫降", "lost":"已确认损失", "unknown":"去向未明"
}

static func summary(report: Dictionary) -> String:
	return {
		"":"任务进行中 · 尚未结算", "exit_reached":"%s · %d/2 架随舰撤出" % ["任务完成" if report.status == "complete" else "部分达成", report.withdrawn_count],
		"carrier_lost":"未达成 · 埃塞克斯%s" % ("进入不可逆沉没阶段" if report.carrier_phase == "sinking" else "已沉没"),
		"deadline":"未达成 · 窗口届满，埃塞克斯未到区", "manual":"任务中断 · 观众手动结束，未判胜负"
	}.get(report.reason, "")

static func rows(report: Dictionary, names: Dictionary) -> PackedStringArray:
	var lines: PackedStringArray = []
	for row: Dictionary in report.airframes:
		var details: PackedStringArray = []
		if row.launch_tick >= 0: details.append("起飞 " + _time(row.launch_tick, report))
		if row.recovery_tick >= 0: details.append("回收 " + _time(row.recovery_tick, report))
		var status: String = str(AIRFRAME_STATES.get(row.status, row.status))
		if row.withdrew: status = "已随舰撤出"
		if row.status == "other_carrier" and names.has(row.carrier_id): status += "（%s）" % names[row.carrier_id]
		if row.status == "unknown": status += "（最后可知 %s：%s）" % [_time(row.last_known_tick, report), AIRFRAME_STATES.get(row.last_known, row.last_known)]
		details.append(status)
		lines.append("%s：%s" % [names.get(row.unit_id, row.unit_id), " · ".join(details)])
	return lines

static func report_body(report: Dictionary, names: Dictionary) -> String:
	var carrier: String = str(names.get(report.carrier_id, report.carrier_id))
	var condition: String = {"operational":"可战", "disabled":"失能、仍漂浮", "sinking":"沉没中", "wreck":"已沉没", "removed":"已沉没"}.get(report.carrier_phase, report.carrier_phase)
	var lines: PackedStringArray = [summary(report), "截至 %s / 窗口 %s" % [_time(report.tick, report), _time(report.deadline_tick, report)],
		"%s · %s · 已回收且仍在舰 %d/2" % [carrier, condition, report.aboard_count], _exit_status(report)]
	lines.append_array(rows(report, names))
	return "\n".join(lines)

static func brief(report: Dictionary, subtitle: String) -> String:
	return "%s\n窗口 %s · %s · 已回收且仍在舰 %d/2 · 点「战报」查双机" % [subtitle, _time(report.deadline_tick, report), _exit_status(report), report.aboard_count]

static func _exit_status(report: Dictionary) -> String:
	if report.reason == "exit_reached": return "东侧外海撤离区：已到区"
	var center: Array = report.exit_center_m
	var position: Array = report.carrier_position_m
	var distance_m: float = Vector2(position[0] - center[0], position[2] - center[2]).length() - float(report.exit_radius_m)
	if distance_m <= 0.0: return "东侧外海撤离区：舰位在区内"
	if distance_m < 10.0: return "东侧外海撤离区：距边缘不足 10 米"
	return "东侧外海撤离区：距边缘 %.2f 公里" % (distance_m / 1000.0)

static func _time(tick: int, report: Dictionary) -> String:
	return ObserverText.time(float(tick) / float(report.tick_hz))
