# S02 主力舰模型表现接口

2026-11-10；对应 [S01 v1 运行契约](../runtime-contracts.md)，不扩展或修改模拟契约。交付状态见 [S02](deliveries/S02.md)。

## 入口与状态输入

`res://scenes/ships/yamato_1944_04.tscn` 和 `res://scenes/ships/iowa_bb61_1944_12_28.tscn` 都以 `CapitalShipAdapter` 为根，缩放为1，单位米。没有海面、相机、UI、自动瞄准或本地模拟时钟。独立旧查看器不改默认入口。

```gdscript
var model: CapitalShipAdapter = load(unit_definition.model_scene).instantiate() as CapitalShipAdapter
add_child(model)
model.apply_state(unit_state_snapshot)
```

`apply_state(Dictionary)` 消费S01 `UnitState.snapshot()` 的 `position_m`、`rotation_rad`、`active`、`weapons`。Vector3或长度3数组均可；角度为弧度。它只显示状态，不改变世界、弹药、战果、任务或射击事件。`active=false`默认隐藏模型；持续显示残骸可由S07/S05的损伤表现另处理。

`apply_weapon_state(station_id, {train_rad, elevation_rad}) -> bool` 直接设置对应武器相对其基础朝向的姿态，保持限位。模拟负责转速、射界、装填、库存、遮挡与战斗规则。无效ID或非有限角度返回false。Iowa可选 `gun_elevations_rad:Array`，分别显示三根独立主炮轴；S01默认单个elevation仍使三管同仰角。

## 安装点和炮口

`mount_sockets() -> Array[Dictionary]` 返回深复制的S01 `MountSocket` JSON字段：id、host_id、weapon_definition_id、role、position_m、base_yaw_deg、elevation_pivot_m、muzzle_positions_m、source。所有实际游戏炮位都在其中：大和39座、Iowa58座。运行ID仍由世界用 `<entity_id>/<mount_id>` 组成；不能用Node实例ID。静态数据在两份正式 `data/units/` 定义中，测试会逐字段对照实际模型，数值容差0.00003 m/同量级角度，仅覆盖JSON和float32表示。

- `muzzle_transform_local(station_id, barrel_index) -> Transform3D`：相对本适配器的当前实际炮口位姿。
- `muzzle_transform_global(...) -> Transform3D`：同一炮口经舰艇姿态后的世界位姿。
- `barrel_index`从0开始；炮口统一朝局部-Z。Iowa主炮各管Marker在各自俯仰轴；大和同座枪炮共用该座俯仰轴。每座、每舰实例独立。

模拟不能读取这些Node来取得敌方实时状态；火控/弹道用纯数据 `MountSocket.local_muzzle_transform()` 和己方UnitState。表现用Marker安放炮口闪光等，二者在受控多姿态测试中对齐。此游戏AA配置均用固定甲板宿主，没有炮塔顶AA的额外父炮运动耦合。

正式数据更新由 `tools/export_capital_ship_sockets.gd` 从真实模型提取完整socket；它只更新两舰JSON的mounts。不是运行时自动重写数据，也不据导出绿灯证明历史正确。修改几何后须重导出、跑检查，再审实际截图。

## 共用资源与回归

Iowa通过 `assets/naval/models/us_iowa_1944/{scripts,scenes,data,shaders}` 四个相对目录软链接复用独立工程。相对资源路径同时适用于独立工程与根工程；不要把其project.godot、.godot或查看器作为模型依赖。根Web预设的include_filter已显式包含别名目录中的Iowa配置JSON；迷彩遮罩以原创SVG文本内置资源创建，避免两个工程共用.import缓存。打包时须保留或展开这些明确的资源链接；S08负责Web导出实测。

同型主炮/副炮依同一几何或PackedScene复用，独立固定座、回转轴、俯仰轴不合并。静态兄弟网格按材质合批；不跨活动轴、炮位或宿主模块边界合并。Iowa迷彩固定到舰艇局部坐标，舰艇移动由 `apply_state` 更新world_to_ship；炮室涂装在原位坐标中随回转。

```sh
python3 tools/verify.py --owner S02 --timeout 60 test res://tools/export_capital_ship_sockets.gd
python3 tools/verify.py --owner S02 --timeout 75 test res://tests/test_capital_ship_models.gd res://tests/test_weapon_motion.gd res://tests/test_mesh_batching.gd res://tests/test_hull_geometry.gd
python3 tools/verify.py --owner S02 --project iowa --timeout 60 test res://tests/test_mount_assembly.gd
```

单一验证锁、超时和清理要求沿用 [验证入口](../validation.md)。默认headless，S02不启动浏览器。单次原生检查会保存六张1600×1000图及audit然后退出：

```sh
python3 tools/verify.py --owner S02 --timeout 45 godot --render -- res://scenes/inspection/capital_ship_capture.tscn -- --ship=jp_yamato_1944_04
python3 tools/verify.py --owner S02 --timeout 45 godot --render -- res://scenes/inspection/capital_ship_capture.tscn -- --ship=us_iowa_bb61_1944_12_28 --neutral
```

`--neutral`把所有MeshInstance3D统一覆盖为双面中性材质，包括内嵌surface材料，故既不残留迷彩也不会因原网格双面材质的剔除差异产生假缺面。完整全舰side/top/bow_quarter/stern_quarter与局部fore_battery/aft_battery分开命名；重复运行覆盖同一模型的当前证据。历史原图位于各参考包original/，AI风格图在target/，真实Godot截图在showcase/evidence/S02/，三者不混称。
