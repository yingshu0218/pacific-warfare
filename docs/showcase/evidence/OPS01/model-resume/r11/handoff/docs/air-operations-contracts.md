# 航空作业第一阶段契约（OPS01 开发版）

更新：2026-11-11。**独立私有实际模型阶段自验通过，待统筹动态验收与S14/Chrome接入**。CV-9沿既有舰队积分航行，F6F-5沿既有飞行积分出动、巡逻、回收、整备并连续重新布置/再次出动。[S04 r10实际轮钩模型](showcase/acceptance/S04-carrier-use-review.md)已在私有stage消费，89项原机制与31项几何/任务组合检查通过，15fps关键动作见[接续交付](showcase/deliveries/OPS01-model-resume.md)。生产场景/公共模型未替换。

## 唯一命令入口与模块所有权

- 首次出动使用原 `BattleOrder(patrol)`，受令对象为实际飞机/机群，`target_id` 指向己方母舰，`area`为真实巡逻区域。UI保留 issuer/source/recipients/status/reason、每架执行与实际阶段时间线。不是一段预写的舰载演出台词。
- `retreat`＋母舰 target/有效area为召回；已经在舰上时直接报告已回收，不起飞。取消、改派沿原 `BattleCommand` / `SimulationWorld` 固定tick分发。OPS不会私建第二条指挥队列或另一个AircraftTasks。
- 私有 `task_bridge.gd` 继承原 AircraftTasks；mission阶段调用原执行器或可选的唯一`CarrierMissionDelegate`，其他作业阶段由OPS给飞行控制。delegate只写控制/任务意图，通过纯数据`carrier_delegated_mission.return_requested/return_reason`报告真实完成，保留同一取消/改派入口。当前不新增全局order_type或第二个任务执行器。
- `flight_bridge.gd` 调用原 AircraftMotion力积分，仅在有许可的起降阶段免通用180m低空拉起并取全襟翼失速参数；地形/能量/失速继续生效。on_deck不运行空中积分。进近与带襟翼起飞/复飞及其退出过渡中，速度航迹与物理机体俯仰分离，以有界迎角组合；完成过渡后的清洁飞行直接回原积分，不永久增加角速度限制。
- `deck_motion.gd`在ShipMotion之后积分甲板相对位移与制动，解轮胎刚性支承约束。空中与地面不会同tick双重位移。`CombatDamage`/`AircraftDamageMotion`拥有终端受损运动。

公共合入最小点见[接口提案](air_operations/OPS01/integration-hooks.md)。原型不与现有AircraftSuite同时安装；独立夹具只安装一个任务域处理器和一个飞行积分器。未来由统筹安排将此钩子接入生产套件，不能同时注册两个 `aircraft_tasks`。

## 同源甲板、运动与接地

消费[CV01甲板契约](carrier-deck-contracts.md)与原`deck.json`。单位为米、秒、弧度；+Y向上、-Z向前。飞行状态原点与缩放不变，模型到飞行坐标仍平移`(0,-2.30,0)`；此偏移不是轮胎接点。S04 helper的真实轮胎圆周沿甲板法线求支承，三轮解出约9.6453°停放俯仰和1.203077m原点离甲板高度，顶面15.85m时原点约17.053077m。旧同高三轮、pitch=0、18.15m停放与固定4.4m钩偏移均撤销。

`world_point = ship.world_transform() * deck_local_point`；甲板点世界速度为舰心平动＋`angular_velocity.cross(ship_basis * local_point)`＋甲板相对速度。刚性承载同时消费母舰完整姿态。海面渲染波动不参与甲板碰撞或接地高度。

`CarrierDeckGeometry.surface`消费同一升降机高度，孔/台面不匹配会禁止放行。全展开包络按13.056m翼展/10.236m机长保守检查，不能把一个中心点接地当整机净空。OPS未开放折翼/机库/升降机下行；SB2C、A6M与其他机型没有本阶段航空作业许可。

触舰用本tick前后实际机体/母舰姿态扫掠轮胎圆面支承点、实际机体/翼/尾/襟翼mesh支承点及完整旋转桨盘，选择最早物理触面；机体/桨盘先碰撞就交DM，不伪报轮胎触舰。合法轮胎接触保留纵向速度并对剩余步长积分。滑跑抬尾和接地落尾以有限角速度连续变化，原点高度随轮胎支承重算。只在区域、速度、下沉率、方向、坡度、甲板与预约条件均有效时作为正常着舰。

轮/钩失去DM宿主即排除。实际尾钩鞋端由S04 CPU helper计算，按当前姿态求0–40°上偏，使鞋边受甲板+0.02m约束，不移动飞机配合。每tick保存母舰局部的鞋端/鞋边扫掠段，与真实索段求三维最近距离；阈值0.073m（索半径0.023m＋鞋半宽0.05m），满足才进入减速。未挂索的实际滑跑可bolter再离舰，不直接吸停。索缆弹性、钩载荷与精细悬架未实现。

提前不稳定进近仍可复飞；已经物理触面却不满足包线时，在碰撞点发出既有`unit_surface_contact(surface=ground, surface_id=carrier_flight_deck)`。CombatDamage本tick决定禁用/解体；额外支承模块只让已经失效的残骸/有上限碎片随真实移动甲板承载，不恢复active或OPS占用。停桨后以实际桨叶相位、剩余mesh和声明的简化质量中心作有界重力倾转，不锁死首次姿态或停在单点悬空支承；以质量中心重力投影对接触凸包的15mm容差判定稳定。支承消失继续原DM终端运动。当前仍是粗粒度地面撞击/过阻尼落定，未加入完整刚体系统。原受控-10m/s下冲及新增错误低头导致桨盘先触舰均已通过。

包线、历史锚点和明确近似见[参数与原始资料](air_operations/OPS01/parameters-and-sources.md)。当前静止空气，真实15m/s母舰航行形成迎风；非零环境风明确拒绝，待统一空气相对速度接口。没有现代蒸汽弹射或自动着舰设备。

## 阶段与可观察数据

`unit.module_data.carrier_ops`和`modules.carrier_operations`是纯数据快照，模型/UI只消费。

| 字段 | 含义 |
| --- | --- |
| `phase`, `reason`, `since_s`, `order_id` | 当前真实阶段、等待/失败原因、入态模拟时间、当前高层命令 |
| `on_deck`, `local_m`, `relative_velocity_mps` | 运动所有权、局部甲板位置/速度；空中时仅作为观测量 |
| `gear_down`, `hook_down`, `flaps_down`, `hook_deflection_rad` | 实际使用态与CPU解出的钩上偏；候选Adapter直接消费 |
| `angle_of_attack_rad`, `configuration_transition_active` | 模拟拥有的构型机体姿态与退出过渡；参与接触/DM |
| `hook_pose`, `wire_id` | 实际鞋端/鞋边、自由端/约束端与真实挂索结果 |
| `sorties`, `recoveries`, `touchdown_count`, `go_arounds` | 实际离舰/有效停放回收/轮胎接触/复飞次数 |
| `launch_queue`, `recovery_queue`, `strip_owner`, `strip_use` | 有序队列和互斥全长直甲板预约；不允许同时放飞和回收 |
| `parking` | 有限前甲板停放槽与实际受令飞机ID |
| `fuel_stock_kg`, `ammo_stock_rounds` | 真实有限基地油弹库存 |
| `history` | `tick/time_s/unit_id/from/phase/reason/order_id` 实际状态转换；独立检视UI直接读取 |

正常一轮为 standby → preparing → queued → taxi_out → takeoff_roll → climb → mission → return/holding → approach → touchdown → arresting → taxi_clear → servicing → standby。

占用、航向或甲板失效会等待/复飞，复飞后通过真实飞行再进入队列。取消地面任务会制动并保留物理飞机位置；取消空中任务自主请求回收。损失释放预约/队列，不生成替代飞机。部分发动机损伤、active disabled、无油仅让OPS放弃作业，原飞行积分继续；真正crashing/wreck/removed才由DM积分，避免半空冻结或被拉回甲板。

## 库存与当前循环边界

每个实际UnitState只对应一个roster条目。存活待命、在空、受损移交、损失分别保留状态；库存没有第二个飞机实例。只有实际回收并在有效停车位停止后才开始整备计时，再从基地库存补入原`aircraft_motion.fuel_kg`和原`WeaponState.remaining_rounds`。不会给空中、损失或取消的飞机补给；库存不足只供应现存数量，不生成油弹。

一/双机首次出动、连续respot与第二波完整回收/整备均已自验通过；单机还覆盖牵引中取消后再次执行。此前停在`forward_park_requires_respotted_deck`的旧版限制保留在初轮证据中，当前版本已用连续甲板牵引替代。后方停机先挪到105m站位，再将前一架挪到75m站位，依然积分位置/速度、检查间距、占用整块直甲板；机头不靠瞬转掉头，动力不是虚构的飞机倒车推力。1.2m/s和0.35m/s²是抽象甲板搬运近似，无地勤角色或设备模型。双机两波全过程最小间距20m，始终是同两架UnitState。

当前只验收1机与2机整波再次出动。两机编制中仅出动一架、另一架留在后甲板时，回收会如实等待该甲板障碍清走；尚无“回收前把未出动后甲板库存重新移回前甲板”的反向地勤调度。当前可通过给两架下整波命令完成重复循环，不把这项未测单架混合甲板调度宣称通过。

## 独立入口与验证边界

- 检视场景：`res://tests/air_operations/inspection.tscn`，真实队列/指令/阶段，暂停、1×、4×、召回、再次Sortie、重开、跟随切换。默认一机；命令行`-- --two`为两机。
- 先用`tests/air_operations/prepare_model_stage.py --name <新名称>`构造私有stage，再以`tools/verify.py --owner OPS01 --project .local/ops01-model/<新名称>`串行执行。当前冻结stage为r11；不在普通根工程加载未安装的几何helper。
- 机制：`test_cycle.gd`、`test_operations.gd`、`test_model_resume.gd`。临时故障/资源消耗是受控测试输入，不宣称真实交战发生。
- `capture.gd`：`--fps=15 --segment=launch|recovery|waveoff|hard_contact`为关键短段；预滚从原始停放状态逐60Hz tick积分，仅不记录图像，没有补帧。旧3fps总览只作为历史阶段证据；录制帧率不宣称Chrome性能。
- S14/Session、生产自动扫描数据、普通启动和Web构建均未修改；Chrome待统筹调度。航母炮战、SB2C攻击、多型/两阵营/陆基、混合待机/出动反向调度及自动程序指挥官再出动策略均未通过本阶段；当前再次出动由同一BattleOrder新请求触发。
