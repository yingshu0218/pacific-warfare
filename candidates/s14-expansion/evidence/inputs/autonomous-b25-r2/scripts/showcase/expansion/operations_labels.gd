extends RefCounted

const PHASES: Dictionary = {"standby":"甲板停放","preparing":"出动准备","queued":"等待放飞","respotting":"甲板调位","taxi_out":"滑行至起飞位","takeoff_roll":"甲板滑跑","climb":"离舰爬升与集合","mission":"空中巡逻任务","return":"返航","holding":"回收排队","approach":"末段进近","touchdown":"实际触舰","arresting":"挂索减速","taxi_clear":"滑行清场","servicing":"有限油弹整备","deck_hold":"甲板等待／受限","go_around":"复飞","diverted":"已脱离舰载作业","lost":"飞机损失"}
const REASONS: Dictionary = {
	"carrier_complete_wave_required":"此甲板只支持整波出动；留机将阻挡回收，已拒绝单机出动",
	"carrier_base_mismatch":"指令母舰与本机所属母舰不符","deck_aircraft_requires_sortie_or_recall":"甲板飞机须接收整波巡逻或召回指令",
	"parked_inventory":"在真实甲板待命","sortie_order_received":"已接收完整波次指令","awaiting_clear_launch_deck":"等待起飞甲板可用",
	"exclusive_launch_clearance":"已获独占起飞许可","awaiting_continuous_deck_respot":"等待连续甲板调位","launch_deck_or_queue_occupied":"起飞区或队列被占用",
	"climb_and_assembly_complete":"真实爬升和集合完成","low_fuel_return":"低油返航",
	"on_station_duration_complete":"已达指令巡逻期限",
	"patrol_complete_return":"巡逻阶段完成，申请回收","recall_order_received":"收到召回指令",
	"recall_already_aboard":"飞机已在母舰甲板","airborne_retask_received":"已接收新的空中任务","carrier_lost_support_released":"母舰失效，已解除甲板支承",
	"unfit_aircraft_remains_physically_parked":"飞机受损，仍实际停留并占用甲板","terminal_damage_owns_motion":"终端损伤已接管运动",
	"ops_released_flight_continues":"退出舰载流程，继续原飞行","aircraft_unfit_for_carrier_operation":"飞机真实状态不满足舰载作业",
	"base_available_again":"母舰条件恢复，重新准备","carrier_unavailable":"母舰不可用","wreck_on_flight_deck":"真实残骸占据甲板",
	"flight_deck_disabled":"飞行甲板失效","carrier_turning":"母舰转弯超出作业包线","carrier_attitude_outside_envelope":"母舰倾斜超出作业包线",
	"nonzero_air_wind_not_supported_stage1":"首阶段仅支持零环境风","insufficient_wind_over_deck":"甲板相对风速不足","crosswind_outside_envelope":"侧风超出作业包线",
	"elevator_not_at_flight_deck":"升降机不在飞行甲板高度","cancelled_sortie_recover":"出动已取消，安排回收","released_aircraft_reached_terminal_damage":"退出作业后的飞机已进入终端损伤"
	,"actual_hook_shoe_swept_wire_segment":"实际钩鞋扫过三维阻拦索并挂索","airspeed_and_deck_run_complete":"真实空速与滑跑长度满足，已离舰",
	"approach_clearance_invalid":"进近许可失效，执行复飞","approach_deck_occupied":"进近甲板被占用，执行复飞","arrest_complete_clear_landing_area":"挂索减速完成，滑行清空着舰区",
	"awaiting_recovery_deck":"等待回收队列和甲板许可","bolter_airborne_real_velocity":"未挂索，按真实速度重新离舰",
	"deck_handling_force_clears_forward_parking":"甲板调位，清空前部停放区域","deck_respot_physically_complete":"实际调位完成",
	"exclusive_recovery_clearance":"已获独占回收许可","go_around_rejoin_queue":"复飞后重新排队","landing_deck_occupied":"着舰区被占用",
	"outside_touchdown_zone":"实际触舰点超出着舰区","physical_deck_contact_damage_handoff":"实际接触损伤已交原损伤模块",
	"recovered_and_parked":"已实际回收停放，开始有限整备","roll_length_and_wind_cleared":"滑跑距离和甲板风条件通过",
	"service_complete":"有限油弹整备完成","sortie_recovered_and_serviced":"本波已实际回收并完成有限整备",
	"touchdown_attitude_outside_envelope":"触舰姿态超出包线","touchdown_footprint_unsupported":"实际轮组或机体包络无甲板支承",
	"touchdown_sink_outside_envelope":"下沉率超出触舰包线","touchdown_speed_outside_envelope":"触舰速度超出包线",
	"uncontrolled_deck_contact":"失控机体真实接触甲板","wheel_support_lost_at_actual_deck_edge":"轮胎已越过实际甲板边缘"
}

static func phase(code: String) -> String: return str(PHASES.get(code,"正在执行舰载作业"))
static func reason(code: String) -> String:
	if REASONS.has(code): return str(REASONS[code])
	var words: Dictionary = {"queue":"等待回收队列","occupied":"甲板占用，等待或复飞","clearance":"等待甲板许可","fuel":"油料条件限制","ammo":"弹药库存限制","service":"实际有限油弹整备","arrest":"真实尾钩挂索","wire":"阻拦索接触","touch":"真实轮组触舰","launch":"真实离舰条件","takeoff":"实际滑跑与离舰","respot":"连续甲板调位","parking":"等待可用停放位","deck":"甲板条件受限","approach":"按真实状态进近","recover":"回收条件与实际航迹","damage":"飞机受损，作业受限","collision":"真实几何接触，作业中断","cancel":"指令取消，按实际状态释放","terrain":"地形净空受限"}
	for word: String in words:
		if code.contains(word): return str(words[word])
	return "按实际作业状态执行"
