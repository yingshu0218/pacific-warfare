# BOMB01：轰炸与受拦截任务候选交付

2026-11-11。**r18私有机制、真实单位场景和原生动作证据完成，待统筹独立复核；普通Showcase尚未集成或通过Chrome。** 没有覆盖公共运行文件，没有修改Session、菜单、自动注册或S14白名单，没有创建新聊天/子代理。实际版本为Godot `4.7.2.stable.official.ed1daf0bf`、Compatibility。仓库开始时无Git，未假定恢复点。

最终候选：[final-manifest.json](../../../candidates/bomb01/final-manifest.json)。对应[511份明确输入](../evidence/BOMB01/final/stage-input-manifest.json)、[冻结源码](../evidence/BOMB01/final/inputs/)、[显式集成数据](../evidence/BOMB01/final/integration/)、[接入契约](../../bombing-contracts.md)。S14还必须共同遵守其[S14-BOMB组合边界](../S14-BOMB-integration-inputs.md)。这份交付不授权用旧整文件覆盖最新S14。

## 已实现的行为

程序指挥官只根据本方实际接触或合法已知区域，从统一BattleOrder入口下达编队大指令。真实飞控决定进入、滚入/稳定、投放、拉起、脱离、重组与返航；没有定时投弹、保证命中、定时击落、位置传送或直接改目标健康。正常计时只用于决策频率、稳定条件、有限弹列间隔、引信和攻击超时等机制。

| 机型/日期 | 角色与有限载荷 | 实际能力与边界 |
| --- | --- | --- |
| SB2C-4 / 1944 | `dive_bomber`，1×AN-M64 TNT | 原已准入真实模型，弹舱、俯冲减速板、自然俯冲投放和拉起。没有发布预切翼尾组，不声称SB2C部位脱落/完整终端DM已合格。 |
| D4Y2一二型 / 1944-10 | `dive_bomber`，1×Type98 No25 | 真实舱门、摆架、翼下减速板；保留出生摆架姿态，甲板拒放及安全空中才推进摆架；不冒充翔鹤1941实际历史搭载。 |
| G4M1一一型 / 1942-07 | `level_bomber`，12×Type97 No6 | 稳定水平弹列、双机空间、受袭中止；战斗构型地面拆盖，没有虚构飞行开合门。陆基、无正常航母回收资格。 |
| B-25J-1-NC代表构型 / 1944-07 | `level_bomber`，6×AN-M64 TNT | 使用AV04最终透明机鼻模型，逐层有限弹列：0/1下、2/3中、4/5上，同侧下层先清。陆基、无正常航母回收资格。 |

Bomber角色拒绝intercept/engage/escort/aircraft_training狗斗任务，仍保留patrol/regroup/retreat导航。无防御枪弹不会阻止满载轰炸；最后一枚投下后仍连续拉起/脱离。低油、受损、空载、过低/过快、不足稳定段、目标丢失及错过窗口会改变真实后续，不补发炸弹。240秒攻击超时只限攻击阶段，实际650秒回归验证中止后能脱离并进入返航，不反复重置pullout。

炸弹进入原CombatProjectiles/CombatFrame/CombatDamage，显式gravity_release、零炮口速度、继承母机当前线速度、出生tick不推进。无制导；有重力、阻力、有限保险时间和距离、接触延时、寿命与唯一首次接触。完整弹体/尾翼/挂耳包络检查清离母机后，仍保留实际再碰撞；SB2C/B25仅按真实开舱通路拆分中央粗代理，不豁免整架飞机。海面、地面、建筑与实体沿同一查询，装饰建筑没有虚构健康。爆炸按实体最近代理一次曝光、距离衰减、地形/建筑/实体遮挡及原友伤设置处理。

`BombingMissionDelegate`实际继承OPS的CarrierMissionDelegate。与OPS组合只装一个任务桥，父级bombing_delegate为null，reset/accept/step/released只走一次；BombStores是唯一库存/释放写入者。实际OPS发布的`carrier_ops.on_deck`即使与高空位置矛盾，也会拒绝释放。航母返航hook保留给OPS；**本批没有验证SB2C/D4Y真实起降/回收**，独立到达返航空域不等于落地。

## 验证结果

通过报告：r18导入`20261111T153458-485b6221`；13项补测在`20261111T153539-703640f6`首子项通过；补齐原S04输出目录后的完整回归`20261111T153818-98e775ae`全通过。原始日志与结果均在[final/runs](../evidence/BOMB01/final/runs/)和[final/results](../evidence/BOMB01/final/results/)。

| 检查 | 证据 |
| --- | --- |
| 29项弹道/保险/损伤 | 独立解析重力、继承速度、薄屋顶扫掠、唯一首次接触、哑弹、延时单爆、海陆、近远衰减、友伤、建筑遮挡、完整弹体清离与回撞、出生姿态/有限对齐、旧枪弹零速度仍拒绝。 |
| 34项任务/OPS生命周期 | 双B25有限弹列、真实间隔/直航、保留编队槽位及长机丢失、库存不重置、同机取消/改派、真正的typed OPS单路径、正式on_deck字段、角色拒绝、低油/过低/受损/空弹、实际240秒超时。 |
| 13项转换补测 | 自然投放前2tick取消/低油均0投放；同机重新派单使用新身份；不足稳定距离漏失；本方接触过期后中止。改变初态5.5km→17km，接触0.0167s→22.0s、命令0.0333s→22.0333s、投弹39.4s→161.4667s。 |
| 20个真实挂点/包络 | 实际模型顶点核弹体/尾翼/挂耳；20槽均通过，模型/模拟位置误差0m；D4Y实际摆架位置也一致。 |
| 四型自然海面攻击 | 1/12/1/6枚均自然离架、解除保险后外部首次接触、完成连续拉起/脱离并存活，不能仅凭扣弹计通过。 |
| 真实单位轰炸场景 | SB2C→停泊雪风1枚/1次目标受损；D4Y→美M1阵地1枚/1次；G4M双机→美M1阵地24枚/2次；B25双机→停泊雪风12枚/2次。包括真实漏失与舰体直接命中，不直接修改目标健康。 |
| 真实受拦截场景 | F6F→G4M：172次原武器fired、32次damaged、投弹24→0；A6M→B25：139次fired、34次damaged、投弹12→0。原火控/碰撞/伤害导致中止、尾部脱落与落海，不保证别的初态有相同战果。 |
| 原有回归 | 原projectile14、gunnery69、weapon_cycle24、geometry8项通过；原simulation_commands与aircraft_motion通过。独立同输入枪弹的事件、单位、RNG、发射/终止计数JSON逐字节相同，SHA `eaaa6dad4e562965fc11af4672b97a4f948e3059963aef99cce62352e7deba67`。 |

六组场景是**停泊舰/不开火岸炮、有利追尾初态的受控机制夹具**。初态允许确定位置/速度和上级任务，不能在运行时按表改写战果。普通场景的舰艇机动、防空、FleetPlanner、菜单和双方观战UI须S14组合后重新验收。早期正面对头及高速追击没开火的失败证据保留，未为展示调整旧武器伤害/命中概率。

## 连续原生动作证据

[native-manifest.json](../evidence/BOMB01/r18/native-manifest.json)逐帧记录SHA、实际tick、挂点误差、源码与capture.json关系；六片共2760帧、960×540、15fps。模拟60Hz，每输出帧准确推进4tick，无插帧，无按墙钟演单位。先只读寻找自然事件，再从同一初态/种子重放录制；只有镜头跟随，未修改战局。

| 录像 | 范围 |
| --- | --- |
| [B25轰炸26秒](../evidence/BOMB01/r18/native/b25-bombing/action.mp4) | 六槽离架、有限弹列、继承运动、海面漏失与实际舰体接触。 |
| [D4Y俯冲26秒](../evidence/BOMB01/r18/native/d4y-bombing/action.mp4) | 真实摆架、离机、俯冲拉起、下落和阵地弹着。 |
| [SB2C俯冲26秒](../evidence/BOMB01/r18/native/sb2c-bombing/action.mp4) | 真实开舱、减速板、完整离机、拉起和舰艇弹着。 |
| [G4M轰炸26秒](../evidence/BOMB01/r18/native/g4m-bombing/action.mp4) | 实际拆盖构型、双机弹列、下落、阵地受损/漏失。 |
| [F6F拦G4M40秒](../evidence/BOMB01/r18/native/g4m-interception/action.mp4) | 实际曳光/损伤、尾部脱落、浓烟失控、海面衔接。 |
| [A6M拦B2540秒](../evidence/BOMB01/r18/native/b25-interception/action.mp4) | 实际尾部脱落、受损坠落与落海。长机50.13秒才落海，片中40秒只覆盖先落海的僚机，不假称两架都拍完。 |

录制事件过滤器没有收录`unit_surface_contact`，该遗漏保留。完整同输入headless场景事件与录制快照在[verification-and-cleanup.json](../evidence/BOMB01/final/verification-and-cleanup.json)显式关联：G4M僚机tick1874/画面468–469帧；B25僚机tick2000/499帧，快照均`contact_surface=sea`，实际画面有水柱/泡沫。没有把另一次事件伪装为原生录制事件。SB2C在开放弹舱内出生即与实体壳清离，无需等待source_cleared转换事件；其后实际碰撞一直启用。

所有重型验证共用`tools/verify.py`锁。58份历史报告含成功/失败/锁超时；134个先前子进程组经独立signal0只读复核均不存在。审计本身的`20261111T154926-8537488c`也正常退出并有cleanup_ok。没有浏览器标签、HTTP服务或保留的原生窗口；没有杀S14或用户原有进程。新音频/付费服务/账号均未引入，录制静音，不声称炸弹专用音效已验。

## 复建与S14接入

以下在仓库根执行，新stage名字不能覆盖已有stage：

```sh
python3 tests/bombing/prepare_stage.py review-bomb01
mkdir -p .local/bomb01/review-bomb01/docs/showcase/deliveries
python3 tools/verify.py --owner BOMB01-review --timeout 55 --lock-timeout 55 --project .local/bomb01/review-bomb01 import
python3 tools/verify.py --owner BOMB01-review --timeout 55 --lock-timeout 55 --project .local/bomb01/review-bomb01 test res://tests/bombing/test_mechanisms.gd res://tests/bombing/test_tasks.gd res://tests/bombing/test_transitions.gd res://tests/bombing/test_visual_contract.gd res://tests/bombing/test_scenarios.gd res://tests/bombing/test_interception.gd
python3 tools/verify.py --owner BOMB01-review --timeout 55 --lock-timeout 55 --project .local/bomb01/review-bomb01 godot --render -- --script res://tests/bombing/capture.gd -- --case=bombing_us_b25j_1944_07 --output=/private/tmp/bomb01-review-b25
```

正式合入须只取manifest中八个共享候选差异、八份新增脚本、五份显式数据及已验收的模型依赖。基线/OPS/extra全目录仅供复核，不能递归变成生产包。候选patch供重基，保留S14最新patrol期限校验、OPS取消隐藏110秒、F6F/A6M fighter角色与甲板过滤；不得用旧ops_frozen或旧fighter性能覆写它们。FleetPlanner与示例BombingCommander不得双重分配同一战斗机，推荐前者管战斗机、后者只管轰炸目标。投完/枪弹0不能跳过拉起/脱离。

来源、原页与近似分开列于[参数来源](../../references/bomb01/sources.md)。AN-M64统一1950 TNT身份；日本No6/Type98 No25原扫描已打开。完整飞行极线、加载重量/发动机/燃油图、精确历史俯冲包线和炸弹阻力未数字化；当前限值是各型独立保守任务近似，不宣称全部历史性能合格。爆炸半径、能量换算、结构伤害和姿态对齐同样是显式近似。

保留未完成：防御枪射界/火控/库存、逐发动机独立失效/气动扭矩、SB2C预切损伤组及完整终端DM、G4M/B25动态机场起降、SB2C/D4Y实际航母作业、普通入口/UI/Chrome与M5性能。本批双发机为合计推进损伤/共同模拟桨相位，烟点居中，不伪造已识别的受损发动机侧。

## 保留的失败与修复

r03俯冲过低/无投放、r04–r09资源释放错误、SB2C/B25出生后母机自撞、r12无实际拦截开火、未导入直接测试导致的class解析失败，以及r17/r18原回归缺夹具/输出目录错误均保留原日志。修复分别为真实姿态进入/弹道窗口、数据/运行夹具依赖拆分、开放弹舱真实通路与完整清离、合法有利初态、先导入及明确测试依赖/目录；没有通过删除失败、强制命中、全机免碰或放松旧枪弹校验获得通过。锁等待超时不记作机制执行通过。
