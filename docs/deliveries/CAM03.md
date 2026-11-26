# CAM03 战斗机跟拍

2026-11-19。生产入口为 `showcase/carrier_harbor.tscn`。Godot 4.7.2 Stable，Compatibility。

## 中文操作

- 从默认「港湾实战观战」或段落菜单的「单机自主空战观察」「四机自主任务」进入，在顶栏点「战斗机跟拍」。镜头先选择正在执行自主机动的战斗机，其次正在与战斗机交战的主体，再次是在空的战斗机。镜头显示「在空」或「脱离」等当前状态。
- 主体有效时至少保持 6 个模拟秒。已有主体与候选同样有取景价值时继续跟随。失去主体时优先在可用的交战飞机中接替，同等情况下优先原对手。全部战斗机不可跟拍时显示「暂无可跟拍的战斗机」，保留最后视角。
- 平时从侧后约 43 米观察，并以世界竖直方向维持地平线。对手或同一双机组的成员在镜头能兼顾的范围内时，自动腾出取景空间。实际入画时显示「对手」「长机」或「僚机」。
- 机动名取自 AIR02 正在执行的动作，并等模拟发布实际姿态或航迹变化后显示。改出阶段会标「改出」，完成或中止后恢复当前任务状态。训练从独立训练段落进入，沿用原有训练状态和镜头。
- 空格或「暂停」冻结镜头与战局，再按恢复。再次点击「战斗机跟拍」、按 C 或点「实际交战」回到混合电影。按 F、右拖、滚轮或使用移动键可转入自由观察。选定单位后按「跟随」可接管镜头。按 R 或点「重开」重置本场，恢复该段原有默认镜头。「空中交战」仍可独立观看轰炸、拦截、空战及轰炸机炮塔还击。

## Ego Lite 复核接口

普通按钮首次点击调用 `_action("camera", "fighter")`，再次点击切换 `"auto"`。仍使用协议 2 的 `window.S14X.observe_frame`。选择跟拍后每帧可读 `fighter`：

- `id` 是当前主体，顶层 `id`、`model_m`、`screen_px` 仍对应同一插值帧的模型。主体为空时保留 `fighter`、`generation`、`tick` 与 `presentation_time_s`，避免把其他镜头的旧主体误作当前目标。
- `opponent_id` 是当前任务确认的在场战斗机对手。`secondary_id` 是镜头当前尝试取景的第二架，可通过 `relation`（`opponent`、`leader`、`wingman`）和 `secondary_in_frame` 核对是否实际入镜。
- `rotation_rad`、`bank_rad`、`velocity_mps`、`camera_roll_rad` 与 `shot_serial` 可用于连续构图核对。`autonomous_maneuver` 提供动作、阶段、状态及小量实测信息，`verified_label` 表示当前镜头显示了经过实际运动确认的动作名。

## 运行文件

下列六个 GDScript 文件已修改，相邻的 `.gd.uid` 为沿用的原资源标识。通过资产清单中已有的脚本路径进入普通 Web 构建。

- `scripts/presentation/cameras/observer_camera.gd`，取景选择、连续侧后跟拍、双机构图、实际机动标签。
- `scripts/game/first_playable.gd`，从跟拍切入手动观察。
- `scripts/showcase/all_units_showcase.gd`，段落入口、切换按钮和跟拍状态。
- `scripts/showcase/expansion/carrier_harbor.gd`，常规港湾状态。
- `scripts/showcase/expansion/web_probe.gd`，现有 opt-in 帧探针的当前跟拍观测。
- `ui/observer_hud.gd`，通用视角状态名。

模拟、初态、火控、武器未编辑。相机读取与已渲染模型同一表现时钟的 `presentation_units`。根目录无 Git 元数据，交付用文件 SHA-256 标识。

冻结源码副本位于 `.local/repairs/cam03/frozen`。包含运行文件、资源标识和回归用例的 [SHA-256 清单](../showcase/evidence/CAM03/source-sha256.json) 自身的 SHA-256 为 `5c3ce70eb08c6efe6df94b92c857b3227c9a92502960d0d0599222055422670a`。

## 串行验证命令

```sh
python3 tools/verify.py --owner CAM03-final-import --timeout 100 --lock-timeout 220 import
python3 tools/verify.py --owner CAM03-regressions --timeout 150 --lock-timeout 205 \
  test res://tests/rx02/test_observer.gd res://tests/test_air01_default_harbor.gd
python3 tools/verify.py --owner CAM03-native-final --timeout 245 --lock-timeout 480 \
  godot --render -- --script res://tests/test_cam03_fighter_camera.gd --position -1800,0
```

RX02 的 50 项检查通过。普通港湾的 AIR01 回归同时覆盖舰炮、战斗机交火、战斗机对轰炸机开火、轰炸机背部炮塔镜头及 24 条真实炸弹离架与接触链。报告保存在 `.local/validation/runs/20261119T105558-5e92c2ff/report.json`。

## 原生取景结果

在 Apple M5、1280×720 的 Compatibility 原生窗口中，以 30 Hz 取样推进同种子 707 的正式段落。「港湾实战观战」采样 90 模拟秒，「单机自主空战观察」采样 105 模拟秒。共 42 项原生检查通过，含真实鼠标点击、空格暂停与恢复、W／F／C／R、右键接管、单位跟随、同局切回空中交战和训练入口。暂停时镜头位置、地平线和当前标签均冻结。原生进程通过验证器清理。 [逐帧采样](../showcase/evidence/CAM03/native.json) · [原生运行与清理报告](../showcase/evidence/CAM03/native-report.json) · [既有观战回归](../showcase/evidence/CAM03/regression.json)

| 入口 | 真实交火与跟拍 | 画面证据 |
| --- | --- | --- |
| 港湾实战观战 | 两型战斗机共 110 发对战斗机枪炮弹。零战 4 号连续跟随约 39 秒，镜内高差约 373 米，最大相对起始航向变化约 180°。可看到轴向滚转、爬升转弯和斜向滚转弧，49 帧将对手也纳入避开界面的取景区 | [轴向滚转](../showcase/evidence/CAM03/harbor_axial_roll.png) · [爬升转弯](../showcase/evidence/CAM03/harbor_rising_arc.png) · [斜向滚转弧](../showcase/evidence/CAM03/harbor_oblique_roll_arc.png) |
| 单机自主空战观察 | 共 64 发战斗机对战斗机枪炮弹。零战 3 号从 21.58 秒跟到 43.38 秒，镜内高差约 514 米，最大相对起始航向变化约 138°。可辨上升、下降、换向和轴向滚转。另一个镜头有 21 帧取到对手 | [对机交汇](../showcase/evidence/CAM03/maneuver_opponent.png) |

两个样本的同一主体内最大镜头偏航速率分别为 0.384 与 0.374 弧度／秒，世界地平线在采样中保持水平。最终样本的第二架为空战对手。长僚机依据实际同组状态和取景范围选入，最终两个采样窗口未拍到同组双机。反向转弯标签在先前 AIR02 版本的原生采样中出现，最终样本中的可见动作如上。

先前的真实战局回放记录了两处跟拍主体进入坠毁状态并当帧交接。最终两局未自然触发原跟拍主体失效，因此同时用正式入口导出的独立快照验证失效切换和全部不可用时的保留视角，对照实际世界快照确认战局未被修改。 [较早的真实损伤交接记录](../showcase/evidence/CAM03/earlier-loss-sample.json)

普通 Web 包和 Ego Lite 验收由统筹完成。
