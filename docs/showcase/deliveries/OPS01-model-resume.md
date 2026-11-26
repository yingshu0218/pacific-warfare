# OPS01 S04 实际模型接续交付

2026-11-11。**独立私有实际模型阶段自验通过，交统筹动态验收；生产S14/S08/Chrome尚未接入。** 零环境风、CV01 Essex CV-9、1/2架F6F完整波次。原飞行/舰队/任务/DM继续使用既有唯一执行器。

## 本次实现

消费已由统筹验收的S04 r10四文件，候选清单SHA256为`379681d3aa81909d08a1e7c28a323ca7bac03054a390e2efb83d558ec8c9a3f3`。只替换私有`.local/ops01-model/r11`，公共F6F/Builder/Adapter未覆盖。stage输入是普通运行白名单加CV01、OPS、四份显式夹具，保留`.gdignore`，没有递归吸入AV02/G4M/AU01。实际执行476项输入冻结在[审计](../evidence/OPS01/model-resume/r11/audit.json)和`inputs/`。

- 替换旧同高三轮与pitch=0停放。用真实主/尾轮圆周沿当前甲板法线求支承，停放9.6453°、原点离甲板1.203077m；滑跑抬尾/接地落尾有界连续，姿态和高度由模拟写入。
- 分离下滑航迹与机体俯仰。进近机体约+9°，实际航迹约−2.2°；构型迎角/姿态连续变化，原AircraftMotion仍是唯一力积分。完成构型退出后的清洁名册内mission，1200tick位置/速度/姿态对照误差0；额外角速度上限没有永久施加于空战。
- 接触同时扫掠真实轮胎、实际候选机腹/翼/尾/襟翼mesh凸支承与完整旋转桨盘。错误低头的桨盘先触舰沿既有CombatDamage损伤，不记成功轮胎触舰。宿主断离或耐久归零时不保留轮/钩。
- 实际钩鞋端/鞋边在同一母舰局部坐标扫掠三维真实索段，最近距离≤0.073m才挂索。按当前姿态求钩上偏，不固定4.4m后偏移或静态29.95°。未挂索保留实际滑跑bolter路径。
- 受损残骸/原有上限碎片接受同源移动甲板支承。停桨后按实际桨叶相位、剩余几何与声明的简化质量中心作有界重力倾转，形成稳定支承，不锁死首次−2°姿态或悬挂在单个桨尖上；不隐藏桨叶、不改变DM断件/战损结局、不恢复active或补给。
- 增加可选`CarrierMissionDelegate`最小组合hook；BOMB/S14可在同一AircraftTasks内写控制与显式任务完成信号。probe验证600个真实mission tick、回收原因、取消一次与唯一执行器；不宣称轰炸机制已实现。

## 机制证据

最终31项接续检查：`.local/validation/runs/20261111T124451-3bc42af0/report.json`；同一r11的单机全循环与原89项机制：`.local/validation/runs/20261111T124711-ab8c45b1/report.json`。固定Godot`4.7.2.stable.official.ed1daf0bf`，headless串行，**120项、0失败**，另有单机全循环。

| 验证 | 最终结果 |
| --- | --- |
| 单机完整出动→巡逻→回收→补给 | 550.316667s；触舰479.383333s，阻拦停止484.383333s，停车520.316667s |
| 双机完整第一波与第二波 | 第一波748.333333s；第二波完成总时刻1902.45s；始终同两架真实UnitState |
| 双机最小甲板间距 | 20m |
| 地面世界/甲板变换误差 | 0m |
| 首波地空交接/二次含牵引最大位置积分差 | 0.013363m / 0.008108m，无瞬移 |
| 速度变化（含接地法向冲量） | 最大1.879471m/s |
| 油料守恒误差 | 约5.1×10⁻¹⁰kg；弹药补入原WeaponState且有限库存扣除 |
| 清洁飞行对原AircraftMotion | 名册外完整快照一致；名册内1200tick物理状态误差0 |
| 原受控−10m/s硬触舰 | 既有DM结局，失去OPS所有权，残骸封闭甲板，不补给 |
| 错误低头−2°进近 | 连续控制变化，桨盘先触舰；成功轮胎触舰计数0，既有DM失效/解体 |
| 停桨残骸实际mesh落定 | 最大tick高度变化0.053782m、角速度0.350001rad/s；全过程最低净空约−0.00000153m（浮点误差） |
| 残骸支承稳定性 | 最终俯仰约3.9°、侧倾21.4°，接触样本支承跨度5.348m；剩余质量中心沿重力投影距接触凸包0.01175m，在声明的0.015m容差内；母舰失效后原DM继续坠落 |

挂`wire_01`的实际事件：t=479.383333s，钩鞋扫掠`(−3.000006,15.871026,117.101448)`→`(−3.000006,15.872281,116.531326)`；索段`(−14,15.87,117)`→`(10,15.87,117)`，最近距离0.00125029m，钩上偏约23.64°。完整坐标/实际事件在[单机证据](../evidence/OPS01/model-resume/r11/mechanisms/cycle.json)。有限油弹、取消/改派、损失、复飞再次进近、真实母舰转弯/失效、连续复位、单/双机二次循环、暂停/4×/重开全部保留通过。

本轮修复了一个实际数值缺陷：Godot内建点在多边形判定对甲板内`(−3,−47.034286499)`返回false，导致第二次双机牵引虚假失去尾轮支承。当前用同一CV01顶点的标量crossing/boundary判定，不抖动飞机位置、不扩大甲板；原点复现脚本与历史失败报告保留。

## 15fps 原生短片段

四段均使用同一冻结r11的476输入与同一S04 r10四文件，Compatibility/Apple M5、960×640。每帧推进4个60Hz固定tick后真实渲染；全部从原始停放逐tick预滚到目标阶段，无补帧、无设置飞机轨迹。UI历史行数/区域已约束，实时状态位于顶部，飞机和甲板关系可辨。录制帧率不是Chrome性能数据。r09/r10中间画面与单点支承退回记录保留为历史，不作为最终同版证据。

| 片段 | 帧数 / 时长 | 证据 |
| --- | --- | --- |
| 滑跑→离舰→收轮爬升 | 330 / 22s | [录像](../evidence/OPS01/model-resume/r11/launch/launch.mp4) |
| 进近→轮胎接触→实际钩端挂索→减速停止 | 360 / 24s | [录像](../evidence/OPS01/model-resume/r11/recovery/recovery.mp4) |
| 甲板受阻→真实复飞 | 180 / 12s | [录像](../evidence/OPS01/model-resume/r11/waveoff/waveoff.mp4) |
| 错误低头→桨盘触舰→DM→重力倾转/稳定落定 | 300 / 20s | [录像](../evidence/OPS01/model-resume/r11/hard_contact/hard_contact.mp4) |

各目录包含逐帧时间/状态/CPU与实际模型轮钩误差、编码输入SHA256和精选原始PNG；全部逐帧坐标误差小于6mm准入容差。未重录旧9分钟3fps总览；旧总览/旧421输入归档仍是历史机制阶段，不作为新模型的使用态证明。

## 复建与交接

新建stage不覆盖旧取证：

```sh
python3 tests/air_operations/prepare_model_stage.py --name review-ops
python3 tools/verify.py --owner OPS01-review --project .local/ops01-model/review-ops --timeout 60 import
python3 tools/verify.py --owner OPS01-review --project .local/ops01-model/review-ops --timeout 90 test res://tests/air_operations/test_cycle.gd res://tests/air_operations/test_model_resume.gd res://tests/air_operations/test_operations.gd
```

如需原生检视，使用该stage与统一锁、有界timeout，不在根工程缺少S04 helper时直接运行。关键采集器参数为`--fps=15 --segment=launch|recovery|waveoff|hard_contact --output=<独立绝对目录>`。取证窗口最小化/不抢焦点，脚本完成自动退出；所有Godot和ffmpeg都经verify锁串行并finally清理。没有创建Chrome标签或HTTP服务。

参数/原始资料与明确估计见[来源卡](../../air_operations/OPS01/parameters-and-sources.md)，唯一执行器与任务delegate的字段/时序见[组合交接](../../air_operations/OPS01/integration-hooks.md)。476项最终同版输入、候选四文件、白名单、公共基线、历史验证失败和本轮进程组清理均在最终审计中保留。审计自身进程清理由外层verify报告另行证明。

## 未完成范围

当前只验证一/两架F6F整波循环。两架编制只出动一架时，后甲板留机仍可能阻挡回收；需要后续反向清场调度或命令校验限制，不能宣称任意局部波次已支持。零环境风之外的空气相对速度接口、日方甲板、多型混合、陆基、轰炸、程序指挥官自动再出动、航母炮战、S14生产注册与Chrome均不在本轮通过范围。简化气动/阻拦常减速度、抽象甲板牵引和粗粒度碰撞不是工程级模拟。
