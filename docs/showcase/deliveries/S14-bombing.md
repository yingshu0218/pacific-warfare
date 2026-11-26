# S14 实际轰炸／截击私有组合交付

2026-11-12。已按统筹授权完成用户体验版准入与普通 `expanded` 构建；最终 S08 长测／性能仍待验。原普通包及被改文件均已备份。本页接续已接受的 [港湾自主阶段](S14-carrier-harbor.md)，不修改其冻结证据，也不将静态飞机检视等同于轰炸或起降系统完成。

## 当前组合与来源

保留的私有工程为 `candidates/s14-bombing/stage`，已准入普通入口 `res://showcase/carrier_harbor.tscn`。当前 R13 冻结清单 `candidates/s14-bombing/evidence/inputs-combination-r13.json`，560 个明确输入，SHA256 `dea38bbf6559714c6f778b8e21ea76e060497b92a0f0430b224c78057593d514`。原生与 Web 证据分别记录实际来源，不将不同轮次冒充同版。

- 继承 S14 自主阶段 R8 的 513 份输入，清单 SHA256 `4dbcafef6ce361aab559ed0ef6529498b65ca4071d710969557619ec2f676942`。
- 按已接受的 BOMB01 r18 清单 `45af9ef0475b7b27972171176f413e6c7089f7a301e1d79248cb79beec4fb5d1`，只取八项共享差异、八份新增轰炸脚本和五份集成 JSON；不导入 BOMB 夹具场景、旧 OPS 副本或整个候选目录。
- 八项共享差异逐项重基到 S14 R8；World 保留显式巡逻时限校验。初始重基记录在 `evidence/shared-rebase.json`；此后 S14 集成改动另见 `evidence/combined-deltas-r13.json` 及逐文件差异，不能将其称为未经修改的 BOMB 原文件。
- `tools/s14_bombing/build_stage.py` 从明确清单恢复；`freeze_inputs.py` 核对 399 份公共基线后冻结。新增回归测试的原文件哈希单列于 `evidence/regression-inputs.json`。

历史尺寸、子型、模型几何、挂点和弹药资料沿已验 AV02/03/04 与 BOMB01 交付；未新增历史性能断言。AN-M64 保持 `us_an_m64_tnt_tm1950` 身份和原资料参数，不沿用 240 千克占位数据。投放窗口、阻力、引信与损伤半径仍为 BOMB 明示的简化近似。

## 普通菜单与执行所有权

原 16 个段落、19 单位训练及港湾／航母／静态检视保留。同一普通段落菜单新增六项：SB2C 俯冲轰炸、D4Y2 俯冲轰炸、G4M1 水平轰炸、B-25J 舰艇轰炸、F6F 截击 G4M1、零战截击 B-25J。任务场景使用实际注册作战单位，静态模型不计作战单位。

美方轰炸目标为真实航行、探测、射击和受损的雪风；日方轰炸目标为 MAP02 真实部署的美军 M1 防空炮组。没有被动泊舰、停火时段、无敌、强制命中／损失或按钟点播放的攻击步骤。程序指挥官基于本方实际接触提交 AI 来源命令，不能读敌方全知视图。

Session 仅装一套 AircraftTasks、AircraftMotion、CombatProjectiles、CombatDamage 和 BombStores。BombingCommander 仅管理轰炸编组；战斗机仍归原 FleetPlanner。OPS 桥接受同一个任务委托；舰载波次、护航与轰炸使用显式任务所有权，实际完成、取消、损失或母舰不可用时释放，不能依靠永久 `human` 来源锁住 AI。手动召回仍为真实用户来源命令。

任务状态、炸弹库存、舱门／摆架／减速板、控制面与战损从模拟读取。可从正常指挥态势查看双方任务和真实执行记录。新场景重置时选择有效单位，消除旧大和详情与“单位已退出”残留。正常 HUD 只保留观看所需的“在空开始 · 返航至撤离空域”。只读镜头追踪实际编队、弹体、弹着与坠机接触，不写单位或战果。

为保留旧 SB2C 整机战损，CombatDamage 为无预切部件配置的飞机建立独立 `coarse_airframe` 终端状态，复用既有终端运动与真实水面接触；不虚构可脱落机翼。静态批处理跳过模型接口直接引用的活动 Mesh，防止门、减速板或挂弹引用被释放；其余静态部件仍批处理。

## 已完成的检查

- 六个实际生产场景：58 项零失败，`combination-r11.json`。D4Y 投放／首次接触 1/1，G4M 24/24，B-25 12/12；F6F 截击 G4M 实际开火 48 次但 G4M 仍投放 24 枚；零战截击 B-25 实际开火 50 次，轰炸机真实损伤中止、投放 0 枚。保留实际结果，不宣称所有截击都阻止投放。
- SB2C 默认移动舰场景因 `too_low` 安全中止，两枚仍在库存，实际拉起／脱离／返航后遭防空击毁。长机 103.72 秒开始坠落、122.12 秒真实落海，僚机 163.52 秒坠落、228.38 秒落海。早期无条件投弹断言失败仍保存于 R1–R4 证据；此场景只验中止与战损，不写成普通投弹成功。
- 近／远、低油、空载和接触丢失：20 项零失败，`variants-r10.json`。近场接触 0.0167 秒、下令 0.0333 秒；远场接触 25.0000 秒、下令 25.0333 秒。其余三项分别产生 `fuel_reserve`、`empty_load`、`target_lost` 且不投弹。接触丢失为独立测试模块明确撤除己方传感输入，不进入运行包；空载只在初始化按显式挂载掩码生成，不由 UI 或运行中测试改写库存。早期“必须延后30秒”的无依据断言失败保留于 R9，后按实际接触因果校验。
- 原弹丸首次接触／保险／遮挡等 14 项、原 F6F/零战 DM 90 项、旧装配 284 项、自主指挥 33 项和实际取消生命周期 6 项均零失败。串行报告 `.local/validation/runs/20261111T170856-cd11f8fe/report.json`；输出与来源绑定 `evidence/regressions-r11.json`。R12 相比 R11 仅增加真实坠机接触后的只读镜头短暂停留。
- 埃塞克斯同两架 F6F 两波次：9 项零失败，`pair-r9.json`。模拟 1727.37 秒，两机各出动2次、回收2次、补给完成、实际存活并待命；有限母舰库存真实扣除。报告 `.local/validation/runs/20261111T165609-6b3298e6/report.json`，来源绑定 `evidence/pair-r9-binding.json`。此项是一艘母舰双机整波，不是双航母作业。
- 原生六场景安装与75个实例投放挂点均通过；R10 截图已确认当前单位详情和相机文字。R7 动态网格引用错误与此前失败记录保留，修复后 R8/R10 通过。R12五段连续片段已完成，全部每帧4个固定tick、15FPS、1280×720、无音轨：B25投放44秒、D4Y投放32秒、G4M投放44秒、B25受截击至僚机落海32秒、SB2C整机落海12秒。源帧、电影和ffprobe帧数/时长见 `evidence/native-movies.json`；连续性与真实事件计数见 `evidence/native-continuity-r12.json`。原生实际查看记录 `evidence/native-visual-review-r12.json`。B25受截击片首帧已在左翼脱落后0.4秒，不宣称其拍到了脱落前后瞬间。R13仅补终态原因翻译及空原因/未知非空原因兜底，原生不重复录制；Chrome检查最终翻译。

## 用户体验版准入与启动

统筹授权记录 `docs/showcase/acceptance/S14-bombing-preview-admission.json`。按 `evidence/public-change-plan.json` 的77项逐路径变更落公共文件，535份正式白名单，139份新准入；根 `project.godot`、`export_presets.cfg` 和旧 `all` 别名保持原值。实际准入记录 `evidence/public-admission.json`。普通builder首次正确拒绝了旧 `scripts/bombing/.gdignore`：该目录仅有八份已准入且哈希一致的脚本，备份空标记后取消隔离，使白名单生效；没有额外导入候选目录。

普通包已构建于 `build/first-playable`，入口 `res://showcase/carrier_harbor.tscn`。535份根来源均与R13白名单完全一致，原始JSON按明确文件名导出。旧普通包9产物及旧manifest备份于 `candidates/s14-bombing/evidence/public-before/build/first-playable`；源码备份仍保留于同一 `public-before`。私有审查包 `build/s14-bombing-review-r13` 保留。

在仓库根执行：

```sh
python3 tools/run_first_playable.py web --scene expanded
```

随后在 **Chrome** 打开 `http://127.0.0.1:8765/index.html`。需要重建时加 `--build`；Ctrl-C关闭本次服务器，默认最多运行3600秒。正常菜单可见 `SB2C · 俯冲轰炸`、`D4Y2 · 俯冲轰炸`、`G4M1 · 水平轰炸`、`B-25J · 舰艇轰炸`、`F6F 截击 G4M1`、`零战截击 B-25J`；港湾、静态检视、F6F单机／双机整波及原16段落继续可选。

普通构建清单 SHA256 `82d0c4074925f35f985d735a946ea33d25c57b3d508e92efc50127b41df6ec00`；`index.pck` SHA256 `3455f5c834a77e4af7941a3d6a2be6dc6087b480feea248b8a89eb6ee94d7cd9`；HTML SHA256 `bc8fbd5b372ad6510603080d3db3aae5cca18cf3a7e86d70e17180c40fe3307e`。完整产物哈希及构建报告在 `evidence/ordinary-build-r13.json`。

## Chrome与最小启动验证范围

Browser插件不可用，沿用项目既有Playwright回退与真实Google Chrome157.0.8103.39，Apple M5／16GB、Metal WebGL2、1280×720、DPR1。未启用Safari。私有候选 `chrome-review-r13/run.json` **整体未完成／passed=false**：82项已记录检查均为通过，但最后零战截击B25的等待断言超时，之后的原训练步骤未执行。原脚本只接受`pullout + combat_damage_abort`；实际事件在4.45秒为`pullout + damage_abort`，长机之后实际返航、155.05秒以`all_assignments_released:damage_abort`终结任务且余6枚，僚机79.83秒落海。没有据此修改单位或战果；脚本已修为接受实际原因，按体验优先不再重跑整套。

此轮实际普通菜单已进入六任务，B25/D4Y/G4M真实投放与首次接触、SB2C真实安全中止及落海、两组战斗机真实开火、双方指令面板、暂停/2倍/4倍/声音/重开和终态原因中文均有记录。页面异常、相关控制台错误均为0；不将82项或观察到的状态写成整轮Chrome通过。点击命令会按正常行为定位该编组/目标，因此该轮B25弹着截图处于用户自由观察；自动镜头的关键近景以R12原生证据证明。后续S08应按真实中止阶段和订单终态验收，并补完未执行检查。

准入后的最小普通启动 `ordinary-smoke-r13/run.json` 通过，报告 `.local/validation/runs/20261111T172651-d5460d14/report.json`。检查 ordinary 页面身份、1280×720、硬件WebGL、23单位/30菜单项、普通菜单B25实际双机与各6枚库存、真实AI轰炸指令、暂停及无脚本/浏览器错误；只读观察器由测试临时注入，普通构建文件没有测量脚本。截图 `ordinary_expanded.png`、`bombing_visible_menu.png`、`ordinary_b25.png`。本项只证明普通启动与交互，不证明长时间和性能。

本轮测试Chrome、HTTP服务、临时profile及Godot/ffmpeg预览均按所属进程清理；清理审计另列 `evidence/cleanup-preview-r13.json`。用户体验服务器未由测试留下。后续既有S08的普通组合包长测、最终性能与本页能力边界仍待验，未因提供可体验版本而宣称完成。

## 能力边界

未完成／未验收的能力为：防御枪火控与库存、双发逐发动机独立故障、SB2C预切部件、G4M/B25动态陆基起降、SB2C/D4Y实际舰载作业、翔鹤与日机动态起降。现有新轰炸场景从在空初态开始，返航是撤离空域，不是完成着舰／着陆。只有 F6F 在埃塞克斯上的既有整波作业进入本轮循环验证。本交付不将 T27 或完整航空循环整体标为完成。
