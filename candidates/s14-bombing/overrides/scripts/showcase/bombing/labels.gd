extends RefCounted

const PHASES: Dictionary = {"awaiting_contact":"等待己方敌情","inbound":"接近攻击区域","roll_in":"滚入俯冲","dive":"实际俯冲","stabilize":"稳定投弹航段","salvo":"有限弹列投放","pullout":"拉起脱离","egress":"脱离攻击航线","regroup":"编队返航重组","return":"返回撤离空域","released":"任务控制已释放","crashing":"受损失控坠落","wreck":"实际残骸","removed":"残骸已清除"}
const REASONS: Dictionary = {"awaiting_contact":"等待有效己方接触","forming_attack_route":"组织攻击航线","bombing_executor_capable":"轰炸编组已接令","Attack assigned area":"攻击指定任务目标","roll_entry_not_established":"未能建立俯冲进入姿态","bombing_requires_own_surface_contact":"缺少己方有效水面接触","bombing_mode_required":"缺少轰炸类型","recover_survivors_after_interruption":"任务中断，召回幸存飞机","flight_operations_course":"维持航空作业航向","carrier_patrol_with_visible_duration":"执行有明确期限的舰载巡逻","attack_entry_reached":"进入攻击航段","rolling_entry_attitude_reached":"俯冲姿态成立","finite_bomb_train":"按有限间隔投弹","load_released":"载荷实际离架","positive_climb_established":"已建立正爬升","clear_of_attack_run":"已飞离攻击航线","formation_on_return_heading":"编队已转返航航向","airborne_return_area_reached":"已到撤离空域","damage_abort":"受损中止攻击","combat_damage_abort":"严重战损中止攻击","target_lost":"目标接触丢失","too_low":"高度不足，停止投放","empty_load":"载荷已空","fuel_reserve":"燃油接近储备量","overspeed_abort":"速度超出投放限制","missed_release_window":"错过投放窗口","target_passed":"已飞过目标","attack_timeout":"攻击未在任务限期内建立","order_released":"任务已取消或改派"}
static func phase(value: String) -> String: return str(PHASES.get(value,value))
static func reason(value: String) -> String:
	if value.is_empty(): return "等待实际执行回报"
	if value.begins_with("flight_safety:"): return "飞行安全限制，中止攻击"
	if value.begins_with("all_assignments_released:"): return "全部受令单位已释放 · "+reason(value.trim_prefix("all_assignments_released:"))
	return str(REASONS.get(value,{"recipient_inactive":"受令单位已退出任务","replacement_order_received":"已接收替代任务","order_cancelled":"任务已取消","order_superseded":"任务已改派","domain_executors_accepted":"任务执行器已接令","flight_task_received":"飞行编组已接令"}.get(value,"其他执行原因")))
