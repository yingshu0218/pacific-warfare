# OPS01 公共组合最小交接

2026-11-11 模型接续。实现仍在`scripts/air_operations/`与`tests/air_operations/`，普通S08公共模块/模型/白名单未由OPS替换。没有Git元数据；旧阶段基线见`baseline-hashes.json`，本次实际执行输入与公共文件核对见`docs/showcase/evidence/OPS01/model-resume/r11/audit.json`。

## 唯一所有权与顺序

| 所有者 | 职责 |
| --- | --- |
| `task_bridge.gd`，唯一`aircraft_tasks`，priority300 | 继承现有AircraftTasks与BattleOrder生命周期；mission阶段选择原任务或一个可选任务delegate；其他OPS阶段让出控制 |
| `CarrierOperations`，priority350 | 作业阶段、甲板预约、队列、油弹、飞行控制意图；不做空中位置积分 |
| `flight_bridge.gd`，唯一AircraftMotion | 调用原力积分；on_deck跳过，真实终端DM跳过；有效起降许可下豁免通用180m拉起；仅在构型过渡中组合物理机体姿态 |
| 原`ShipMotion`，priority410 | 母舰位置/速度/姿态积分 |
| `deck_motion.gd`，priority430 | 甲板相对运动、真实轮胎支承与扫掠接触、三维尾钩挂索、有限减速 |
| 原`CombatDamage`，priority650 | 真实碰撞损伤、拆分结果、终端与碎片运动、寿命 |
| `deck_contact_support.gd`，priority690 | DM后甲板承载，停桨后按实际剩余几何/质量中心作有界重力倾转与稳定支承；不恢复active/任务/补给，不另算战损 |
| S04候选AircraftAdapter | 只消费纯状态并显示实际模型；不写模拟位置/构型/损伤 |

生产组合时不得再安装另一份`AircraftSuite`任务/飞行执行器。现有任务、空战、OPS与BOMB必须在同一任务域内组合；公共改动由S14扩展的唯一所有者接入。

## BOMB01 可消费的任务hook

`CarrierMissionDelegate`是可选RefCounted接口，只有`supports(order_type)`、`reset(world)`、`accept(world,order,ids)`、`step(world,unit,order,owned,formation)`、`released(world,order,ids,reason)`。在注册/重开前将实例赋给唯一task bridge的`mission_delegate`。支持判断沿用已通过全局校验的BattleOrder类型；该hook不绕过校验、不新增order_type或第二个调度器。

delegate在真实`mission`阶段设置原`aircraft_control`，通过已有武器/库存/命令进度契约执行任务。它不能积分位置、写甲板阶段或注册第二个飞行模块。任务完成或需要返回时写：

```gdscript
unit.module_data.carrier_delegated_mission.return_requested = true
unit.module_data.carrier_delegated_mission.return_reason = "actual_task_complete"
```

该纯数据由task bridge初始化为`{active:true, return_requested:false, return_reason:""}`。OPS读取显式完成信号后负责回收；delegate处于active时不强加演示110s巡逻计时，低油/损失/取消仍生效。取消/改派沿原BattleCommand释放入口，`released`只到达同一delegate一次并清除该纯数据。delegate为空或不支持该类型时仍走原AircraftTasks。

本阶段用一个无弹药probe验证600个真实mission tick、显式完成原因、取消一次与单任务执行器。它证明组合生命周期，不代表SB2C/G4M/D4Y挂点、投弹、命中、陆基或多型甲板已经完成。

## S04 四文件与CPU几何

固定候选清单`candidates/s04-carrier-usage/candidate-manifest.json`，SHA256`379681d3aa81909d08a1e7c28a323ca7bac03054a390e2efb83d558ec8c9a3f3`。stage builder只从普通`tools/showcase_runtime.json`白名单、CV01/OPS显式子树与四份夹具取输入，保留`.gdignore`边界；不递归吸收AV02/G4M/AU01在制资源。四份候选只覆盖stage目标，不改公共模型。

`CarrierAirframeGeometry`消费已发布helper；圆周轮胎接点随真实甲板法线求解，宿主断离/耐久归零即排除。`model_contact_proxy.json`由候选实际mesh离线提取，用于机腹/翼/襟翼/尾与停桨实际相位支承，旋转桨盘仍是完整解析包络。轮/钩数据不从渲染节点临时读回。渲染只消费`carrier_ops.gear_down/hook_down/flaps_down/hook_deflection_rad`。

普通根工程尚无helper；OPS新检视必须在准备后的stage运行。独立场景仅在内存注入Essex非战斗定义与FleetConfig；不代表生产注册或航母炮战准入。

## 保留限制

零环境风、一艘Essex、一/两架F6F完整波次；双机仅放飞一架时，后甲板留机可能阻挡回收，尚需反向清场调度或生产校验限制。日方、多型混合、陆基、轰炸、自动再次波次、S14/Chrome由各任务后续接入。有限油弹/取消/损失/复飞/连续复位与二次循环的既有机制必须保留。
