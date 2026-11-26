# S06 舰队与指挥接入契约 v1

2026-11-10，先发布接入约定；验证状态以 `docs/showcase/deliveries/S06.md` 为准。S01/S04/S05 的公共语义不变。米、秒、弧度、-Z 舰艏。

## 安装与所有权

`FleetConfig.load_file("res://data/fleet/showcase.json")` 后，在已 configure 世界首 tick 前调用 `FleetSuite.install(world, config, enable_commanders=true)`。返回错误数组；测试可关闭程序指挥官，仅用人类或测试来源的 BattleOrder。仍须分别安装正式 `AircraftSuite`、`CombatSuite`。

固定顺序：S05探测100 → `fleet_commander`200 → `fleet_tasks`310 → `ship_motion`410 → S05火控450。指挥官只调用 `commander_snapshot(faction_id)` 和 `submit_order`；纯规则规划器不持有世界引用。航空命令直接交 S04，不另建编队。

S06只写 `ship_control`、`ship_motion`、`fleet_formation`、`unit.task.ship` 和船只的 `combat_intent`，目标经 SET_TARGET。`damage`/炮位/库存/弹丸由S05维护。disabled舰不执行任务但有界滑行；sinking/wreck/removed由S05移动，S06不积分。舰艇没有鱼雷行为。

## 高层命令与终态

| 类型 | 舰艇执行 |
| --- | --- |
| patrol | 区域或航点巡航；旗舰领航、其余实际航行入站，慢舰触发减速重组；持续至改派/取消/损失 |
| escort | 友方核心舰保护；`intent=air_defence_cover` 时报告防空掩护；不追出保护圈，允许职责内防空和自卫对海射击 |
| engage | 仅对海目标；据己方新鲜接触接近、转向舷侧展开、维持交战距离；失联清目标并向最后接触搜索，超时失败 `contact_not_reacquired`，不全知判断击沉 |
| regroup | 要求区域/航点；全部当前受控成员实际进入区域且减速稳定后逐成员完成 |
| retreat | 要求区域/航点；停对海射击、保留防空、自主航行进入区域后完成；完成不冒充沉没或着陆 |
| intercept | 舰艇域明确拒绝 `ship_intercept_unsupported`；航空域仍由S04执行 |

每tick使用 `owned_order_unit_ids`，部分改派只释放重叠者；释放清旧控制/火力/目标。命令的source仅影响记录，human与ai共用校验、能力判定、执行器。真实终态与逐成员结果沿S01记录。未知目标毁伤只会导致失联/搜索，不宣称已击沉。

## 读模型与原因码

S07读取 `orders_snapshot()` 的request/intent、received/changed_tick、execution与history；读各单位 `task.ship` 的phase/reason、goal_m、distance_m、leader_id、slot、order_id，以及 `ship_motion` 实际speed/turn_rate/avoidance_reason。事件 `fleet_flagship_changed` 表示实际受控成员的领舰接替；不等同全军重新下令。

阶段：`cruise`、`forming`、`regroup`、`guard`、`air_defence`、`approach`、`deploy`、`broadside`、`search`、`withdraw`、`blocked`。

撤退区外完全失去动力或燃料时，保持同一executing任务，真实进度为 `blocked`，原因 `propulsion_unavailable`（动力不可用）或 `fuel_exhausted`（燃料耗尽）。S07显示“无法机动／撤离受阻”，不继续写“正在撤离”。舰仍active、浮水、未exited；保留可用防空和已知接触内的对海自卫。指挥官看到同一存续retreat不反复重下或制造失败终态；取消/改派仍沿S01。没有拖带、维修或凭空恢复动力。进入区域后才能成功退出。

主要执行原因：`following_route`、`rejoining_station`、`slow_member_reform`、`station_keeping`、`core_protection`、`air_defence_screen`、`close_to_gunnery_range`、`turning_to_broadside`、`maintain_gunnery_range`、`last_known_contact`、`awaiting_own_contact`、`contact_not_reacquired`、`protected_unit_lost`、`regroup_area_reached`、`withdrawal_area_reached`。运动附加：`neighbor_starboard`、`neighbor_yield`、`coast_detour`、`coast_braking`、`disabled_coasting`。

指挥意图原因：`search_no_contact`、`surface_contact`、`protect_core`、`air_defence_cover`、`intercept_air_threat`、`reserve_air_cover`、`reform_after_contact_loss`、`flagship_replacement`、`severe_damage`、`low_fuel`、`no_ammunition`、`force_depleted`。原因来自实际输入和执行，不是齐射/命中台词。

配置分开记录历史最大航速和游戏加减速/回转/距离近似。海岸为显式静态AABB海面投影，S07须把战斗环境的陆地/建筑投影传入同一场景参数；S06不从渲染网格猜测海岸。正常海战空海域可为空。不是海图寻路或拥挤港口调度系统。

## S07 场景配置示例（入口已冻结）

配置文件为 `data/fleet/showcase.json`：`profiles[definition_id]` 含historical_max_knots、cruise_mps、acceleration_mps2、braking_mps2、coast_drag_mps2、turn_radius_m、yaw_acceleration_degps2、engagement_range_m、flag_rank。历史航速换算1852/3600；其他均明确为游戏近似。

`navigation` 含clearance_m、prediction_s、station_spacing_m、reform_distance_m、search_timeout_s、solids；`policy` 含decision_period_s(6)、order_cooldown_s(24)、contact_hysteresis_s(18)、air_threat_radius_m(6500)、ship_retreat_radius_m、air_retreat_radius_m。不要为了镜头重排指挥周期。

每个 `commanders[faction_id]` 必须给 `patrol_center_m:[x,y,z]`、`patrol_radius_m`、`retreat_center_m`、`air_retreat_center_m`。可在安装前复制config.data、调整这些位置、重新load_data；安装会再次深复制，运行中改外部config不生效。场景中心应按双方初始位置和航向配置，仓库默认仅为示例海域。

```gdscript
var fleet: FleetConfig = FleetConfig.new()
assert(fleet.load_file().is_empty())
var settings: Dictionary = fleet.data.duplicate(true)
settings.commanders.jp.patrol_center_m = [-2500, 0, -3500]
settings.commanders.us.patrol_center_m = [2500, 0, -3500]
# 与S05读取完全相同的纯数据box；中心/半尺寸为数组，投影到XZ。
settings.navigation.solids = combat.data.environment.solids.duplicate(true)
assert(fleet.load_data(settings).is_empty())
assert(AircraftSuite.install(world).is_empty())
assert(CombatSuite.install(world, combat).is_empty())
assert(FleetSuite.install(world, fleet).is_empty())
```

S01场景的 `groups` 原样使用 `{id,faction_id,member_ids}`；不添加私有编队结构。同一4机flight可保留两组双机的显式group，指挥官按已存在完整同成员group寻址，否则用明确单位列表。四机威胁下两机拦截、两机保护，具体双机角色由S04执行。

舰艇spawn可选 `module_data.ship_initial={flagship_priority:100,fuel_fraction:1.0}`；不填时按舰型flag_rank，战列舰100、驱逐舰40，存活领舰保持至释放/损失。fuel_fraction为场景余油比例，172800秒巡航参考续航是游戏近似，非史实油量。`velocity_mps` 应按初始 `rotation_rad.y` 的艏向给定；0速可自然加速。

人类/工具自定义巡航航点放在同一BattleOrder.waypoints_m中；程序指挥官使用区域巡航，不另写坐标。撤离必须真实进入指定区域并减速后完成，随后设置 `ship_motion.exited=true`、`exit_reason="ordered_retreat"`、`active=false`，发一次 `ship_exit {order_id,reason,destroyed:false,sunk:false}`。这是驶出战区，S07据exited隐藏/分别记账，不能当失能或沉没。程序指挥官不再重派，reset恢复exited=false；S06不改damage。航空默认撤离区还需S07同步设置各spawn的 `aircraft_initial.withdrawal_center_m/withdrawal_radius_m`（S04自主低油退出使用此值）。

程序指挥官尊重当前human来源命令，并且不会覆盖S04正在真实withdraw的飞机。`fleet_commander.snapshot_state()`公开next_decision_s和最近receipt用于诊断；正常UI使用S01订单及 `unit.task.ship`，不把诊断当战术内容。
