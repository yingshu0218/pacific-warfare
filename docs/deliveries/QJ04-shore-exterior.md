# QJ04 岸防外观布景

青岬新版采用两种独立、静止的岸防历史外观道具：

- `scenes/qingjia/qj04_props/round_sandbags.tscn`：圆形平台，三层错缝堆叠的沙袋形成环状外观。
- `scenes/qingjia/qj04_props/permanent_concrete.tscn`：灰色混凝土外观，哑光旧化、灰斑与封闭的阴影带。

道具的历史照片依据沿用 [QJ03 岸防历史外观道具](QJ03-shore-heritage-props.md)。沙袋和混凝土壳都是架空美术，不是实物工事复原。没有活动炮架、武器数据、发射、单位注册或碰撞体。QJ03 原资源未改动。

验证：`godot --headless --path . --script tests/qingjia/test_shore_exhibits_qj04.gd`。两处各有 12 个合批哑光网格，场景根位于地面，Godot Compatibility 实机图已复核。
