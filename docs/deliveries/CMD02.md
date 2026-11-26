# CMD02 双指挥官与观战态势

2026-11-19。默认港湾机制与 720p 原生界面通过，源码已冻结。普通 Web 导出、Ego Lite 操作及性能复核由统筹验收。

## 签发与决策

- 日美双方各有舰队和航空岗位，签发身份分别为 `jp_fleet_commander`、`jp_air_commander`、`us_fleet_commander`、`us_air_commander`。舰队岗位调度舰艇，航空岗位调度战斗机编队并签发既有的三项轰炸目标。普通人工来源和岗位共用 `submit_order` 的校验、固定步长分发及执行回报。岗位命令校验阵营、受令域与现有任务所有权，分发时复查，避免同一仿真步排队的程序命令覆盖已接收的人工任务。甲板作业、训练、独立任务、撤退和已承诺轰炸受保护。
- 默认港湾对四个岗位启用自动姿态。每六仿真秒独立评估各自可调兵力、损耗与相关的己方接触。进攻扩展接敌范围，并提高已识别重型舰的优先级。平衡使用常规防御范围。保守优先保护核心及编队，收紧拦截范围，并暂缓尚未派出的轰炸任务。执行中的合法拦截保留原订单和双机成员，轰炸继续走攻击、离架、脱离与返航执行链。姿态至少保持两个决策周期，升级及降级阈值分开。
- 既有配置未提供姿态时沿平衡规则运行。场景可按阵营通过 `fleet_overrides.commanders.<faction>.postures` 分别设置 `fleet` 和 `air` 为 `auto`、`offensive`、`balanced` 或 `conservative`。共用记录为 `world.shared_state["command_postures"][faction][post]`，含 `posture`、`reason`、`issuer_id`、`changed_tick`。舰炮分配消费该记录，继续由 GUN01 负责。
- 普通观战的「指挥态势」同屏显示四个岗位、当前姿态和原因。双方有效命令可各自滚动，时间线显示签发人、受令对象、目标及真实状态变化。选中舰艇可看到主炮、副炮、两用炮和防空炮的实际分配目标或待命等状态，依据炮位角色与 `mount_targets`、`mount_status`。原有 Web 只读探针提供姿态和选中单位摘要，并转发真实 `airburst`、`surface_impact` 事件。

## 同一态势的执行差异

受控验证逐轮使用相同敌我初始态势和接触记录。下表依据已分发且执行中的订单。

| 姿态 | 舰队旗舰任务 | 航空出动和预备队 |
| --- | --- | --- |
| 进攻 | 接敌较远的重型舰 | 两组双机分别拦截轰炸机与敌战斗机 |
| 平衡 | 接敌较近的水面舰 | 一组双机拦截轰炸机，两架保持掩护 |
| 保守 | 区域巡逻 | 四架保持掩护 |

自动验证覆盖无接触进入平衡、有接触升级、兵力不可用导致单岗位降级、可用飞机回归后恢复进攻，以及重开后的确定性。正常港湾同一初始目标下，美方基准在第 2 tick 派两项轰炸。控制本方战斗机被占用后，航空岗位保守，暂缓两项新轰炸。解除占用后，第 722 tick 按仍可用的成员和接触重派并执行，先前已承诺的 SB2C 任务在降级时保留原订单。人工巡逻在共用入口接收并进入执行，排队竞争及随后提交的岗位任务都未夺取其所有权。

## 普通港湾回归

新炮组分配接入后的首次采样中，一架 G4M1 受损中止，另一架错过释放窗口。把两架的初始点沿原进场方向平移 2,020 米，为进入投弹航段留下时间。更改限于港湾初态，S14 独立轰炸与拦截场景、装备和火控参数沿用原配置。

正式 AIR01 场景回归跑满 90 仿真秒，24 枚 G4M1 炸弹均有对应的真实离架、接触与爆炸事件。首个投放约在 21 秒。零战对 B-25J 实际开火 194 发，战斗机对战斗机共 229 发，双方均有实弹记录和实际机动。美方 B-25J 受损，SB2C 在目标失联后返航。自动电影验证覆盖水面交战、投弹、弹着、截击及狗斗。统筹的 95 秒合并采样也得到完整 24 枚弹体链，记录了三种自然姿态和四个签发身份，高层派令拒绝为 0。调整前出现过一次失效舰艇接触拒绝，未形成反复提交。 [AIR01 原始采样](../showcase/evidence/CMD02/air01-headless.json)

## 验证记录

Godot `4.7.2.stable.official.ed1daf0bf`，由 `tools/verify.py` 共用锁串行执行。

| 检查 | 结果 | 共享验证记录 |
| --- | --- | --- |
| CMD02 决策、权限、命令和真实保守延迟任务 | 37 项通过 | `.local/validation/runs/20261119T082041-a278d7c4/report.json` |
| CMD01、命令链、接触和 AIR01 锁定回归 | CMD01 23 项及接触 10 项通过，命令链和锁定脚本通过 | 同上 |
| S06 旧指挥与确定性回放 | 19 项及 13 项通过 | `.local/validation/runs/20261119T081834-f09234d5/report.json` |
| 正式 AIR01 默认港湾 90 秒 | 通过，运行约 57.5 秒 | `.local/validation/runs/20261119T081556-c1c3d381/report.json` |
| 原生 1280×720 正常界面 | 17 项通过，截图后退出 | `.local/validation/runs/20261119T081949-b3fad55a/report.json` |
| 正式港湾快速重开及订单回归 | 观战 25 项、CMD02 机制 37 项通过 | `.local/validation/runs/20261119T084832-b1d30cea/report.json` |
| headless 导入 | 通过 | `.local/validation/runs/20261119T081946-031c0fe8/report.json` |

[720p 指挥态势](../showcase/evidence/CMD02/720p-command.png) · [720p 舰炮目标摘要](../showcase/evidence/CMD02/720p-harbor.png)

## 交付路径

新增运行文件及运行 UID 均为零。以下 13 份既有运行文件已冻结，当前工程无 Git。接手备份为 `.local/repairs/20261119_dual_command/before`，本任务冻结副本为 `.local/repairs/20261119_dual_command/CMD02-frozen`。 [逐文件 SHA-256](../showcase/evidence/CMD02/source-sha256.json)

- `data/scenarios/s14_expansion_harbor.json`
- `scripts/bombing/commander.gd`、`scripts/bombing/mission_delegate.gd`
- `scripts/command/commander/fleet_commander.gd`、`scripts/command/commander/fleet_planner.gd`
- `scripts/game/first_playable_session.gd`
- `scripts/showcase/all_units_showcase.gd`、`scripts/showcase/expansion/web_probe.gd`
- `scripts/simulation/ship_motion/fleet_config.gd`、`scripts/simulation/simulation_world.gd`、`scripts/simulation/state/battle_order.gd`
- `ui/observer_hud.gd`、`ui/observer_text.gd`

新增测试为 `tests/test_cmd02.gd`、`tests/test_cmd02_observer.gd`，包含两份对应的 `.gd.uid`。运行准入清单与统筹开发清单保留原文件。

## Web 启动说明补充

`tools/serve_first_playable.py` 在绑定后按实际端口生成 Ego Lite 地址及 Ctrl-C 停止提示。`tools/run_first_playable.py` 将该提示显示在当前终端。已检查两份 Python 文件的语法，并以模拟绑定验证默认、自定义和系统分配端口的提示。普通入口实启由统筹校验。这两份交付工具独立于上述游戏源码冻结清单。

## 快速重开修复

Ego Lite 发现战斗运行一段时间后重开时，新局尚无订单，HUD 因订单签名相同而留着旧卡。重开现在同步清空双方指令卡、时间线和选中详情。指令卡按当前观战场次与订单 ID 读取快照，过期的指令卡和时间线回调即使碰到复用的订单 ID 也会被忽略。

正式港湾回归推进到大和的真实指令在上一局第 3,904 tick 更新，然后经「重开」在同一帧尝试触发旧按钮。重开时双方旧按钮消失，第 6 tick 仍没有可点的旧舰队命令。新局第 34 tick 点击第一条舰队命令时复用了 `fleet_ai:jp:0001`，下达、接收和最近变化均为第 2 tick。更新后的交付清单和冻结副本只替换 `ui/observer_hud.gd` 和 `tests/test_cmd02_observer.gd` 的版本，普通 Web 包由统筹重建并复验。
