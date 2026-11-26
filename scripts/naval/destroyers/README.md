# S03 驱逐舰纯模型接口

以下场景均直接从根工程加载。水线船中/全长中点原点，米制，+X右舷、+Y上、-Z艏向；实例缩放 `(1,1,1)`。

| 单位定义 | 纯场景 |
| --- | --- |
| `us_fletcher_dd445_1942_07_18` | `res://scenes/ships/fletcher_dd445/fletcher_dd445.tscn` |
| `jp_yukikaze_1942_06` | `res://scenes/ships/yukikaze/yukikaze.tscn` |

`data/units/<id>.json` 是正式单位入口；`data/ships/<ship>/assembly.json` 是模型装配清单。正式入口不含相机、UI、环境、计时器、自动瞄准或发射逻辑。只有另设的测试截图场景带中性环境与自退流程。

## 调用

实例加入场景树并完成 `_ready` 后调用。每帧只消费世界快照，模拟始终是状态源：

```gdscript
var packed: PackedScene = load(definition.model_scene) as PackedScene
var visual: Node3D = packed.instantiate() as Node3D
add_child(visual)
visual.apply_state(unit_state.snapshot())
# 可单独更新某炮位；train 相对炮位 base_yaw，elevation 正值抬炮。
visual.apply_weapon_state("main_51", {"train_rad":0.6, "elevation_rad":0.2})
var socket_records: Array[Dictionary] = visual.mount_sockets()
var muzzle_in_ship: Transform3D = visual.muzzle_transform_local("main_51",0)
var muzzle_in_world: Transform3D = visual.muzzle_transform_global("main_51",0)
var forward: Vector3 = -muzzle_in_world.basis.z
```

| 方法 | 行为 |
| --- | --- |
| `apply_state(state: Dictionary) -> void` | `position_m`、`rotation_rad` 可为Vector3或三元素数组；`active`控制可见；`weapons`字典以station_id逐座更新。没有插值/自己的时钟，完整快照含active等标准字段 |
| `apply_weapon_state(station_id,state) -> bool` | `train_rad`、`elevation_rad`以弧度更新活动轴；限位只作显示保护，不执行转速/火控。未知炮位或非有限角度返回false，拒绝时不部分改姿态 |
| `gun_elevations_rad` | 可选逐管俯仰数组。C型双炮分别保留活动轴；统一elevation时与S01共同pivot的炮口公式一致。逐管不同姿态要使用实际逐管炮口方法，不能套单一角度 |
| `mount_sockets() -> Array[Dictionary]` | 返回防御性深复制，字段对应冻结MountSocket契约，位置是武器座圈上端，不是底座下端 |
| `muzzle_transform_local/global(station_id,barrel_index)` | 0起始管号，返回实际Marker全姿态；炮口位于实际炮管网格前端。无效ID/管号返回IDENTITY，调用方须按定义先校验 |
| `apply_equipment_state(id,{train_rad}) -> bool` | 可选，仅回转`torpedo_01/02`外观，没有launch或扣弹方法。本Showcase不向世界注册鱼雷武器 |

世界决定转速、装填、启用、弹药和开火；模型不改变库存。机械可转范围不等于无遮挡开火许可，S05仍须处理自身建筑/友方遮挡和实际弹道。所有主炮默认朝向与历史炮位相符，偏角相对每座零位；-Z炮口使用正X轴俯仰。

## 模块与实际承载

每舰有独立可加载 `hull.tscn`、`bridge.tscn`、`funnels.tscn`、`platforms.tscn`、`equipment.tscn`。五种通用武器场景位于 `scenes/ships/destroyer_modules/`，每个炮位引用同一型号场景，实例独立回转与逐管俯仰。舰体不是武器脚本的一部分，武器也不包含整段舰体建筑。

`Ship/Hull|Bridge|Funnels|Platforms`提供带语义ID的宿主和表面Marker；装配从该Marker变换建立`MountFoundations/Foundation_<id>`，其固定底座上端`WeaponSeat/WeaponInstance`才是炮架原点。没有为补缺口添加通用支柱。`TrainPivot`只带回转外壳，`ElevationPivot_XX`带摇架/炮管/炮口；固定座圈与基脚留在回转轴之外。主炮的前部/顶面出口使用真实开口；检查覆盖负俯角、零位和最高仰角，避免炮管穿过实心炮室表面。

生成命令 `python3 tools/s03/build_destroyer_data.py`只重写S03所属的JSON/tscn，保留GDScript和资料；不要手改生成清单后又运行生成器。新武器/弹药用`s03_`命名空间，避免与S02/S05同ID异内容。弹药参数仍待S05校准。

## 来源与资源权利

程序网格、材质、场景和适配脚本由本项目编写，没有导入第三方舰体/炮架模型或纹理。历史照片仅在两舰参考目录保留作开发对照；模型不加载这些图片。参考目录有`.gdignore`，不导入Godot。田宫成品图/说明书、造船期刊只保留外链，临时检视副本在`.local/s03`，不作为游戏可发布资产。两型AI候选只保存外观探索，几何均未通过，未用于改变历史布局。

来源与限制：[弗莱彻 brief](../../../docs/references/ships/fletcher_dd445_1942_07_18/modeling-brief.md)、[雪风 brief](../../../docs/references/ships/yukikaze_1942_06/modeling-brief.md)。验证入口、逐炮位表、截图、实际退出码见[S03交付](../../../docs/showcase/deliveries/S03.md)。
