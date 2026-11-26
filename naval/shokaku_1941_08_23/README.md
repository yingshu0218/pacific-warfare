# CV02 · 翔鹤 1941-08-23

独立纯模型和甲板契约候选，Godot `4.7.2.stable.official.ed1daf0bf` / Compatibility。未改根入口、CV01、生产注册或普通19单位包。

- 入口：`shokaku.tscn`；模块：hull / hangar / flight_deck / island / funnels / platforms / equipment。
- 历史固定高平两用炮8座双联127mm；游戏轻防空6座三联25mm。合计**14炮架／34管**，与历史轻防空12座分开记录。
- `apply_state`、`apply_weapon_state`、`apply_equipment_state`仅消费状态；`mount_sockets`和炮口变换供后续适配。
- `deck_definition`深复制；`deck_surface_at(Vector2(x,z))`返回当前甲板/升降台面；`deck_obstacles`给保守障碍。飞机完整接地/包络仍须调用方检查。
- 3升降机为独立节点；节点路径、孔口、上下限和表面同源于`data/deck.json`。
- 历史确认/图像估值/游戏索位近似写在同一数据和参考卡里。D4Y仅尺寸笼，A6M为未改源码的1944纯模型静态跨期检查。

有界机制检查（含真实网格装配）：

```sh
python3 tools/verify.py --owner CV02 --timeout 60 godot -- --log-file .local/cv02-test.log --script res://naval/shokaku_1941_08_23/inspection/test_shokaku.gd
```

自动截图并退出（既有原图不覆盖时换输出目录）：

```sh
python3 tools/verify.py --owner CV02 --timeout 70 godot --render -- --log-file .local/cv02-native.log --resolution 1440x900 res://naval/shokaku_1941_08_23/inspection/inspection.tscn -- --capture res://.local/cv02-review --views starboard_bow_quarter,top,port_side,port_stern_quarter
```

原生交互检视可省去`--capture/--views`，用左右键切相机；verify仍负责超时和本轮进程清理。检视专用水线裁剪不属于纯舰体模型。

Web重建：`python3 tools/cv02/build_web.py`，仅准备`.local/cv02-web-project`并由统一verify锁依次导入/导出到`build/cv02-web`；不修改根工程导出设置。检查：`python3 tools/verify.py --owner CV02 --timeout 100 exec -- node tools/cv02/chrome_check.mjs`，私有Chrome/HTTP服务在finally关闭。

来源与边界：[参考卡](../../docs/references/ships/shokaku_1941_08_23/modeling-brief.md)。最终证据与限制：[CV02交付](../../docs/showcase/deliveries/CV02.md)。模型通过不表示航行/防空战斗/起降/队列/轰炸完成，正式注册由S14单一所有者处理。
