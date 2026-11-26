extends RefCounted

const PHASES: Dictionary = {"awaiting_contact":"等待己方敌情","inbound":"接近攻击区域","roll_in":"滚入俯冲","dive":"实际俯冲","stabilize":"稳定投弹航段","salvo":"有限弹列投放","pullout":"拉起脱离","egress":"脱离攻击航线","regroup":"编队返航重组","return":"返回撤离空域","released":"任务控制已释放","crashing":"受损失控坠落","wreck":"实际残骸"}
const REASONS: Dictionary = {"awaiting_contact":"等待有效己方接触","attack_entry_reached":"进入攻击航段","rolling_entry_attitude_reached":"俯冲姿态成立","finite_bomb_train":"按有限间隔投弹","load_released":"载荷实际离架","positive_climb_established":"已建立正爬升","clear_of_attack_run":"已飞离攻击航线","formation_on_return_heading":"编队已转返航航向","airborne_return_area_reached":"已到撤离空域","damage_abort":"受损中止攻击","combat_damage_abort":"严重战损中止攻击","target_lost":"目标接触丢失","too_low":"高度不足，停止投放","empty_load":"载荷已空","fuel_reserve":"燃油接近储备量","overspeed_abort":"速度超出投放限制","missed_release_window":"错过投放窗口","target_passed":"已飞过目标","attack_timeout":"攻击未在任务限期内建立","order_released":"任务已取消或改派"}
static func phase(value: String) -> String: return str(PHASES.get(value,value))
static func reason(value: String) -> String:
	if value.begins_with("flight_safety:"): return "飞行安全限制，中止攻击"
	return str(REASONS.get(value,value))
