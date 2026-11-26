extends RefCounted

const NAMES: Dictionary = {"bank_turn":"大坡度转弯","climb_dive":"爬升与俯冲","axial_roll":"完整轴向滚转","roll_reversal":"反向滚转转弯","split_s":"半滚倒转"}
const PHASES: Dictionary = {"roll_in":"卸载滚入","pull_turn":"拉杆转弯","climb":"爬升","dive":"俯冲","roll":"持续滚转","roll_reverse":"反向滚入","pull_reverse":"反向拉杆","pull":"倒置拉杆","recover":"改出平飞","completed":"已完成","aborted":"已中止"}
const REASONS: Dictionary = {"training_received":"训练已接收","training_executor_capable":"具备训练能力","training_actual_geometry":"根据实际姿态与航迹执行","training_geometry_complete":"实际机动与改出已完成","training_fighter_only":"只支持两型战斗机","training_insufficient_start_agl":"起始离地高度不足","training_requires_level_entry":"需要安全平飞入场","training_split_s_envelope":"当前速度或高度不满足倒转包线","training_friendly_conflict":"友机间距不足，已中止","training_stall_margin":"失速余量不足","training_overspeed":"速度超出安全范围","training_low_altitude":"离地高度不足","training_low_fuel":"余油不足","training_power_lost":"动力损失，已交还安全飞控","training_control_lost":"操纵受损，已中止","training_damage":"实际受损，已中止","training_timeout":"未在安全时限内完成","training_recipient_inactive":"受令飞机已退出","sb2c_showcase_navigation_only":"SB2C当前只开放导航任务","training_unknown_maneuver":"训练类型无效","training_uses_explicit_parameters_only":"训练只能使用明确机动参数"}

static func name_of(kind: String) -> String: return str(NAMES.get(kind,"飞行训练"))
static func phase(code: String) -> String: return str(PHASES.get(code,"等待实际执行"))
static func reason(code: String) -> String:
	if REASONS.has(code): return REASONS[code]
	if REASONS.has(code.get_slice(":",0)): return REASONS[code.get_slice(":",0)]
	if code.begins_with("training_safety:"):
		var safety: Dictionary = {"stall_recovery":"失速改出","low_altitude_recovery":"低空改出","overspeed_recovery":"超速改出","energy_recovery":"能量恢复","terrain_recovery":"地形避让","glide":"无动力滑翔"}
		return "安全飞控接管 · "+str(safety.get(code.get_slice(":",1),"安全改出"))
	if code.begins_with("training_"): return "训练参数或安全条件不满足"
	return ""

static func view(units: Dictionary, orders: Array[Dictionary], subject: String, order_id: String) -> Dictionary:
	var result: Dictionary = {"order_id":order_id,"subject_id":subject,"status":"submitted","phase":"","label":"已提交 · 等待实际接收","training":{},"execution":{}}
	if order_id.is_empty() or not units.has(subject): return result
	var state: Dictionary = units[subject]
	var training: Dictionary = state.task.get("aircraft",{}).get("training",{})
	if training.get("order_id","") != order_id: training = state.module_data.get("aircraft_training",{})
	if training.get("order_id","") == order_id:
		result.training = training.duplicate(true)
		result.phase = str(training.get("phase",""))
	for order: Dictionary in orders:
		if order.order_id != order_id: continue
		var execution: Dictionary = order.get("execution",{}).get(subject,{})
		result.execution = execution.duplicate(true)
		result.status = str(execution.get("status",order.status))
		if result.status == "completed": result.status = "awaiting_confirmation"
		result["order_status"] = order.status
		if order.status in ["failed","cancelled","superseded"]:
			result.label = "已中止 · "+reason(str(execution.get("reason",order.reason)))
			if result.label == "已中止 · ": result.label = "指令已取消或被替代"
		elif execution.get("status","") == "completed" and training.get("order_id","") == order_id and training.get("status","") == "completed":
			result.status = "completed"
			result.label = "已完成 · "+name_of(str(training.maneuver))
		elif not result.training.is_empty():
			result.label = name_of(str(training.maneuver))+" · "+phase(str(training.phase))
		else: result.label = "已接收 · 等待实际机动"
		break
	return result
