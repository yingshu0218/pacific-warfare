# S04 立体空战与 F6F 机动修正交付

2026-11-10。**v3 原生自验完成，交统筹独立复验；不代表整个 Showcase 或 Chrome 最终验收完成。** Godot 固定为 `4.7.2.stable.official.ed1daf0bf`，Compatibility。航空运行代码及相关生产输入已冻结，清单见 [production-inputs.json](../evidence/S04-spatial/production-inputs.json)。

## 先看连续实飞

| 片段 | 内容与范围 | 录像 |
| --- | --- | --- |
| 4v4，F6F `us_3`，88–106s | 受控初态与交战指令之后自主飞行；真实尾追触发，滚转倒置→正载荷半圈→改出。固定世界朝向镜头只平移 | [18秒完整动作](../evidence/S04-spatial/f6f-v3-split-final-native.mp4) |
| 4v4，F6F `us_0`，40–56s | 后跟随机位；目标横穿原转向后反向滚转，实际对准后拉杆急转 | [16秒后视](../evidence/S04-spatial/f6f-v3-reversal-native.mp4) |
| 正式岛港，`us_air_2`，66–96s | 使用真正的 `FirstPlayableGame`、HUD 和默认42m跟随距离；正常观战中的接敌、拉升、俯冲与调整 | [30秒正常观战](../evidence/S04-spatial/f6f-v3-observer-native.mp4) |
| 正式岛港，`us_air_4`，152–178s | 与反馈前同机、同时间窗口；当前高位掩护平稳飞行，对照此前反复抬低头与恢复切换 | [26秒同窗口](../evidence/S04-spatial/f6f-v3-current-native.mp4) |

四段共1350帧、15fps，均实时推进固定tick世界，无指定飞机姿态、位置轨道、命中或损伤。录像无音轨。自定义镜头保持世界向上；后视镜头只有限速地跟随水平航向，在近垂直时保持航向。正常观战片段直接消费正式场景的状态与相机，不修改其实现。原生帧、每秒状态、帧hash与编码检查见 [native-captures-v3.json](../evidence/S04-spatial/native-captures-v3.json)。

轨迹审计确认四段捕获与终版固定步长记录对应；因原始轨迹按0.25s取样，用位置插值核对时最大偏差0.179m。插值仅用于核对，没有用于录像或模拟。[审计记录](../evidence/S04-spatial/f6f-trajectory-audit.json)

## 修复的原因与实际行为

原行为把持续爬升率直接变成瞬时俯仰上限，战斗速度下约7°，主要水平追逐。保留的120s基线中，八机累计超过15°航迹俯仰的时间为0。

首轮v2虽然有高度变化，却被用户和统筹退回：大坡度下长期卸载甚至负载荷；目标在身后时三维最短弧可能向上绕；归队、安全恢复与追瞄会交替夺取控制；±78°限制也阻止倒置。原始v2源码、曲线和录像保存在 [v2-before-f6f-calibration](../evidence/S04-spatial/v2-before-f6f-calibration/source-hashes.json)。早期 `f6f-v3-split-native.mp4` 是控制优先级修复前的中间证据；本交付使用表中的 `split-final`。

终版普通引导分别处理航向与航迹俯仰，再求协调的升力方向、坡度和可用载荷。滚转以有限角加速度/角速度运输实际机体上方向；升力和重力改变真实速度，推力、阻力、重力交换速度与高度。目标在身后不再通过错误上仰绕近路。持续爬升只约束可供发动机功率；短时拉升消耗动能。

F6F的防御机动使用实际机动平面与正载荷请求，按真实滚转对准、航迹转角和安全条件推进，支持大坡度急转、反向滚转与有余量的半滚倒转。已开始的安全规避保持控制权到完成，僚机站位或短时接触变化不在滚转中途抢回控制。危险、撤退、取消/改派或友机避碰可中止；冷却保存在本机，清空任务/接触记忆不能绕过。大角度动作由情境触发，零战仍采用其自身性能与战术选择。

升降舵由实际正/负载荷驱动，倒置或越过垂直时不会因世界俯仰角的符号变化反向。模型、碰撞代理与固定炮口仍消费统一权威姿态；射击继续使用S05实际炮口、弹道、首次碰撞和库存。

## 速度、过载和连续性证据

4v4实际 `us_3` 在90.9667s开始滚入，93.9167s转入拉杆，103.2s完成；真实飞行方向改变165.63°，最低航迹俯仰−84.00°，最大本体滚转60°/s，最大实际航迹曲率22.21°/s，末段俯仰−6.59°。倒置拉杆时有实际正载荷，动作随速度改变可用过载，并未将5.5g当作所有速度都可用。

- [速度／俯仰／滚转率／载荷／曲率](../evidence/S04-spatial/f6f-v3-split-curves.png)
- [同尺度三维真实航迹](../evidence/S04-spatial/f6f-v3-split-trajectory.png)
- [反馈前后同机同时间窗口](../evidence/S04-spatial/f6f-v2-v3-same-window.png)

同窗口图也反映自治战术结果变化；控制器由独立机制检查验证：同高度背后目标最大航迹俯仰1.14°；65°稳态转弯在约107–110m/s时半径547–575m，与 `g*tan(bank)/V` 的最大相对差约0.0068%。受控半滚倒转通过近垂直姿态，完整三维姿态单tick变化约1.01°，没有姿态跳变。这些是受控检查结果，不是历史最大机动性能宣称。[F6F机制数据](../evidence/S04-spatial/f6f-coordination.json)

## 原行为及自然交战

原海面场景采用同一 `first_playable.json` 初态，分别记录原行为与终版120s；终版另延长到240s。当前岛港通过正式场景的 `scenario_path` 装配。2v2/4v4是同高度受控接敌，之后由航空规则自主执行，均使用正式S05。

| 案例 | 秒 | 航空开火／命中事件 | 最小友机距m | 累计俯仰绝对值超过15°机秒 | 最低活动飞机速度m/s |
| --- | ---: | ---: | ---: | ---: | ---: |
| 原行为，原海面 | 120 | 92／10 | 11.68 | 0.00 | 45.21 |
| v3，原海面 | 120 | 64／8 | 58.35 | 48.42 | 77.25 |
| v3，2v2 | 160 | 186／10 | 201.18 | 128.20 | 69.51 |
| v3，4v4 | 160 | 459／40 | 73.53 | 287.73 | 78.06 |
| v3，原海面 | 240 | 64／8 | 58.35 | 56.63 | 77.25 |
| v3，正式岛港4舰8机 | 240 | 43／6 | 58.35 | 50.43 | 73.77 |

命中为实际事件，战果可随行为改变；没有修改武器、弹药、伤害或初始位置制造效果。终版各例开火数与实际库存消耗一致，记录的航空友伤为0。原基线没有细分敌我命中字段，因此表格统一列总命中事件。机秒为所有活动飞机的累计时间，不是场景秒数。机制记录可继续推进到240s，正常观战的结束/暂停仍由正式Session判定。

[完整指标与结束原因](../evidence/S04-spatial/metrics.json) · [原行为图](../evidence/S04-spatial/standard-before.png) · [终版同为120s图](../evidence/S04-spatial/standard-after-120s.png) · [当前岛港图](../evidence/S04-spatial/current-after.png)

前后全场三维图使用相同X/Z范围±12km、高度0–4km、正交镜头及实际物理轴比例；局部倒转图各轴统一km且同物理比例，没有竖向夸张。原始样本、真实阶段切换、油量、能量和结束原因保存在各 `*-after.json`。

## 物理校准与史料边界

历史基础极速、持续爬升、服役信息、基准质量与武装均保持原值，终版与v2存档的非spatial性能字段逐项相同。新增操作参数是明确的游戏近似。

诱导阻力依据 `Cdi=Cl²/(πeAR)` 推导，以原有1g平飞阻力为基准增加载荷引起的增量：`Δa=2mg² max(n²−1,0)/(πe b²ρV²)`。使用既有质量和翼展，`e=0.8`是明示估计；F6F在海平面100m/s、3g的增量约1.66m/s²，原经验式约3.20m/s²。不是为了达标任意降低阻力。[NASA原理](https://www1.grc.nasa.gov/beginners-guide-to-aeronautics/induced-drag-coefficient/)

已打开本地原始AN01-85FB-1扫描，核对印刷29/34/38/57/59页的操作边界、特技、失速与载荷图。保守采用260kt全副翼边界与滚转+5g约束；1947手册的后期改装不自动套用1944子型。原60°/s估计滚转率没有提高。F6F-3 NACA试验没有当成精确F6F-5曲线。[手册扫描](https://fredhaise.space/docs/career-paths/F6F_Pilot_Handbook.pdf)

F6F翼面334ft²及翼展42ft10in与既有模型基准相符，用于校核；零战采用既有11m翼展和2740kg质量。同一关系保留质量/翼展/失速速度造成的能力差异。[美国国防部／海军资料](https://www.denix.osd.mil/legacy/denix-files/sites/33/2021/12/U.S.-Navy-Shipwrecks-and-Submerged-Naval-Aircraft-in-Washington-An-Overview-Report-1996-Legacy-98-0856.pdf)

仍是零侧滑、零迎角的点质量和受限操纵近似；没有完整气动极线、翼型/螺旋桨滑流、尾旋、WEP热限制、燃油质量变化或驾驶员生理模型。安全余量、控制增益、滚转加速度和效率估计均在性能数据与代码中明示。

## 地形与命令审计

航空直接使用S09的 `TerrainQueries.height_m` 与 `segment_hit`，提前查询并以有限转弯/爬升避让；实际前后位置再扫掠，真实接触交给S05。冻结地图hash为 `6327c444e480e19be73bdbe75cc0b90e31f974c5ec2fcf765a5926d7a70f6678`。40s山脊案例最低余高177.66m、接触0次；不可避免撞地/撞房各产生一次真实surface接触及一次S05撞击结算，不误报成触海。[地形数据](../evidence/S04-spatial/terrain-safety.json)

v2拒绝审计保留完整请求：[rejections-before-fix.json](../evidence/S04-spatial/rejections-before-fix.json)。航空失效后清目标是无用命令，已改为只清自身控制/开火意图；舰艇同类问题由S09所有者修复。24.033s的舰队指挥官请求来自己方尚fresh但已滞后的接触，S01真实校验拒绝，属于正常情报滞后；没有让AI读敌方实时active，也未放宽校验。终版记录各例拒绝为0，完整分组及请求仍由记录器保存。

## 检查、复现与交接

| 检查 | 结果与覆盖 |
| --- | --- |
| F6F协调飞行17项 | 背后目标、解析转弯、真实倒置拉杆、连续姿态、低空禁止、跨记忆冷却、升降舵方向 |
| 立体运动5070／战术33项 | 动能换高、无动力能量、斜向转弯、失速/低空、近垂直、情境选择及中止 |
| 自然交战64／原航空交战26项 | 2v2、4v4、原场景、正式岛港；真实枪口/命中/库存、间隔和退出 |
| 原任务40／模型38／原飞行17项 | 护航、归队、接替、失联、低油/无弹/损伤、取消/部分改派及正式活动轴/炮口 |
| 全状态回放8项 | 4v4延长到110s，覆盖倒转完成；当前岛港40s。重置、30fps/不规则帧、暂停/2倍速、真实效果开关下，全模拟状态与全部事件一致 |
| 同源地形27／S01命令／S05炮战69项 | 扫掠分类与结算、命令权限/幂等/生命周期、原真实弹道回归 |

检查使用真正失败退出，不屏蔽Godot错误。调试失败、超时或锁等待的原报告仍保留；终版通过报告及日志索引见 [validation-runs.json](../evidence/S04-spatial/validation-runs.json)。

```sh
python3 tools/verify.py --owner S04 --timeout 60 import
python3 tools/verify.py --owner S04 --timeout 120 test res://tests/test_f6f_coordinated_flight.gd res://tests/test_aircraft_spatial_combat.gd res://tests/test_aircraft_spatial_replay.gd
python3 tools/verify.py --owner S04 --timeout 90 godot --render -- --minimized --resolution 1100x700 --script res://tests/aircraft_spatial_capture.gd -- --case=four --follow=us_3 --start=88 --duration=18 --view=world --output=res://.local/S04-f6f-v3-split-final-frames
python3 tools/verify.py --owner S04 --timeout 90 godot --render -- --minimized --resolution 1280x720 --script res://tests/f6f_observer_capture.gd -- --follow=us_air_2 --start=66 --duration=30
python3 tools/verify.py --owner S04 --timeout 30 exec -- python3 tools/audit_f6f_traces.py
```

控制/状态与新增phase/reason已公布在 [航空契约](../../aircraft-contracts.md)。主改动是 `aircraft_motion/`、`AircraftFlightController`、`AirCombatTactics`、`AirCombatManeuvers`、航空任务/编队和性能估值；未编辑模型builder/adapter、正式UI/相机、FirstPlayable、S05或舰队代码。UI中文消费与最终Chrome浏览器门槛交统筹后续所有者处理；本专项没有启动浏览器，也不提供浏览器FPS结论。

每轮引擎/原生/编码/绘图均通过同一 `verify.py` 内核互斥，带超时和进程组清理；窗口最小化并自动退出。清理记录见 [cleanup.json](../evidence/S04-spatial/cleanup.json)。原始帧和缓存保留在忽略目录 `.local`，正式证据在docs；没有驻留预览、HTTP服务或编辑器，也未关闭用户原窗口。源码与辅助脚本hash见 [source-hashes.json](../evidence/S04-spatial/source-hashes.json)，交付证据hash见 [evidence-hashes.json](../evidence/S04-spatial/evidence-hashes.json)。仓库仍无Git，本交付使用既有恢复点、基线/退回版本源码快照与hash记录，不宣称已提交commit。
