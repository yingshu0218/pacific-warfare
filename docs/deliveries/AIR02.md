# AIR02 自主立体飞行

## 观战读取契约

从单位快照读 `module_data.aircraft_motion.autonomous_maneuver`。未进入过本轮新增动作时没有此键。同一单位的 `sequence` 随动作起步递增，战局重开后从 1 开始。镜头可以用 `(战局 generation, 单位 id, sequence)` 识别同一次动作。

| 字段 | 含义 |
| --- | --- |
| `kind` | `rising_arc` 上升弧转、`bank_reversal` 反坡度转弯、`axial_roll` 轴向滚转、`oblique_roll_arc` 斜向滚转弧 |
| `phase` | `enter` 进入、`sweep` 弧转、`reverse` 反向、`rotate` 滚转、`recover` 收姿 |
| `status` | `executing` 执行中、`completed` 已满足航迹及收姿条件、`aborted` 中止 |
| `reason` | 执行中为空。完成为 `geometry_complete`。中止记录安全恢复、受损、超时、友机避让或任务释放等原因 |
| `started_s`、`ended_s` | 模拟秒数。执行中 `ended_s` 为 −1 |
| `entry_position_m`、`position_m` | 开始、最近采样时实际世界坐标，类型为 `Vector3` |
| `heading_change_rad`、`body_roll_rad`、`height_change_m`、`path_length_m` | 从开始至最近一次行为采样的有符号航向变化、积分轴滚、高度变化及沿真实航迹的累计路程 |
| `peak_gain_m`、`arc_turn_rad`、`initial_turn_rad`、`opposite_turn_rad`、`peak_roll_rad` | 峰值上浮和各动作实际达成的方向性幅度 |
| `peak_lateral_offset_m`、`height_span_m` | 相对入口水平切线的最大侧向偏移，以及动作高度极差。斜向滚转弧须实测达标并完成收姿 |
| `next_entry_distance_m` | 飞机累计路程达到该值后才可酝酿下一次动作，供诊断 |

用于实时标签时，检查单位仍在飞行、未进入终端损伤、`status == "executing"` 且安全控制仍为正常。终态快照保留至下一次动作开始。镜头构图可直接读已有的 `forward_m`、`lift_up_m`、`path_pitch_rad`、`bank_rad`、`body_angular_velocity_radps` 和呈现快照的位置、速度。动作字段来自固定步长任务执行器，采样时点可能领先插值画面一个模拟步。

## 行为和场景

只有执行接战或拦截、且本方接触已识别为战斗机时，航空任务执行器才把已有方向请求交给立体飞行分支。持续升转、大幅换向请求、带坡度回到近水平的请求分别可以触发相应动作。自机的速度余量、离地高度、当前姿态、受损和回收状态决定是否接受。直线平飞可以持续任意距离。结束后的距离门槛只限制重入。

转弯接入既有协调飞行控制。滚转通过同一个积分器逐步移动升力方向，沿用机型滚转速率、载荷、失速及地形恢复。所有完成条件都先检查实测航迹，再等待坡度、航迹仰角和滚转速率回到收姿窗口。斜向滚转弧须实际转过 348°、侧移至少 130 米、高度极差至少 160 米。

同一 AI 指挥官续发同目标、同类型、同意图和同航路的任务时，执行器可保留连续的动作编号与实际进度。目标、任务、路线、命令来源改变时，由新命令接管。友机避让、地形、能量、失控和退出继续使用原优先级。

普通港湾使用既有初态。单机自主空战观察把巡航双机与日方二号双机放在港外双方现有航空指挥能更早发现和接战的范围，更新四架飞机的初始位置、速度和航向。其余飞机、航路、指挥规则、装备和训练入口沿用原配置。

## 验证方式

Godot `4.7.2.stable.official.ed1daf0bf`。以正式 `FirstPlayableSession` 和各入口的正式任务模块启动，在每个场景按 60 Hz 推进 105 秒。每十个模拟步记录正在交战的健康战斗机航迹，动作阶段与终态逐步采集。8 秒高度极差使用与统筹基线相同的统计口径。单机段前后对比同时反映初态变化。训练、友机间距、射击、伤损及弹着由现有回归和真实事件核对。

```sh
python3 tools/verify.py --owner AIR02-replay --timeout 185 --lock-timeout 240 \
  godot -- --script res://tests/test_air02_autonomous_motion.gd -- /tmp/air02-707.json 707
python3 tools/verify.py --owner AIR02-replay --timeout 185 --lock-timeout 240 \
  godot -- --script res://tests/test_air02_autonomous_motion.gd -- /tmp/air02-1707.json 1707
```

### 同种子对照，707

| 正式入口 | 机型 | 旧版／新版 8 秒高度极差 P90 | 旧版／新版最大 8 秒高度极差 |
| --- | --- | ---: | ---: |
| 默认港湾 | F6F | 220.38／247.61 m | 436.89／323.26 m |
| 默认港湾 | A6M | 280.25／273.77 m | 365.67／322.18 m |
| 单机自主空战观察 | F6F | 271.01／473.78 m | 351.06／492.23 m |
| 单机自主空战观察 | A6M | 305.57／374.43 m | 345.80／469.81 m |

旧版和新版都有明显升降。普通港湾 A6M 的常态 8 秒极差没有提高，港湾两型的最大 8 秒局部极差均下降。新版斜向滚转弧和上升弧转的侧向位移按完整动作单独统计，统计窗口不会计入脱离接战、伤损或跨越 8 秒窗口的全部动作。 [707 旧版统计](../showcase/evidence/AIR02/707-before-summary.json) · [707 新版统计](../showcase/evidence/AIR02/707-after-summary.json)

| 入口与飞机 | 完整动作 | 起止模拟秒 | 实际高度极差 | 入口切线侧移峰值 | 实际动作幅度 |
| --- | --- | ---: | ---: | ---: | --- |
| 港湾 F6F `us_air_4` | 轴向滚转 | 5.38–15.25 | 449 m | 58 m | 转过 348.3° |
| 港湾 F6F `us_air_3` | 上升弧转 | 60.57–75.28 | 404 m | 958 m | 转向 125.2°，全程飞过 1,457 m |
| 港湾 A6M `jp_air_4` | 斜向滚转弧 | 40.40–51.47 | 207 m | 470 m | 转过 348.9°，收平 |
| 港湾 A6M `jp_air_4` | 斜向滚转弧 | 65.75–76.60 | 234 m | 547 m | 转过 348.1°，收平 |
| 自主观察 F6F `us_pair_demo_1` | 轴向滚转 | 1.42–11.68 | 542 m | 41 m | 转过 348.2° |
| 自主观察 A6M `jp_air_3` | 轴向滚转 | 20.40–30.87 | 520 m | 99 m | 转过 349.0° |

单机段 F6F 另有一次斜向滚转弧于 24.03 秒因正式命令从拦截切换为撤退而中止。默认港湾有 F6F 已达到 348° 滚转、仍在收姿时失去任务接触的中止。两者均保留真实中止，按完成次数统计时剔除。

普通港湾 105 秒仍有 120 发战斗机互射、144 发战斗机对轰炸机开火、24 组炸弹离架—接触—爆炸。旧包相同窗口分别为 229、75、24。独立段实际互射计数由 24 增至 64。新增机动期间单次 60 Hz 模拟步的最大四元数轴角变化在两段分别约 1.115° 和 1.095°。

原始航迹、姿态、命令替换及发射/接触事件保存在 `.local/repairs/20261119_aerial_motion/air02/final-707.json`。旧包原始轨迹在同一父目录的 `before-observation.json`。

### 第二种子与定向回归

1707 的默认港湾中，F6F 完成轴向滚转，A6M 完成 124.4° 上升弧转，高度极差 351 米，侧向偏移 712 米。单机观察中，两型完成轴向滚转，F6F 在 21.27–32.28 秒另完成斜向滚转弧，转过 349.0°，高度极差 232 米，侧向偏移 575 米。默认港湾仍有 24 组实弹离架、接触及爆炸。 [1707 统计](../showcase/evidence/AIR02/1707-after-summary.json) · [707 动作与订单](../showcase/evidence/AIR02/707-maneuvers.json) · [1707 动作与订单](../showcase/evidence/AIR02/1707-maneuvers.json)

两个 105 秒常规样本内无反坡度转弯完成记录。定向初始化用例提供相反的方向请求，由同一积分器完成实测反坡度转弯。F6F 两段实际转向 29.1°／52.1°，高度极差 198 米，侧移 393 米。A6M 两段为 29.0°／52.2°，高度极差 175 米，侧移 336 米。用例还验证平飞跨越冷却距离、方向请求切换、低速拒绝、低空中止，以及实际续令、换目标和重开时的快照语义。

冻结运行文件通过 9 份旧回归脚本，覆盖运动积分、地形避让、F6F 姿态、双型号训练及中止、任务分配、真实战损、2v2／4v4 与目标锁定。2v2 发射 263 发、4 次命中并损伤、5 次再接敌。4v4 发射 220 发、4 次命中并损伤、21 次再接敌。战斗回归 31 项通过，包含实际弹药消耗、双方分组与重开确定性。训练与训练安全分别通过 52 和 68 项。四份 AIR02 验证报告的 Godot 子进程组均已清理。 [验证记录](../showcase/evidence/AIR02/validation-summary.json)

### 冻结交接

| 路径 | 改动与 UID |
| --- | --- |
| `scripts/behaviors/aircraft/aircraft_tasks.gd` | 改动。既有 `aircraft_tasks.gd.uid` 为 `uid://dcss0afgge7ic` |
| `scripts/behaviors/aircraft/autonomous_fighter_motion.gd` | 新增，与 `autonomous_fighter_motion.gd.uid` 一同入包，`uid://dcychqodphpfu` |
| `data/scenarios/s14_maneuver.json` | 改动，四架飞机初态 |
| `tests/test_air02_autonomous_motion.gd` | 新增验证脚本及 `test_air02_autonomous_motion.gd.uid`，`uid://c10n1eoonj63h` |

当前工作目录无 Git 仓库。按文件冻结 SHA-256，副本位于 `.local/repairs/20261119_aerial_motion/air02/frozen`。Web 打包、浏览器及镜头体验由统筹合并验收。 [源码 SHA-256](../showcase/evidence/AIR02/source-sha256.json)
