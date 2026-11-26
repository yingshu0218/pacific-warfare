# S14 全单位 Showcase 阶段交付

2026-11-11（Asia/Shanghai）。**阶段装配/原生证据冻结，释放执行名额；不申请S14最终通过。** 依统筹排程，本轮没有启动Chrome/HTTP/Web导出。完整360°滚转训练与两型战斗机直接演示由原S04接续，SB2C当前模型由原模型聊天准入，随后恢复S14最终集成与一次Chrome，再交S08普通启动/10分钟/三重开。

## 可用入口与本轮结果

`res://showcase/all_units.tscn`，不改根大和、旧开阔海/岛港和模型查看器。四舰、6架F6F、4架A6M、2架SB2C与3座岸防，共19个真实模拟单位、9种型号。五个兵器检视条目另计，父子模块不冒充完整单位。逐型路径/配置/能力/准入/观看入口见[全单位清单](../all-units-inventory.md)。

六个选段为连续导览、双机、四机、F6F尾追规避、SB2C护航、舰炮火力。选段明确重置整场并增长generation；模型按19个稳定ID复用。自动导览不瞬移存活单位，不强制命中/伤害/保活。最先展示双机与SB2C，15–47秒穿插四舰，47–63秒看两型地面炮，随后四机/交战/集结/护航、兵器检视，再继续自动观战。单个主体退出不会终止整个导览；A6M及其余个体始终有单位跟随入口。没有把“加载在远处”作为可读画面证据，各型均另拍正式入口跟随截图。

默认收起原有信息卡，必要导览控件压成一行；“恢复信息”及“指挥态势”保留双方真实任务、成员执行和时间线。演示导演经统一BattleOrder的外部指挥入口（source=human、issuer_id=s14_exercise_director）发令，UI明确标为“演示任务”，不冒称玩家正在指挥，也不替换自然舰队/地面指挥。敌方航空执行仍只用己方contacts；镜头只读复制快照。

统筹已实际查看并确认本阶段默认简洁UI、M2HB/四联炮露出、底板条纹修复及机动近景有效；这不构成S14最终通过。恢复时另需把仍偏小的护航全队画面与SB2C/护航双机近景交替。

SB2C通过独立adapter、定义/性能/一般碰撞profile接入生产导航和飞行积分。原模型减y=2.38m作为飞行参考，不缩放；收轮、闭合展示翼面/弹舱、隐藏展示挂载，桨相位和活动面读取真实状态。独立性能及损伤阈值仍是明确估值，未当成实测历史曲线；没有复制F6F参数。仅巡航/集结/撤离与受护航，不开放战斗机追逐、投弹、后射手、实用机炮、起降或DM预切。原模型未编辑，round3后修订仍待准入。

## 实际画面与连续证据

- [默认简洁画面](../evidence/S14/native/normal_ui.png)、[双方实际命令](../evidence/S14/native/real_orders.png)。四舰、三型机、两型岸防的独立跟随图在同目录。
- [双机24秒](../evidence/S14/pair_phase.mp4)、[四机24秒](../evidence/S14/four_phase.mp4)、[F6F规避24秒](../evidence/S14/maneuver_phase.mp4)、[SB2C护航24秒](../evidence/S14/escort_phase.mp4)。四段共960帧，每帧推进6个真实tick，以10fps编码，**这是证据编码频率，不是游戏/Chrome帧率**。片段展示本阶段的巡航/编队/规避/护航开端；四机30秒后交战、75秒后集结不在这24秒连续片段内，未宣称已经取得完整循环视觉验收。
- 双机相机从实际编队轴横向观察，避免前后深度令一架变成小点。四机全队上下文与两个双机近景交替；现有较大站位下，全队画面的机型可读性仍需随S04训练演示恢复时确认。单机规避镜头保持世界up，不抵消飞机滚转。
- 当前F6F受控初态实际触发`break_turn_roll/pull`；**这段没有完成完整360°滚转，也没有将半滚倒转算作已复现**。菜单暂保留了原v3半滚倒转意图名，恢复时应改为与实际训练契约匹配。完整动作交S04新增真实高层训练入口。零战当前可跟随/编队/交战，尚无单独直接机动训练选段。
- [最终M2HB检视](../evidence/S14/gallery-final/weapon_2_plate_on.png)、[最终四联炮检视](../evidence/S14/gallery-final/weapon_4_plate_on.png)。`gallery-isolation`的同机位仅隐藏新底板后条纹消失，确认是底板顶面与码头共面；将12cm实体底板嵌入码头4cm，使顶面/宿主脚点高8cm后消除。正常DirectionalLight与战场阴影未改。M2/M1917的上托块已实际接触枪体，不冒称历史战斗炮架。

`native-draft1/`保留大UI/旧承载高度失败图，`native-draft2/`保留被退回的遮挡/旧机位；`native/weapon_2.png`等为条纹修正前静态证据，**兵器最终图以gallery-final为准**。连续实飞与最后静态/控制报告分开存于`native/air_capture.json`和`native/capture.json`，防止静态复验覆盖运动记录。

## 检查与实际范围

| 检查 | 结果/限制 |
| --- | --- |
| 六场短装配与重置/回放 | `mechanisms_assembly.json`，51项通过；19单位、各场SB2C真实位移、未因无弹退出、无命令拒绝、正常reset与同输入回放。该轮先于后续初始站位/机位收敛，是阶段装配证据，不冒充最终长测 |
| 连续导览211秒纯模拟 | `mechanisms_guided.json`，11项通过；516次发射、54次命中、317次空爆，最大活动飞机滚转约102.87°/航迹俯仰约37.98°，无命令拒绝。使用收敛前初态，不能将数字套在最后原生片段上；主要证明任务流程会执行/战果真实 |
| 最后真实场景控制 | `native/capture.json`，8项通过：相机不改世界、暂停、2倍率、选段generation、重开、SB2C正常跟随/详情、双方指挥入口；19模型复用 |
| 运动和输入冻结 | `native/air_capture.json`，960帧，捕获前后233份运行脚本/场景/数据hash相同；逐帧真实状态/任务/编队/速度/载荷均留存。视频参数见`videos.json` |
| 条纹隔离/修复 | `gallery-isolation/`与`gallery-final/`，同机位对照已实际打开；只改变新检视底板几何，没有全局关阴影 |
| Chrome、性能、长测 | 未执行；按统筹要求等依赖准入后恢复，不报告原生FPS为浏览器成绩 |

所有引擎/原生/编码经`tools/verify.py`同一锁、明确timeout，固定Godot `4.7.2.stable.official.ed1daf0bf` / Compatibility。首次受限导入因本机编辑器设置写权限失败；首次长机制轮因本机日志/证书权限诊断及早期SB2C位移不足而失败，原报告保留。后续按原包装命令经受控权限运行，未屏蔽ERROR。最终截图/控制/输入守卫/编码均通过，完整成功/失败索引见`validation_runs.json`。

## 源码所有权、恢复与接续

[最小接续接口](../S14-aircraft-integration-handoff.md)列出S04训练命令期待字段、注册与相机消费点，以及SB2C原点/clean形态/活动轴接口。

S14新增源码在`scripts/showcase/`、`showcase/all_units.tscn`、SB2C运行场景与定义、六份s14场景和单独combat overlay。仅三个共享生产文件：

1. `FirstPlayableSession`可选航空executor/只增加键的combat overlay，以及切场generation保留。旧场景继续原路径。
2. `data/aircraft/performance.json`仅新增`us_sb2c4_1944`键，原两型性能不改。
3. `ui/observer_text.gd`仅给导演issuer标“演示任务”，保留实际任务/时间线。

未编辑first_playable.gd、AircraftAdapter、F6F/A6M模型、航空运动/伤害/helper/FX/shader、冻结地图/云海、原SB2C或根配置。未接AU01和S12现代化UI。新授权的航母/港湾/轰炸机扩展留给`expansion-plan.md`，不混入19单位基线。

无Git。Session/性能修改前局部副本在`.local/s14-before/`；UI仅新增的hunk可按恢复清单反向恢复。阶段拥有文件副本在`.local/s14-phase-owned/`。源码/证据/hash/清理索引见`evidence/S14/phase_freeze.json`。空中连续捕获与阶段最终源码唯一生产差异为后来修复的`weapon_gallery.gd`底板+8cm；原文件保留`.local/s14-air-input/`，输入hash仍真实对应当时画面，不将新gallery hash套在旧空中帧上。其他航空/任务/模型源码无变化。

所有本轮临时原生窗口随有界Godot进程退出；没有启动Chrome/HTTP/编辑器窗口，未关闭用户原有窗口或其他任务进程。实际进程组核对见`cleanup.json`。本轮结束释放名额，等待两项依赖后恢复S14，不自行新增聊天/代理。

阶段复看（后台自动截图退出）：

```sh
python3 tools/verify.py --owner S14-review --timeout 90 godot --render -- --minimized --resolution 1280x720 --script res://tests/all_units_capture.gd
python3 tools/verify.py --owner S14-gallery-review --timeout 60 godot --render -- --minimized --resolution 1280x720 --script res://tests/all_units_gallery_probe.gd -- --fixed
```

完整滚转、两型可重复训练、SB2C模型准入、完整四机/护航循环的连续观感、可选真实命中受控伤损演示入口、最终Chrome基本加载与选择仍未交付最终验收。DM受控演示应消费原板块的真实命中夹具/正式入口，本阶段没有把测试脚本伪装成正常菜单。
