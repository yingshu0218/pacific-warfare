# AV05 原生证据

- 独立模型原始 PNG 与机位／标记／成本记录。[改前](model-before/) · [终版](model-after/) · [改前 JSON](model-before/capture.json) · [终版 JSON](model-after/capture.json)
- 普通港湾轰炸原始 PNG 与机位记录。[改前](game-before/) · [终版](game-after/) · [改前 JSON](game-before/viewpoints.json) · [终版 JSON](game-after/viewpoints.json)
- 并排图。[G4M1 独立模型](g4m1-model.jpg) · [G4M1 港湾](g4m1-game.jpg) · [D4Y2 独立模型](d4y2-model.jpg) · [D4Y2 港湾](d4y2-game.jpg)
- 最终接口复测与流程记录。[D4Y2 AV02](verification/d4y2-mechanisms.json) · [G4M1 AV03](verification/g4m1-contracts.json) · [改前可见面](verification/old-visible-shells.log) · [终版总测试](verification/final-contracts-run.json) · [终版可见面](verification/final-visible-shells.log)
- 验证器与截图退出记录。[独立改前](verification/model-before-run.json) · [独立终版](verification/model-after-run.json) · [港湾终版](verification/game-after-run.json)
- [冻结源 SHA-256](frozen.sha256) · [证据 SHA-256](evidence.sha256)

普通港湾改前 PNG 由统筹从正式 Web 包对应的工程做原生捕获。AV05 用相同 [复拍脚本](replay_ordinary.gd) 得到终版 PNG，并核对八组场景、时刻、相机坐标和目标坐标。并排图等比缩放显示，原始 PNG 保留原尺寸。

从仓库根重拍终版时，输出到任务自己的临时目录。

```sh
python3 tools/verify.py --owner AV05-review --lock-timeout 120 --timeout 50 godot --render -- --script res://tests/av05/capture.gd -- "$PWD/.local/av05-review/model"
python3 tools/verify.py --owner AV05-review --lock-timeout 120 --timeout 85 godot --render -- --script "$PWD/docs/showcase/evidence/AV05/replay_ordinary.gd" -- "$PWD/.local/av05-review/harbor"
python3 tools/verify.py --owner AV05-review test res://tests/av05/test_visible_shells.gd
shasum -a 256 -c docs/showcase/evidence/AV05/frozen.sha256
```
