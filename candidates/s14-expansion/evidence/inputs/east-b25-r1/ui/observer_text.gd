class_name ObserverText
extends RefCounted

const OPS: Script = preload("res://scripts/showcase/expansion/operations_labels.gd")

const TRAINING: Script = preload("res://scripts/showcase/training_labels.gd")

const TYPES: Dictionary = {"patrol":"区域巡逻", "escort":"护航警戒", "intercept":"拦截敌机", "engage":"集中接敌", "regroup":"重新集结", "retreat":"脱离撤退"}
const STATUSES: Dictionary = {"issued":"已下达", "received":"已接收", "executing":"执行中", "completed":"已完成", "failed":"失败", "cancelled":"已取消", "superseded":"已被替代", "rejected":"已拒绝"}
const PHASES: Dictionary = {"cruise":"巡航", "forming":"编队集合", "regroup":"重新集结", "guard":"护航警戒", "air_defence":"防空掩护", "approach":"接近目标", "deploy":"转向展开", "broadside":"舷侧交战", "search":"搜索目标", "withdraw":"正在脱离", "aim":"调整射向", "burst":"短点射", "evade":"规避威胁", "extend":"拉开距离", "return":"回到站位", "patrol":"巡逻", "support":"支援僚机", "assembled":"集结完成", "exited_combat_area":"已离开战区"}
const REASONS: Dictionary = {
	"following_route":"沿任务航路前进", "rejoining_station":"正在返回编队站位", "slow_member_reform":"等待慢速成员重组", "station_keeping":"保持编队站位", "core_protection":"保护核心舰", "air_defence_screen":"展开防空屏护", "close_to_gunnery_range":"接近有效炮战距离", "turning_to_broadside":"正在转向舷侧展开", "maintain_gunnery_range":"维持炮战距离", "last_known_contact":"向最后接触位置搜索", "awaiting_own_contact":"等待己方探测接触", "contact_not_reacquired":"搜索后未能重新接触", "protected_unit_lost":"保护对象已失能", "regroup_area_reached":"已经进入集结区", "withdrawal_area_reached":"已经进入撤离区", "search_no_contact":"尚无接触，组织搜索", "surface_contact":"发现水面接触", "protect_core":"保护核心舰", "air_defence_cover":"承担防空掩护", "intercept_air_threat":"拦截空中威胁", "reserve_air_cover":"保留空中掩护", "reform_after_contact_loss":"失联后重新集结", "flagship_replacement":"旗舰替换后重组", "severe_damage":"重伤，退出战斗", "low_fuel":"余油不足，正在撤离", "no_ammunition":"弹药耗尽", "force_depleted":"可战兵力不足", "flight_task_received":"飞行编队已接令", "ship_task_received":"舰队已接令", "short_burst_window":"进入有效短点射窗口", "align_fixed_guns":"调整机头与固定武器射向", "tail_threat":"规避机尾威胁", "separate_before_reengaging":"拉开距离后重新接敌", "ordered_retreat":"依令撤离", "outnumbered_low_energy":"低能量且敌众我寡", "unit_inactive":"成员已经退出战斗", "unit_lost":"成员失能", "new_order":"接受新任务", "reassigned":"成员接受改派", "superseded":"任务被新指令替代", "executor_accepted":"执行部队已接收", "assigned":"任务已分发", "dispatch":"任务已分发", "queued":"等待分发", "capable":"具备执行能力", "human_cancel":"人工取消任务", "ship_intercept_unsupported":"舰艇无法执行空中拦截", "unsupported_order_type":"暂不支持此任务", "unsupported_order_domain":"受令单位不具备此能力", "no_order_executor":"暂未接入此任务", "target_inactive":"目标已经退出战斗", "unknown_target":"目标无效", "missing_order":"任务不存在", "invalid_recipients":"受令对象无效", "foreign_recipient":"不能指挥其他阵营", "no_active_recipients":"没有可用的受令单位", "duplicate_id_conflict":"相同指令编号的内容冲突", "cancelled":"任务已取消", "neighbor_starboard":"避让邻舰", "neighbor_yield":"减速避让邻舰", "coast_detour":"绕行岸线", "coast_braking":"岸线前减速", "coast_unreachable":"目标航点不可通航，停止等待改派", "disabled_coasting":"失能后惯性滑行"}

static func time(seconds: float) -> String:
	return "%02d:%02d" % [int(seconds) / 60, int(seconds) % 60]

static func faction(id: String) -> String:
	return "日方指挥官" if id == "jp" else "美方指挥官"

static func reason(code: String, phase_code: String = "") -> String:
	if OPS.REASONS.has(code): return OPS.reason(code)
	if code.is_empty(): return "等待执行回报"
	var training_reason: String = TRAINING.reason(code)
	if not training_reason.is_empty(): return training_reason
	if code.begins_with("showcase_exercise_"): return "场景演示任务 · 使用统一指令入口"
	var ground: Dictionary = {"shore_sector_watch":"警戒港口水道","ground_air_defence":"保护港区空域","sector_watch":"守备区域，等待己方接触","tracking_contact":"根据己方接触追踪目标","arc":"目标超出阵地射界","terrain_masked":"山体或建筑阻断火线","masked":"炮架或宿主阻断火线","out_of_range":"目标超出有限射程","traversing":"炮组正在转向瞄准","reloading":"炮组装填中","fired":"炮组正在射击","hold_fire":"已停火","ground_incompatible_target":"该炮组无法攻击此目标域","ground_executor_capable":"炮组已接收任务"}
	if ground.has(code):return ground[code]
	if code == "propulsion_unavailable": return "动力失效，无法驶向撤离区"
	if code == "fuel_exhausted": return "燃料耗尽，无法继续航行"
	var extra: Dictionary = {"low_fuel":"余油不足，正在撤离", "wingman_station":"僚机保持掩护站位", "rejoining_pair":"正在重新加入双机编队", "escort_protection_area":"在保护区域警戒", "support_pair_station":"支援双机保持站位", "gathering_surviving_members":"正在集合存活成员", "replacement_order_received":"已接收替代任务", "recipient_inactive":"成员已失去执行能力", "all_recipients_inactive":"受令成员已退出战斗", "order_received":"任务已接收", "order_started":"开始执行任务", "human_cancelled":"人工取消任务", "unknown_order":"任务不存在", "unsupported_order":"暂不支持此任务", "invalid_order_type":"此类任务尚未接入", "unknown_recipient":"受令对象不存在", "recipient_inactive_at_dispatch":"分发时受令对象已退出", "domain_executors_accepted":"部队已接令", "validated":"指令已下达"}
	if extra.has(code): return extra[code]
	if REASONS.has(code): return REASONS[code]
	if code.begins_with("withdrawn:"): return "已撤出战区 · " + reason(code.trim_prefix("withdrawn:"))
	if code.begins_with("all_assignments_released:"): return reason(code.trim_prefix("all_assignments_released:"))
	if code.begins_with("superseded_by:"): return "已被后续任务替代"
	return phase(phase_code) if not phase_code.is_empty() else "等待进一步执行回报"

static func phase(code: String) -> String:
	if OPS.PHASES.has(code) and not PHASES.has(code): return OPS.phase(code)
	if code == "training": return "飞行训练"
	var ground: Dictionary = {"shore_watch":"海峡警戒","area_air_defence":"区域防空","ground_engage":"炮组交战","ground_blocked":"炮组受限"}
	if ground.has(code):return ground[code]
	if code == "blocked": return "航行受阻"
	if code == "cover": return "僚机掩护"
	if code == "formation": return "保持编队"
	return PHASES.get(code, "正在执行任务")

static func recipients(order: Dictionary, names: Dictionary) -> String:
	var labels: PackedStringArray = []
	for id: String in order.get("recipient_ids", []): labels.append(names.get(id, "作战编组"))
	return "、".join(labels)

static func order_title(order: Dictionary, names: Dictionary) -> String:
	var target: String = names.get(order.get("target_id", ""), "")
	var source_tag: String = "[演示任务] " if order.get("issuer_id", "") == "s14_exercise_director" else ""
	var kind: String = TRAINING.name_of(str(order.get("training",{}).get("maneuver",""))) if order.get("order_type","") == "aircraft_training" else str(TYPES.get(order.get("order_type", ""), "战术任务"))
	return source_tag + recipients(order, names) + " → " + kind + (" · " + target if not target.is_empty() else "")

static func execution(order: Dictionary, names: Dictionary) -> String:
	var groups: Dictionary = {}
	for id: String in order.get("execution", {}):
		var member: Dictionary = order.execution[id]
		var summary: String = STATUSES.get(member.status, "等待回报") + " · " + reason(member.get("reason", ""), str(member.get("progress", "")).get_slice(":", 0))
		if not str(member.get("replacement_order_id", "")).is_empty(): summary += "（已另受新令）"
		if not groups.has(summary): groups[summary] = []
		groups[summary].append(names.get(id, "编组成员"))
	var lines: PackedStringArray = []
	for summary: String in groups:
		lines.append("、".join(groups[summary]) + "：" + summary)
	return "\n".join(lines)

static func timeline(entry: Dictionary, names: Dictionary) -> String:
	var order: Dictionary = entry.record
	if entry.kind == "command_rejected":
		var request: Dictionary = order.get("request", {}).get("payload", {})
		return time(entry.time_s) + "  " + faction(order.get("faction_id", "jp")) + " → " + order_title(request, names) + "\n指令被拒绝 · " + reason(order.get("reason", ""))
	var origin: String = "（演示任务）" if order.get("issuer_id", "") == "s14_exercise_director" else ("（人工）" if order.get("source", "ai") == "human" else "")
	var title: String = time(entry.time_s) + "  " + faction(order.get("faction_id", "jp")) + origin + " → " + order_title(order, names)
	if entry.kind == "order_execution_changed":
		var member: Dictionary = order.get("execution", {}).get(entry.entity_id, {})
		return title + "\n" + names.get(entry.entity_id, "编组成员") + "：" + STATUSES.get(member.get("status", ""), "执行中") + " · " + reason(member.get("reason", ""))
	if entry.kind == "order_assignments_changed":
		return title + "\n成员调整 · " + execution(order, names)
	return title + "\n" + STATUSES.get(order.get("status", ""), "已下达") + " · " + reason(order.get("intent", "") if entry.kind == "order_issued" else order.get("reason", ""))

static func maneuver(task: Dictionary, motion: Dictionary) -> String:
	if task.has("training"):
		var training: Dictionary = task.training
		return TRAINING.name_of(str(training.maneuver))+" · "+TRAINING.phase(str(training.phase))+" · 滚转 %.0f° / 高度变化 %+.0f 米" % [rad_to_deg(float(training.peak_roll_rad)),float(training.height_change_m)]
	var phases: Dictionary = {"climb_setup":"占据高位","dive_attack":"俯冲攻击","high_yoyo":"高位修正","low_yoyo":"低位增速","zoom_climb":"拉升脱离","diving_break":"俯冲规避","oblique_extend":"斜向脱离","high_cover":"高位掩护","vertical_rejoin":"立体归队","recover":"安全改出","track":"追踪瞄准"}
	var safety: Dictionary = {"normal":"正常飞行","stall_recovery":"失速改出","low_altitude_recovery":"低空改出","overspeed_recovery":"超速改出","glide":"失去动力滑翔"}
	var why: Dictionary = {"lead_solution":"按接触提前量追踪","tail_contact_energy":"尾后受威胁，利用动能","tail_contact_clearance":"尾后受威胁，争取间隔","pass_separation":"交错后拉开间隔","excess_closure":"闭合过快，修正攻击线","target_pulling_away":"目标远离，转换能量","height_advantage":"利用高度优势","convert_speed_to_highside":"将速度换成高位","energy_margin":"恢复可用能量"}
	var why_code: String = str(task.get("maneuver_reason",""))
	var line: String = phases.get(task.get("maneuver_phase",""),"保持任务飞行")+" · "+safety.get(motion.get("safety_state","normal"),"安全状态待回报")
	if why.has(why_code): line += "（"+str(why[why_code])+"）"
	if motion.has("height_agl_m"): line += " · 离地 %.0f 米" % float(motion.height_agl_m)
	return line
