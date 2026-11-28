# 美国太平洋舰队：首批九艘主力舰外观

这是新增的九个独立 Godot 外观，不更改关卡部署、武器、航行或损伤。美军水面外观总数由 15 增至 24；全舰机展厅从 37 项增至 46 项（33 舰、13 机）。

| 批次 | 新增 | 逐舰照片依据、造型和简化 |
| --- | --- | --- |
| 舰队航母 | 约克城 CV-5、列克星敦 CV-2、黄蜂 CV-7 | [航母外形复核](US-FLEET-CARRIERS-VISUAL.md) |
| 战列舰 | 北卡罗来纳 BB-55、西弗吉尼亚 BB-48 | [战列舰外形复核](US-FLEET-BATTLESHIPS-VISUAL.md) |
| 巡洋舰 | 旧金山 CA-38、火奴鲁鲁 CL-48 | [巡洋舰外形复核](US-FLEET-CRUISERS-VISUAL.md) |
| 舰队驱逐舰 | 西姆斯 DD-409、艾伦·M·萨姆纳 DD-692 | [驱逐舰外形复核](US-FLEET-DESTROYERS-VISUAL.md) |

约克城同级已有企业和大黄蜂，列克星敦同级已有萨拉托加；这里增加的是对应年份的个舰造型，不将它们算成新舰级。各舰以指定时期照片为外形依据，使用项目统一哑光材质。史料未能清晰分辨的涂色和小件按游戏观察距离简化；不把历史照片中的海况、停放飞机或受损状态当作模型固定组成。

## 打开和测试

- 外观展厅：在 Godot 中打开并运行 `res://showcase/archive_gallery/viewer.tscn`，在舰船栏选择对应舰名。
- `godot --headless --path . --script tests/model_audit/test_us_fleet_exteriors.gd`：检查九个条目独立可加载、外形尺寸、可见网格，以及不含战局碰撞或导航节点。
- `godot --headless --path . --script tests/model_audit/test_archive_finish.gd`：检查其余展品仍可加载、实际材料处理和相机/选择控制。
