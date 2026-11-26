# S02-deck 大和侧视甲板轮廓修正

2026-11-11。大和 1944 年 4 月的局部几何修正、安装检查、原生及 Chrome 对应视角验证已完成，待统筹独立复核。原 S02 / S13 交付和证据保留。

## 原因与改动

旧 `deck_height` 将 11 个甲板标高逐段线性连接，前炮甲板低点 z≈−50m、舯部接平处及后航空甲板 z≈92m 有突变斜率；舰体仅用 81 个等距截面，部分标高点没有落在实际网格上。甲板和舷侧原本共用 rings，问题来自曲线和截面采样，并非两层网格错接。

`scripts/ship_geometry.gd` 改为保持形状的三次 Hermite 插值，保留全部 11 个原标高，不产生额外隆起／下陷。舰体与甲板继续共用同一边界，148 个截面包含所有标高点和中点，跨度最多 2m，并在曲率较大处细分，实际网格与曲线的最大误差为 **3.83mm**。没有把艏部、前炮低甲板、抬升舯部和较低航空甲板拉平。

三座主炮的真实炮座下缘按实际甲板曲面裁切，座圈保持水平；只更新三个宿主接触标高，没有新增通用支柱。主炮座面仍为 7.2 / 11.4 / 8.7m，三座三联 460mm、两座三联 155mm 的炮型、座数、管数、全部坐标与朝向保持原位。39 座武器的前后 socket 数据全部一致，正式单位 JSON 字节不变。其余数值格式由 Godot JSON 序列化为浮点形式，语义核对仅三个 `attachment.surface_y` 改变，见 [接触标高差异](../evidence/S02-deck/contact_changes.json)。

## 轮廓依据与视图

本轮实际重新打开以下原图：

| 原图 | 用途和限制 |
| --- | --- |
| [1941-10-10 试航完整侧面](../../references/ships/yamato_1944_04/original/yamato-1941-trials-and-context.png) | 核对共通艏部上扬、前炮区低点和连续舷缘；不借用其舷侧 155mm 或早期防空配置 |
| [田宫 78030 p18 整舰侧／俯](../../references/ships/yamato_1944_04/original/yamato-late-fit-side-and-plan.png) | 核对前炮甲板、舯部、后甲板的相对高低和转折区域；晚期套件仅用于共通舰体，不转移其 1945 防空配置 |
| [Modelkasten p5 图3，1944.2–6 完整平面](../../references/ships/yamato_1944_04/original/yamato-1944-02-to-06-plan.png) | 保留舰体平面和主副炮纵向位置；该图不提供垂向标高 |
| [Skulski p18](../../references/ships/yamato_1944_04/original/skulski-p18-freeboard-and-common-structure.png) | 10 / 8.6 / 6.4m 干舷锚点；页面本身不是完整侧视，不单独证明中间曲线 |

中间标高仍属既有图像比例复原，没有新增船厂型线或毫米级史实精度的声明。AI 目标图未参与这次几何定形。原图完整来源与日期限制沿用 [S02 参考包](../../references/ships/yamato_1944_04/modeling-brief.md)。

[前后轮廓裁剪对照](../evidence/S02-deck/profile_comparison.png)保留原始像素比例，仅取同一 y=430…650 区域，未扭曲横纵比例。以下原始 1600×1000 实拍未裁剪，前后相机位置、目标点、正交尺寸逐项完全一致：

| 机位 | 修改前 | 修改后 | Chrome |
| --- | --- | --- | --- |
| 左正侧 | [前](../evidence/S02-deck/before/port_side.png) | [后](../evidence/S02-deck/after/port_side.png) | [实拍](../evidence/S02-deck/chrome/port_side.png) |
| 右正侧 | [前](../evidence/S02-deck/before/starboard_side.png) | [后](../evidence/S02-deck/after/starboard_side.png) | [实拍](../evidence/S02-deck/chrome/starboard_side.png) |
| 略俯侧 | [前](../evidence/S02-deck/before/port_elevated.png) | [后](../evidence/S02-deck/after/port_elevated.png) | [实拍](../evidence/S02-deck/chrome/port_elevated.png) |
| 前炮过渡 | [前](../evidence/S02-deck/before/fore_transition.png) | [后](../evidence/S02-deck/after/fore_transition.png) | [实拍](../evidence/S02-deck/chrome/fore_transition.png) |
| 后甲板过渡 | [前](../evidence/S02-deck/before/aft_transition.png) | [后](../evidence/S02-deck/after/aft_transition.png) | [实拍](../evidence/S02-deck/chrome/aft_transition.png) |
| 前部壳体单独侧视 | [前](../evidence/S02-deck/before/fore_hull_side.png) | [后](../evidence/S02-deck/after/fore_hull_side.png) | [实拍](../evidence/S02-deck/chrome/fore_hull_side.png) |
| 后部壳体单独侧视 | [前](../evidence/S02-deck/before/aft_hull_side.png) | [后](../evidence/S02-deck/after/aft_hull_side.png) | [实拍](../evidence/S02-deck/chrome/aft_hull_side.png) |

已实际查看上述原生前后图及 Chrome 七视图。低点和接平处的硬折角收圆，主炮底座、前后副炮围壳与两舷平台未见明显悬空或埋入。

## 验证与性能

固定 Godot **4.7.2.stable.official.ed1daf0bf**、Compatibility，导出模板版本匹配。只运行受影响的四项机制检查：

| 检查 | 结果 |
| --- | --- |
| `test_hull_geometry.gd` | 263m 总长、38.9m 最大包络、10.4m 吃水保持；三角面有限且无退化；炮塔屋顶／绕序通过 |
| `test_yamato_deck.gd` | 原标高不变、无过冲、切线连续；296 个甲板边界点与舰壳匹配；39 个真实宿主面通过；三座主炮下缘接触最大偏差 0.048mm；副炮围壳和两舷连续平台接触／露高通过 |
| `test_capital_ship_models.gd` | 既有两舰安装／socket、真实炮口变换、独立运动和被动模型接口通过；衣阿华只读 |
| `test_mesh_batching.gd` | 索引／非索引混合合批的三角面、顶点次数及变换通过；公共合批器未修改 |

原生完整舰模型网格数 **216 → 216**，三角形 **127254 → 131676（+3.47%）**。七个机位的渲染调用数逐一不变，正侧为 580（含阴影）。[原生前记录](../evidence/S02-deck/before/capture.json)、[后记录](../evidence/S02-deck/after/capture.json)、[几何／安装结果](../evidence/S02-deck/geometry_installation.json)保留原始数据。

Chrome **157.0.8103.39**，Apple M5 / 16GB，ANGLE Metal，1600×1000 CSS 与实际缓冲，DPR=1。Browser 插件未提供，按 `frontend-testing-debugging` 技能使用已有 Playwright。实际执行“独立检视场景加载 → 方向键切换镜头 → 同一七机位实拍”；页面与场景身份、非空画面、无错误覆盖、控制台、39 座武器及相机交互均通过。控制台与页面错误均为 0。[Chrome 原始记录](../evidence/S02-deck/chrome/run.json)的 6 秒 RAF 样本为 717 帧，约 **119.5 FPS**，均值 8.37ms、P95 10.1ms。

该采样仅为带阴影和检视探针的单舰场景，不是四舰海空战、最终规模或 S08 长时性能验收。没有启动 Safari，也未重跑全战斗测试。

## 恢复、输入边界与清理

修改前已核对版本控制状态：本目录仍没有 Git 仓库。五个相关文件的局部恢复副本位于 `.local/s02-deck-before/`；[起始清单](../evidence/S02-deck/start_manifest.json)保存 548 个源码校验值。生产变更限 `scripts/ship_geometry.gd`、`data/hull_stations.json`、`data/yamato_1944_mounts.json`；另新增本次专用捕获场景、测试和 `tools/s02_deck/` 工具。

Chrome 包冻结独立检视场景的 **32 个依赖文件**，不包含 first_playable、云海、陆基、飞机或战斗入口。衣阿华资源只因现有适配器的 preload 进入依赖，不实例化、不修改。S10 并行源码变化单列在 [源码校验值与边界](../evidence/S02-deck/source_hashes.json)，未回退或覆盖。根入口保持原配置；导出写入忽略目录 `build/s02-deck-web/`。模板、依赖和产物校验值见 [构建清单](../evidence/S02-deck/build_manifest.json)。

所有引擎、导出与浏览器进程均经 `tools/verify.py` 的共享 flock、超时和进程组清理运行。[验证汇总](../evidence/S02-deck/verification.json)保留成功与失败报告及日志：两次等待 S10 导致的锁超时未启动引擎；首轮固定间隔的 2.1cm 曲线误差已通过局部细分修正；接触断言从 20µm 调整到适合网格检查的 0.2mm，最终实际偏差低于 0.05mm；隔离包初次导入的资源别名路径问题已在打包工具修正。Chrome 首轮停在标题断言（引擎随后将标题设为工程名），修正身份检查后完整七视图通过，冻结模型没有变化；失败记录也已归档。

[独立清理核对](../evidence/S02-deck/cleanup_audit.json)确认本轮记录的 25 个验证子进程已退出、两个自建 HTTP 端口已关闭、私有 Chrome 配置目录清空。没有关闭用户原有窗口或无关进程。[证据索引](../evidence/S02-deck/evidence_index.json)提供逐文件 SHA-256。

复现入口：

```sh
python3 tools/verify.py --owner S02-deck-review --timeout 90 test res://tests/test_hull_geometry.gd res://tests/test_yamato_deck.gd res://tests/test_capital_ship_models.gd res://tests/test_mesh_batching.gd
python3 tools/verify.py --owner S02-deck-review --timeout 60 godot --render -- --position -1800,0 res://scenes/inspection/yamato_deck_capture.tscn -- --output=res://.local/s02-deck-review
```

复建 Web 使用 `python3 tools/s02_deck/build_web.py`，浏览器脚本必须经 `tools/verify.py … exec -- node tools/s02_deck/chrome_check.mjs`。其默认输出会更新本任务 Chrome 证据，复核时应先保留本次归档。
