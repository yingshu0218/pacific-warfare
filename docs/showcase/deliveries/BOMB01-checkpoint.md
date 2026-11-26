# BOMB01 可恢复检查点（未验收、未完成）

2026-11-11。统筹按用户“增加 B25 并加入 Showcase”的最新优先级，要求为 AV04 腾出执行名额。本轮已停止实施；保留候选和失败证据，等待统筹在同一聊天接续。**不得按本文件将轰炸能力注册或宣称通过。**

机器状态见 [BOMB01-progress.json](BOMB01-progress.json)，候选状态见 `candidates/bomb01/checkpoint-manifest.json`，SHA256 `d92dc4ad77869d1f4d1ad1b2432f7d1ed216d3c825a7e4ae195f4369fa6bc922`。

## 基线与所有权

- 已读取 AGENTS、总体规划、任务/直接依赖、BOMB01 执行卡、扩展计划及现有弹丸/碰撞/损伤/命令/航空/地形实现；根目录 `git status` 确认无 Git 仓库，不假定恢复点。
- `candidates/bomb01/baseline-manifest.json` 固定启动时 417 项输入：当时 `tools/showcase_runtime.json` 的 396 项明确文件，加项目配置、指定回归夹具及已准入 AV02/AV03 源码/挂点。源码在 `candidates/bomb01/baseline/`。不从之后的 S14 更新重新取隐式基线。
- 9 项共享改动只在 `candidates/bomb01/overrides/`：AmmoDefinition、DefinitionCatalog、BattleOrder、SimulationWorld、CombatConfig、CombatProjectiles、CombatDamage、AircraftMotion、AircraftTasks。`destinations.json` 与 checkpoint manifest 逐项记录目的路径、基线和候选 SHA256。
- 参数只在 `candidates/bomb01/private_data/`；不在普通 unit/ammunition/weapon 自动扫描目录新增定义。`scripts/bombing/`、`tests/bombing/`、候选及证据目录已有 `.gdignore`，未准入脚本不会在普通根工程成为全局类。
- 检查点时对 417 项公共输入逐项比对，**零变化**；未改普通 BattleOrder/Combat/AircraftTasks/Motion、注册目录、白名单、Session 或入口。没有改 OPS 公共源。
- OPS 更新收到后，明确复制最终 r11 的 OPS/CV01/夹具依赖到 `candidates/bomb01/ops_frozen/`，49 项清单在 `ops-inputs.json`。来源 input-manifest SHA256 `5adf29bb535e63e9d4f5698bb7a7a0ee9ad7ebb886478dda2171f4d581052607`。这是后续组合依赖，未替换 BOMB 初始公共基线。

## 已写入的实现（均属候选）

- `scripts/bombing/ballistics.gd`：无制导重力及密度修正的二次阻力预测；预测不修改弹体，不查询敌方 UnitState。
- 弹药候选显式区分 `gun` 和 `gravity_release`，重力释放允许且要求零炮口速度，原炮弹仍要求正初速。炸弹有质量、阻力、保险时间/路径距离、触发延时及寿命字段。
- CombatProjectiles 增加明确 `release_bomb`；出生 tick 不推进，沿原 CombatFrame/CombatGeometry/MAP02 TerrainQueries 首次接触，继承母机实际线速度。保存首次接触/保险信息，已触发延时不再继续检测其他目标；事件为 `bomb_released`、`bomb_contact` 和实际终止/`bomb_explosion`。
- CombatDamage 候选让重力弹不重复走炮弹直击伤害；同一爆炸按每实体最近代理一次曝光，复用原 `_apply`，有距离衰减、实体/同源地形/建筑遮挡及 friendly_fire 开关。装饰建筑不产生虚构健康或摧毁统计。此路径尚未用专项测试证明。
- `stores.gd` 是唯一有限挂载扣弹者，使用实际本机挂点、逐槽库存、固定投放间隔和单 tick 请求；真实飞行后（priority520）释放，取消撤销请求。D4Y 挂点按原摆架轴变换计算；低空/甲板不允完全摆出。G4M 为地面拆盖的开放载荷构型，没有伪造舱门。
- `mission_delegate.gd` 写入持续进入、滚入、俯冲/稳定航段、弹列、拉起、脱离、重组和空中返航阶段，真实报告命令进度/原因；空弹、低油、失联、损伤、速度/高度/安全恢复会中止。未接防御枪或狗斗；B-25 仅保留字符串级能力占位，未制造替代模型。
- AircraftMotion 候选沿原力积分，仅在显式 bomb_rack 存在时考虑剩余载荷和减速板阻力，不直接改单位位置或命中结果。
- AircraftTasks 候选有可选 `bombing_delegate` 用于空中独立夹具；OPS 组合另用 `scripts/bombing/ops_task_bridge.gd` 继承冻结 OPS task_bridge，父级 bombing_delegate 保持 null，仅 mission_delegate 路径有效。BombingMissionDelegate 已实际改为继承 CarrierMissionDelegate，类型不再仅靠方法形状；**尚未做实际 OPS 生命周期/可赋值组合测试**。
- 甲板字段已从误用的 `air_operations.on_deck` 改成 `carrier_ops.on_deck`；**尚未做正式 OPS 快照运行验证**。

## 私有型号/弹种数据边界

- SB2C-4：复用已准入模型，单枚名义 500lb AN-M64；当前质量240kg、装药118.84kg为资料选择，具体装填差异仍需原页限定。既有模型是简化500lb级弹体，不宣称精确弹型几何。
- G4M1 1942-07：复用准入模型12个真实挂点，暂用九七式六番陆用弹；名义60kg级与表列124lb≈56.2454kg分开，装药50lb≈22.6796kg。尚需打开原始表页确认选择与引信。没有按12×60kg标题伪造实际质量。
- D4Y2 1944-10：复用真实轴与单枚250kg级示意弹；暂选 No.25 land 数据仍需原始页与构型适用性核实，不能算历史选型已完成。
- 本机飞行性能为独立保守参数，没有给G4M套F6F狗斗；但尚未完成有载荷/高度/功率条件的原始性能表核对。所有阻力、保险时间/距离、伤害半径与换算、减速板效果、航线/投放窗口和多数飞行限制均属工程近似，不能转标 verified。
- 已浏览到的来源与未下载原页见 `docs/references/bomb01/checkpoint-sources.json`。本轮未生成新模型、AI图或音频，无收费/账号步骤。

## 实际验证结果

六次 Godot 调用全部经根 `tools/verify.py` 同一 flock、55s上限和进程组清理；固定版本均为 `4.7.2.stable.official.ed1daf0bf`。完整日志/报告已复制至 `docs/showcase/evidence/BOMB01/checkpoint-20261111/runs/`。

| 运行 | 实际结果 |
| --- | --- |
| `20261111T130009-9b2ee411` | r01导入失败：macOS沙箱不能写Godot编辑器设置。不是候选通过。子进程已清理。 |
| `20261111T130047-5f7f4274` | r01测试失败：候选生成误替换局部变量造成语法错误；已修，失败日志保留。受界限包装退出清理。 |
| `20261111T130131-0341d282` | r02私有导入通过。 |
| `20261111T130202-62fbfc97` | r02测试失败：夹具漏合入既有SB2C战斗profile及typed Array调用；已修，日志保留。 |
| `20261111T130339-e5f50160` | r03私有导入通过。 |
| `20261111T130416-cf18df88` | r03连续攻击测试未通过：三型统一命令都接受并存活；G4M自然投放12枚后走弹列/脱离/返航，SB2C和D4Y均到too_low中止、投放0枚；退出另有8个ObjectDB/6个资源未释放诊断。 |

最后测试使用受控在空初态与合法已知空海训练区，持续150s/型、60Hz原飞行积分，没有导演改位/健康或强迫命中。它只证明当前G4M任务有一次有限投放结果，不构成整套BOMB通过；未验证真实目标伤害/正确性、编队或视觉。全部轨迹/事件在 `checkpoint-20261111/attacks.json`，原文件在 `.local/bomb01/r03/.local/attacks.json`。

**尚未运行**：专门弹道/首触/保险/重复防护/遮挡/友伤/邻近伤害/库存测试、取消/改派/DM优先组合、原炮弹同输入回归、MAP02攻击实测、OPS正式组合、原生截图或≥15fps短片、Chrome。不得把测试文件选入白名单等同于实际跑过。

## 接续优先项

1. 先复查 r03 轨迹，修 SB2C/D4Y 进入几何与投放窗口：当前两型下降到600m下限而没有投弹，真实中止保留，不能用放宽保险/强制命中掩盖。
2. 修夹具退出资源泄漏，再建有意义的机制测试与旧炮弹同输入对照；现有测试总体红灯。
3. 用稳定OPS task_bridge做真实typed delegate安装/accept/reset/step/released各一次的验证，并拒绝把同一delegate同时赋两属性。验证carrier_ops.on_deck拒绝投放，不能只靠高度兜住。
4. 修默认home表达式：初始化axis归一化之前参与`unit.position_m-axis*5000`，默认点可能极远；当前夹具给了显式withdrawal_center，未暴露此错。
5. 水平稳定/俯冲目标向量未应用编队offset，slot计算还有整除/站位语义需核；后续验证实体最小间距、领机更替、弹列直线与各机本地有限库存，不能全部会聚同一点。
6. 验证取消/改派/空弹/损伤/目标丢失/错过窗口/过低/基地不可用的真实状态释放；当前空中return_area完成不代表已落地回收，陆基回收与OPS多机型资格未完成。
7. 完成原始资料与明确参数资格，再验证G4M/俯冲机真实模型挂点显隐、D4Y摆架/减速板同步和≥15fps原生连续证据。组装通过后由S14消费已验收manifest，再做Chrome；不抢公共入口。

## 恢复与清理

恢复时继续使用冻结基线，不将S14后续变化悄悄混入。`python3 tests/bombing/prepare_stage.py r04` 将明确白名单/9项替换/自有文件/冻结OPS/私有参数生成**新**stage；不要覆盖r03。通过根`tools/verify.py --owner BOMB01 --project .local/bomb01/r04 --timeout 55 import`等命令串行验证，macOS运行需现有允许的沙箱外验证权限。

本轮未启动原生渲染、Chrome标签、HTTP服务、FFmpeg或额外聊天/子代理。六次报告的所有12个子进程组均`cleanup_ok=true`，未留运行会话；没有关闭他人进程。检查点保存后停止，不占下一执行名额。
