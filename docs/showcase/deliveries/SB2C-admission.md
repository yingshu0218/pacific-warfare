# SB2C-4 当前模型准入交付

2026-11-11，Owner：`SB2C-admission`。**整体外形、必要装配和现有 S14 飞行适配准入通过**，由统筹实际看图和独立审计确认，见[准入复核](../acceptance/SB2C-admission-review.md)、[独立审计](../acceptance/SB2C-admission-root-audit.json)。模型到此冻结，不追加孔洞或表面细节。最终全单位场景及 Chrome 留 S14/S08；本结论不涵盖投弹、后座火控、起降或毁伤。

## 模型与修正

入口：[纯模型场景](../../../aircraft/sb2c4/sb2c4.tscn)、[模型源码](../../../aircraft/sb2c4/sb2c4.gd)、[独立检视场景](../../../aircraft/sb2c4/showcase.tscn)。具体子型为 **Curtiss SB2C-4，1944–1945，展开机翼**。

- 机头并入连续外壳，删除独立罩圈、发动机内部等多余几何；加深中机身，后腹逐步收起，尾端与垂尾连贯，修正原先低垂的尾刺轮廓。
- 座舱使用曲面罩体、后倾风挡、不透明灰蓝玻璃和少量分段框条，接缝嵌入机身；后座保留围框、环轨及必要短支撑。双枪整体上仰24°，不穿入垂尾。
- 主翼保持15.164m翼展并收圆翼尖；减速板用无孔实体面板，闭合翼面与展开状态分开。
- 去掉尾轮处夸大的整流脊；短支柱与叉架接入后腹。由三轮接触推导静态停放姿态，不靠拉长尾轮让水平机体三轮落地。
- 炸弹及8枚HVAR尖端朝−Z、安装有承载；闭合弹舱门补偿铰点后贴合机腹。飞行形态闭舱、收轮、关闭减速板、隐藏展示挂载与尾钩。

整机、原始资料和修改前后见[对照记录](../evidence/SB2C-admission/comparison.md)。最终[侧视](../evidence/SB2C-admission/final/side-flight.png)、[斜前停放](../evidence/SB2C-admission/final/reference-front-parked.png)、[正常观战距离](../evidence/SB2C-admission/final/observer-distance-flight.png)均为真实 Godot 画面。

## S14 纯模型交接

米制、比例`(1,1,1)`；+X右、+Y上、−Z前。纯模型根原点仍为`(0,0,0)`；`AIRCRAFT_FLIGHT_REFERENCE=(0,2.38,0)`只是表现参考点，**不是实测重心**。S14既有平移`(0,−2.38,0)`保持不变；无需重定原点或套用停放变换。

| 接口 | 当前行为 |
| --- | --- |
| `set_showcase_configuration(clean: bool)` | `true`闭合减速板/弹舱，隐藏挂载与尾钩；保持起落架和根变换 |
| `set_flight_configuration()` | 调用干净配置并隐藏起落架 |
| `set_landing_gear_deployed(bool)` | 整组显隐，未实现连续收放 |
| `set_arrestor_hook_deployed(bool)` | 整组显隐，未实现连续运动/拦阻索 |
| `set_dive_brakes_deployed(bool)` | 实体上下板与闭合翼面的二值切换 |
| `set_bomb_bay_open(bool)` | 开/闭门与陈列炸弹切换，无投弹或弹药状态 |
| `set_external_stores_visible(bool)` | 8枚HVAR展示组显隐，无发射逻辑 |
| `get_parked_transform() -> Transform3D` | 返回静态三点停放变换，由展示宿主选择应用 |

独立检视场景默认`clean + parked`；命令支持`--mode clean|detail|flight`及`--pose level|parked`。`detail`中的8枚HVAR和1枚500lb炸弹仅是装配检视，**不是已核实的标准出击载荷**。停放姿态俯仰约8.799°、Y平移−0.636952m，三轮接触误差小于`4e-8m`；不得写入真实飞行根姿态。

11个模块、39个marker、位置/方向/来源置信度、实际子节点路径、五个控制面、轮半径与包围盒见机器可读[接口记录](../evidence/SB2C-admission/interfaces.json)。主要路径：

- 螺旋桨：`05 Engine and propeller module/Propeller`；通过模型`propeller`引用使用。
- 起落架：`06 Landing gear module`；主轮中心`(±2.10,1.00,−0.58)`、半径0.44m；尾轮`(0,1.40,3.90)`、半径0.15m。
- 控制面：`10 Movable control surface modules/`下的`Port/Starboard aileron`、`Port/Starboard elevator`、`Movable rudder`，保留`animated_surfaces`引用。方向舵铰点改到Z=5.23m。
- 尾钩：`11 Small equipment module/Retractable arrestor hook`。新增尾钩轴/端点、轮心、尾轮接入点、内部弹释放参考、两门前射炮及两门后射枪的枪口marker；原有主武器和HVAR挂点ID保留。

发动机外包络现归机身，动力模块只保留桨组件；座舱内部和细小表面件不再实例化。后座每支完整枪体归独立局部组，不能继续依赖旧微小子节点。适配使用公开引用/marker；具体路径以本轮JSON为准。

现有[S14适配器](../../../scripts/showcase/sb2c_flight_adapter.gd)未修改；专属headless检查实际实例化它并验证`−2.38m`平移、收轮、静态合批后桨相位及副翼/升降舵状态可消费。两实例状态隔离、全部五个控制面可独立改变。尚未实现连续收放轮/尾钩/减速板、后枪转动火控、弹药/投弹、航母作业及SB2C预切毁伤；留OPS01/BOMB01及后续接口任务。

## 尺寸、参考与限制

名义长11.049m、翼展15.164m。飞行可见包围盒长11.110m（含桨毂/尖端，约比名义长0.55%，非本轮整体放大）、宽15.164m、高4.06990m；最低点是桨尖，非未隐藏的轮子。名义机高4.496m仍为同系列资料估值，不作SB2C-4测绘高度断言。

本轮实际打开R01/R02完整斜前/斜后、R03尾部、R05枪架成品照片及R04 Wright State实机侧面公开预览，并对照用户认可的AI v04简化目标。原照片、AI图、真实模型图分别保存；AI只定风格。R04仅400×327，照片透视与安装尺寸不精确；尚无可量取的同子型严格正前/正投影顶视。精确罩体截面、枪架与尾轮站位仍含照片估计。详情见[参考任务卡](../../references/bombers/sb2c/modeling-brief.md)与[来源记录](../../references/bombers/sb2c/sources.json)。参考照片不作为游戏纹理或再分发素材。

`cockpit-root.png`为隔离座舱连接而隐藏整组武器，因此画面下方裁切中也隐藏了弹舱门；不能将该隔离空隙误认成飞行机腹破洞。实际闭合状态以`underside-flight-closed.png`为准。

## 已完成的验证与证据

固定Godot `4.7.2.stable.official.ed1daf0bf`、Compatibility。所有Godot/截图均经`tools/verify.py --owner SB2C-admission`共享锁、有限超时与进程组清理；截图使用低优先级、屏外位置，保存后自动退出。本任务未启动Chrome、Safari或HTTP服务。

最后接口检查运行`20261110T190505-b40f5827`：退出码0、无失败项。最终14张1440×900原生图全部退出码0、无诊断错误、清理成功，涵盖侧/正前/顶面/斜前后/停放/正常距离、座舱、枪架、尾轮、弹舱、HVAR和闭合机腹。每张PNG旁均有相机、姿态、渲染配置及三份源码依赖哈希。实际命令、退出码与日志见[验证索引](../evidence/SB2C-admission/verification-index.json)，不需为文档收尾重复运行。

仓库根目录的复建命令示例（本轮已执行；当前冻结收尾不再启动）：

```sh
python3 tools/verify.py --owner SB2C-admission --timeout 25 --lock-timeout 45 test res://aircraft/sb2c4/validation/test_sb2c4_admission.gd
nice -n 10 python3 tools/verify.py --owner SB2C-admission --timeout 25 --lock-timeout 45 godot --render -- --rendering-method gl_compatibility --audio-driver Dummy --resolution 1440x900 --position 5000,5000 --quit-after 600 res://aircraft/sb2c4/showcase.tscn -- --view reference_side --mode flight --pose level --capture /Users/infinity/Desktop/Dev/game-pacific/docs/showcase/evidence/SB2C-admission/final/side-flight.png
```

[冻结清单](../evidence/SB2C-admission/manifest.json)收录9份源码/依赖、6份参考与14组PNG/元数据的SHA-256。主要源码：

```text
sb2c4.gd         6da0e7cfbb45027217bc5eda90551c3b75cacaf1151eaf8b60c30d97be18cb61
showcase.gd      08136aff97aa2f5b4984b3e6463ba88a9671569294e74ebd4487ea7cc9c31bce
shared builder   c5642713db0ab0592fbff355413327905d4342fafa9097322281077e13feed3a
S14 adapter      959aa7c3039be1fc34cbb2caa4c086fe2b0981857a7b9b911b19de90789d32b9
```

前后侧视相机相同，但共享builder期间被DM01修改；SB2C不调用其被修正的F6F/A6M主轮舱盖分支。此依赖变化已明确记录并经统筹确认，最终测试及14张图均使用当前哈希。未修改共享builder、S14适配、模拟、FX/DM或根配置。

索引保留48份实际运行记录，包括1次参考下载连接超时和4次锁等待超时；失败未算作通过，锁等待未启动Godot。统筹复查75个登记进程组全部退出，权限不明项0，见[清理记录](../evidence/SB2C-admission/cleanup.json)及独立审计。索引生成后的打包调用`20261110T191232-5f42c38d`也退出0、清理成功，最后读取共享锁为`released`；未关闭或发送信号给用户/DM01进程。

根无Git。改动前局部恢复点为`.local/restores/SB2C-admission/20261110T183132Z`，带`.gdignore`；[修改前清单](../evidence/SB2C-admission/sources-before.json)、[模型与检视源码差异](../evidence/SB2C-admission/source-changes.diff)可回溯。生成时的清单/接口JSON保留当时“待统筹”的状态，当前状态以[准入结论](../acceptance/SB2C-admission-review.md)及[状态记录](../evidence/SB2C-admission/status.json)为准，避免改写已审计快照。

本任务交付结束、释放执行名额；不自动开始G4M或Ki-21。
