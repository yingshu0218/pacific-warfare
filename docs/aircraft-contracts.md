# S04 航空契约 v1

2026-11-10；S04 实现完成、提交统筹验收。纯状态入口 `AircraftSuite.install(world)`；不替代S01高层命令或S05战斗模块。本阶段只有A6M5a与F6F-5，无航母／机场起降、补给和再次出动。

## 正式ID、原点与安装

`jp_a6m5a_1944` 是1944年2月起的五二型甲子型，非某架普通52保存机复刻。`us_f6f5_1944` 保持S01正式ID，为六挺 .50 的F6F-5子型。历史配置与资料限制见两份 `docs/references/aircraft/*/modeling-brief.md`。

米、秒、弧度，+Y上、-Z前。飞行参考是原模型z=0处机身中心，**不是实测重心**。旧F6F点减 `(0,2.30,0)`；旧A6M点减 `(0,1.60,0)`。模型、实体位姿、炮口和S05代理均已用新基准；不要再次保留旧地面原点高度。三点机高仍是历史规格，不是飞行原点以上高度。

| 型号／炮位ID | 武器ID / 弹药ID | 飞行基准炮口[x,y,z] m |
| --- | --- | --- |
| F6F wing_port_01 / wing_starboard_01 | us_an_m2_127mm_single / us_127mm_m2_ball | [±2.35,-0.155,-1.9343181818181819] |
| F6F wing_port_02 / wing_starboard_02 | 同上 | [±2.73,-0.155,-1.8968939393939392] |
| F6F wing_port_03 / wing_starboard_03 | 同上 | [±3.11,-0.155,-1.859861111111111] |
| A6M cowl_port_01 / cowl_starboard_01 | jp_type97_77mm_single / jp_77mm_type97_ball | [±0.16,0.56,-3.94] |
| A6M wing_port_01 / wing_starboard_01 | jp_type99_2_model4_20mm_single / jp_20mm_type99_2_shell | [±2.28,0.04,-1.9108092747851142] |

port取负x，starboard取正x。各炮位 `role=aircraft_fixed`、一管、零炮座转角/俯仰，`position_m` 为炮口，`muzzle_positions_m=[[0,0,0]]`。宿主为左右机翼或 upper_engine_cowl，Marker置于实际炮管前端。坐标小数用于代码一致性，历史照片不提供毫米级测绘精度。S05代理已平移并保留机鼻同步枪上方通道；不从整块发动机/翼面内部生成弹丸。

编制固定：A6M5a双7.7＋双20mm弹链炮（125发/炮），F6F六挺.50（400发/枪）。日机7.7初始500发、周期与弹药弹重/初速仍含估值，S05是战斗参数唯一维护者；S04不覆盖 `data/ammunition/` 与 `data/combat/` 的后续校准。所有正式source.status遵守目录枚举，当前航空几何/性能资料为provisional，不以代码绿灯声称测绘通过。

## 安装顺序与表现接口

```gdscript
# DefinitionCatalog需载入两型单位、引用的三种弹药与三种共用武器。
var world: SimulationWorld = SimulationWorld.new()
assert(world.configure(catalog, scenario).is_empty())
assert(AircraftSuite.install(world).is_empty())
var combat: CombatConfig = CombatConfig.new()
assert(combat.load_file("res://data/combat/showcase.json").is_empty())
assert(CombatSuite.install(world, combat).is_empty())
```

安装都在首tick前。模块顺序为S05 frame80/contacts100 → S06 commander200 → aircraft_tasks300 → aircraft_motion400 → S05 targeting450/weapons500/projectiles600/damage650。不安装第二份飞行运动或旧Showcase机体移动脚本。

纯模型场景：`res://scenes/units/aircraft/a6m5a_flight.tscn`、`f6f5_flight.tscn`；定义model_scene已引用它们。类 `AircraftAdapter` 提供 `apply_state(snapshot)`、`mount_sockets()`（兼容别名installation_sockets）、`apply_weapon_state(id,state)`、`muzzle_transform_local/global(id,barrel_index)`。固定枪不旋转。表现读取模拟给出的propeller_phase/操纵面角，无本地模拟时钟；active=false但damage.phase=crashing/wreck时保留画面，removed或正常撤离隐藏。

旧 `aircraft/scenes/a6m5_52ko.tscn`、`f6f5.tscn`、查看器和机场的builder调用保留。新增 `flight_simplified` 默认false，纯飞行适配器设true；共享builder没有改变其他飞机入口。飞行模式收轮、无外部油箱/火箭，只保留连续机鼻、简化舱盖及必要活动面，不做发动机内部。

## 状态所有权和场景输入

- `module_data.aircraft_initial`：场景只读初态，可含 `fuel_kg`、`withdrawal_center_m:[x,y,z]`、`withdrawal_radius_m`。余油被限制在参考容量内，不能与历史容量混写。建议S07显式设置双方不同的撤离区域；缺省用各自初始航向后方6000m、半径500m。
- `aircraft_motion`：S04运动写fuel_kg/fuel_capacity_kg/fuel_used_kg、speed_mps、distance_m、throttle、turn_rate_radps、energy_height_m、propeller_phase_rad、aileron_rad/elevator_rad、exited/exit_reason、surface_contact。参数源 `data/aircraft/performance.json`，读后每实例隔离。
- `aircraft_control`：S04任务写heading_rad、altitude_m、speed_mps，可带精瞄pitch_rad，运动消费；取消/部分改派释放旧控制。没有任务时保持受限的当前航向和巡航高度，fire=false。
- `air_formation`：稳定slot/pair_index、pair_leader_id/flight_leader_id、leader/wingman、attack/support。每tick按当前归属重选存活长机；不会将单位绑定到偏移或共用轨道。
- `unit.task.aircraft`：真实phase/reason、target_id、distance_m、pair/role，供正常观战UI解释执行。阶段/原因改变立即回报，连续距离最多每120tick汇报一次；高频细值不进入持久命令历史。
- S04只读S05的combat_runtime、WeaponState库存与damage因子；只写combat_intent的fire/allow_aa/burst_until_tick，并经SET_TARGET命令提交目标。枪位、库存扣减、弹丸和损伤没有第二套实现。

`AircraftTasks`仅从己方 `CombatContacts.find` 和S05公布的己方contact索引读敌情；直接get_unit只用己方运动/保护对象/归属。失联不跟踪敌人隐藏坐标。S06只需复用 `submit_order`，不应逐tick重新下令或直接写飞行控制。

## 高层任务与真实终态

```gdscript
var order: BattleOrder = BattleOrder.new()
order.order_id = "jp_air_patrol_01"
order.issuer_id = "jp_commander"
order.source = "ai" # 未来human走同一入口
order.faction_id = "jp"
order.recipient_ids = ["jp_fighter_flight"] # 四机编组或单机列表
order.order_type = "patrol"
order.area = {"center_m":[0,1500,-4000], "radius_m":2000.0}
assert(world.submit_order(order).accepted) # queued不是已经执行成功
```

| order_type | 目的地/目标 | 执行阶段与结束规则 |
| --- | --- | --- |
| patrol | area或waypoints_m | 长机按航点实际飞行，僚机追踪移动站位，另一组保持支援站位；连续任务，直到改派/取消/退出条件。航点是 steering目标，不强制轨道。 |
| escort | 友方target_id，area.radius_m可选保护范围（默认2500m） | guard/approach/aim/burst/return station；单双机保留僚机，四机保留支援组，外圈威胁不牵走全部保护力量；目标离圈清目标归队；保护对象损失后withdraw:protected_unit_lost。 |
| intercept / engage | 敌方目标ID，可附搜索area | 只据己方接触搜索/接近/瞄准/短点射，规避尾追、脱离再接敌；第二组分担其他已见敌机，僚机实际追随/掩护长机。失联搜索最后观测，30s未重新接触转withdraw:contact_not_reacquired，不靠全知active判断击杀。 |
| regroup | 必须有area或waypoints_m | surviving members向实际集结区飞行，全部受控成员进入半径并维持2s后逐成员completed:regroup_area_reached。损失/改派不保留死成员等待。 |
| retreat | 必须有area或waypoints_m | 停火并真实飞入指定区域，逐成员completed:withdrawn:ordered_retreat，随后aircraft_exit；不宣称着陆或补给。 |

自动退出优先于继续攻击：`low_fuel`（余油低于预留8分钟巡航参考消耗+距撤离区预计消耗）、`no_ammunition`（可用枪炮库存为零）、`severe_damage`（动力<.45、操纵<.55或结构<30%），以及己方接触显示局部至少3敌、超过己方2倍且自身低能量的 `outnumbered_low_energy`。退出先执行withdraw，进入撤离区才completed:withdrawn:<reason>并发 `aircraft_exit {destroyed:false,landed:false}`。未到达时不能显示“已返航”。严重损伤继续恶化而坠毁则由S05真实失能/S01释放处理，不保证安全退出。

取消通过 `BattleCommand.CANCEL_ORDER`，部分改派只释放重叠成员。任务每tick用owned_order_unit_ids取归属；取消/失效/替代会清旧控制、点射和旧目标，剩余成员独立继续。reset清所有缓存、点射期限、目标命令序号和燃油，恢复场景输入。

## 运动到损伤边界

沿S05 `unit_surface_contact`：运动取实际海面交点，发一次事件，data={velocity_mps:实际速度,surface:"sea",reason:"forced_ditch"}；本tick清fire并停止继续积分，不写damage或宣称安全退出。S05在650统一设置active/能力/wreck并输出unit_impact。正常 `aircraft_exit` 与迫降损失/被击落分别记账。首个Showcase海战仅测试海平面0，未实现地形飞行避障或基地着陆。

## 复验入口和限制

`python3 tools/verify.py --owner S04 --timeout 60 test res://tests/test_aircraft_models.gd res://tests/test_aircraft_motion.gd res://tests/test_aircraft_tasks.gd res://tests/test_aircraft_combat.gd res://tests/test_aircraft_replay.gd`。首次检出先用同一包装器import注册全局类。所有原生/导入/headless通过该锁；沙箱证书或user日志权限错误使用受控提权的原命令，不改HOME或屏蔽ERROR。

飞机性能是历史量级约束下的点质量近似，未求解完整气动/螺旋桨/WEP热限制/燃油载荷变化。双机/四机、护航、失联、退出和真实炮弹碰撞已有局部证据，整体UI、电影镜头和Chrome性能属于S07/S08（按2026-11-10用户要求，仅Chrome验收；历史Safari记录保留）。详见 `docs/showcase/deliveries/S04.md`。

## S04 立体空战补充 v2（2026-11-10）

本节定义最小字段供统筹及表现所有者接入。正式单位、炮口、BattleOrder与S05接口不变。只有航空执行器与运动器新增纯数据；`rotation_rad`、`velocity_mps`仍是模型、碰撞与固定炮口的权威姿态/速度，表现无需另加随机翻滚。

- 控制 `module_data.aircraft_control.flight_direction:Vector3`：世界空间单位方向，允许明显上仰/下俯；配合现有speed_mps，新增可选max_bank_rad/turn_side。旧heading_rad/altitude_m/pitch_rad继续作为巡航/工具兼容入口。持续climb_mps只约束动力可供的持续爬升能量，不再夹住战斗瞬时pitch。
- 运动 `aircraft_motion.forward_m/lift_up_m:Vector3`、`path_pitch_rad/bank_rad/load_factor/load_limit/stall_margin/vertical_speed_mps` 只读。`safety_state`为normal/stall_recovery/low_altitude_recovery/overspeed_recovery/energy_recovery/terrain_recovery/glide，反映实际限制。三维向量积分/正交朝向避开近垂直Euler奇点；rotation_rad仅作为既有公共姿态序列化。
- 任务 `unit.task.aircraft.maneuver_phase/maneuver_reason`：真实空间机动状态。既有phase保留approach/aim/burst/evade/extend/formation等任务兼容。空间阶段包括climb_setup/dive_attack/high_yoyo/low_yoyo/zoom_climb/diving_break/oblique_extend/high_cover/vertical_rejoin/recover/track；中文建议为占据高位/俯冲攻击/高位修正/低位增速/拉升脱离/俯冲规避/斜向脱离/高位掩护/立体归队/安全改出/追踪瞄准。原因由相对高度、闭合速度、可用动能、尾追接触或安全阈值产生；没有固定演出台词。
- 新的过载、操纵增益、安全余高与战术阈值为明示的游戏近似，保留原历史极速/持续爬升/服役信息，不修改S05命中、枪弹或场景初态。字段最终证据与限制见专项交付文档。

S08只需将maneuver字段和safety_state映射为中文或供查看；航空专项不编辑模型/adapter、UI/相机、first_playable、S05或导出工具。普通3D表现继续直接消费既有姿态，不要求新表现控制。

地图接入点：`AircraftMotion._surface_height(world,position)` 调用统一`TerrainQueries.height_m(world,position,true)`，不自行定义地形。只读`aircraft_motion.height_agl_m`供安全与战术使用；真实接触后仍走S05的unit_surface_contact。

### 地形接入与恢复

`TerrainQueries`/`BattlefieldTerrain` 已落盘后，航空运动已直接消费同源height_m(...,true)与segment_hit。`_surface_height`不再硬编码海面；提前4–10s按速度、可用过载和滚转改出时间查前方余高与实际线段，比较两侧路径选择有限转弯/爬升。前后位置只作实际扫掠，命中真实surface/position/normal/target_id后交S05，不瞬移到山顶，也不将山地/建筑碰撞写成forced_ditch。

附加安全状态为`energy_recovery`（动能预留不足，卸载改出）和`terrain_recovery`（前方地形不足，转向/爬升避让）；附加空间阶段`separation`表示真实友机冲突分离。`terrain_ahead_m/terrain_clearance_m/terrain_lookahead_s/kinetic_margin_m`为只读诊断。地形未安装仍由统一查询返回海面0。新操作过载下界-0.35g用于短时卸载/推杆恢复，是游戏控制近似，非子型结构/负g供油能力的历史认证。

动作的进入、退出、超时与安全中止保存在航空执行器的任务记忆，并随模块snapshot/reset复现。安全改出至少保持1.5s，恢复到1.50倍基础失速速度且航迹俯仰小于18°后才重新允许战术选择；友机冲突会暂时覆写期望方向为实际分离方向并保持有限时间，阶段为separation。不会把局部避让或任务阶段名称当成已经完成的物理动作。

失效受令单位释放时仅清理自身控制、编队与开火意图，不向失效单位提交SET_TARGET；己方仍有效但接触滞后的目标请求继续由S01真实状态校验拒绝，不给AI增加敌方实时active查询。

## F6F机动校准接口 v3（2026-11-10，自验完成，待统筹独立复验）

v2连续片段被用户与统筹退回复核，不能当作新机动验收通过。对照保存在`docs/showcase/evidence/S04-spatial/v2-before-f6f-calibration/`。问题不是模型外形，而是大坡度下长期低/负载荷、背后追瞄引出的错误上仰以及世界水平坡度限制。

航空控制新增可选`lift_plane_normal:Vector3`与`load_factor_g:float`，表示真实机动平面的法线及飞行员拉杆载荷请求；运动器仍须有限滚转、受速度/过载/安全包线约束，将升力沿实际机体上方向施加到真实速度。不支持表现单独摆姿。未提供这些字段时采用协调的航向/航迹俯仰引导；不使用跨身后三维最短弧追瞄。新增`aircraft_motion.body_roll_rate_radps/heading_rate_radps/path_pitch_rate_radps/induced_drag_mps2/requested_load_g/roll_error_rad`为只读实测量。

F6F依据己方尾追/横穿接触选择`break_turn_roll/break_turn_pull`（大坡度急转）、`roll_reversal_roll/roll_reversal_pull`（反向滚转急转）或净空/速度允许的`split_s_roll/split_s_pull`（半滚倒转）。阶段依据实际滚转对准和航迹完成转角退出，并有超时/安全中止；普通追瞄、高低位修正、编队和撤离继续沿既有命令接口。具体门槛与自验数据以最终专项交付为准。UI/相机仍由其所有者接入，航空代码不修改表现姿态。

表现字段清单：新phase为break_turn_roll／break_turn_pull、roll_reversal_roll／roll_reversal_pull、split_s_roll／split_s_pull；新reason为tail_contact_roll_and_pull、contact_crossed_current_turn、tail_contact_split_s_envelope。退出last_exit为maneuver_geometry_complete、friendly_separation、safety_abort或maneuver_timeout。可译作急转滚入／急转拉杆、反向滚入／反向拉杆、半滚倒置／倒转拉起；这些是实际阶段，中文显示由统筹指定的UI所有者接入。

控制权与退出补充：已开始的防御机动按已记录的真实尾追接触/机动平面持续，僚机短时归队判断或接触变化不会在滚转中途夺权；不根据失联目标的隐藏位置继续瞄准，并始终停火。危险、撤退、取消/改派或友机避碰可中止。`module_data.aircraft_maneuver.blocked_until_s/last_exit`在同一架飞机上保留有限冷却，清理任务/接触记忆也不能绕过；reset清空。额外last_exit为contact_lost、task_navigation、task_withdrawal、order_released。

`heading_rate_radps`是水平投影航向角速度，近垂直时不代表机体突转；物理航迹曲率用`path_turn_rate_radps`，滚转用`body_roll_rate_radps`，连续性以完整三维姿态验证。普通导航仍有合理坡度限制；显式机动使用随航迹运输的真实升力框架，可越过90°并倒置，不每步重置到世界水平。

终版证据与复现见[立体空战交付](showcase/deliveries/S04-spatial-combat.md)。正常追瞄与机动滚入保持正载荷；-0.35g下界只供失速/近垂直卸载恢复使用。升降舵按实际拉杆载荷驱动，越过垂直时不按世界俯仰角导数反向。

## DM01 航空毁伤扩展（2026-11-11）

两型机保持上述健康外形、武器安装和 v3 飞行。真实部位命中新增独立两翼与尾翼结构健康；固定翼预切分组仍在组内合批，渲染仅消费模拟碎片位姿。engine 失效独立滑翔；control 功能失能与 tail 结构断裂分开。具体字段、接触生命周期、角速度继承及 FX01 烟源接口见 [航空毁伤契约](aircraft-damage-contracts.md)。DM01 的终端运动替代旧的冻结姿态重力平移；不改健康控制器和历史整机性能表。
