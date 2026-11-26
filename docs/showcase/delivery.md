# Pacific 装备联调 Showcase 交付记录

此页为早期装备联调的历史记录。2026-11-11 全单位 Showcase 的普通启动命令、Chrome 验收与已知性能限制见 [S08 汇总交付](deliveries/S08.md)；本页旧快捷键、规模和瞬时 FPS 不作当前版本验收依据。

## 场景与启动

独立演示入口为 [`showcase/showcase.tscn`](../../showcase/showcase.tscn)。根目录 `project.godot` 的默认场景仍为 `res://scenes/main.tscn`；运行 Showcase 时显式指定入口：

```sh
GODOT=/Applications/Godot.app/Contents/MacOS/Godot
"$GODOT" --version
"$GODOT" --path . res://showcase/showcase.tscn
```

快捷键：`1` 总览、`2` 舰炮、`3` 靶区弹着、`4` 空战跟随、`5` 防空近景；`Space` 暂停、`T` 切换倍速、`R` 重置、`H` 隐藏 HUD、`F8` 性能 HUD。鼠标左键环绕、右键平移、滚轮缩放。

## 复验结果

Godot `4.7.2.stable.official.ed1daf0bf`、Compatibility 渲染器。headless 导入完成；内置验证以固定 `1/60 s` 步长模拟 120 秒，并执行三次重置审计：

```sh
"$GODOT" --headless --path . --editor --import --quit
"$GODOT" --headless --path . res://showcase/showcase.tscn -- --verify --duration=120 --rate=8 --reset-audit
```

结构化结果见 [`run-120s.json`](evidence/run-120s.json)：模拟时长 `120.13 s`，重置次数 `3`，所有内置验收条件通过。主炮 `9` 发 / `6` 次命中，副炮 `15` 发 / `12` 次命中；Type 89 `52` 发，Type 96 `218` 发 / `10` 次命中，Type 92 `30` 发 / `5` 次命中。A6M5a `148` 发 / `76` 次命中，F6F-5 `72` 发 / `42` 次命中。友军误伤为 `0`。

弹丸池峰值 `70/512`，特效池峰值 `27/96`，两类上限丢弃数均为 `0`。两架 A6M5a 各飞行 `120 s`；一架 F6F-5 在 `12 s` 被击落，另一架在 `117.867 s` 被 A6M5a 击落。模拟验收要求双方至少有一架飞机飞行不少于请求时长的 95%，因此通过；这不代表每架飞机都存活了 120 秒。

Type 89 的定时空炸机制确实触发，但这次运行没有记录到空炸命中。机炮和直射防空炮在本次运行中产生了实际命中。

## 画面证据

- [舰炮跟随](../../showcase/evidence/ship.png)
- [靶区弹着](../../showcase/evidence/impact.png)
- [空战跟随](../../showcase/evidence/air.png)
- [防空近景](../../showcase/evidence/aa.png)

四张图均为原生 Godot 1440×900 截图。

## 浏览器检查与性能记录

场景、资源和原生截图验证完成后，才进行 Web 导出。Chrome 与 Safari 均能显示岛屿、机场、大和号和 HUD；两个浏览器中点击场景后按 `5` 都切换到“防空近景”。Chrome 控制台记录了 `SHOWCASE_READY`，含 4 架飞机、2 组舰炮和 3 个地面靶，未见脚本错误。Safari 进行了画面与快捷键检查，没有单独启用 Web Inspector。

Web 构建仅用于本轮本地浏览器检查，保存在临时目录，验证后已关闭测试标签、HTTP 服务并清理构建副本；没有把导出物加入项目。实际设备为 Apple M5 / 16 GB。打开 F8 性能 HUD，在运行中的全屏浏览器窗口采集瞬时 FPS、draw call 与对象数：

| 浏览器 | 仿真秒 | FPS | Draw | Objects |
| --- | ---: | ---: | ---: | ---: |
| Chrome | 77.1 | 54 | 650 | 1398 |
| Chrome | 147.1 | 48 | 2284 | 3040 |
| Chrome | 204.3 | 40 | 1903 | 2656 |
| Safari | 117.7 | 25 | 1609 | 2145 |
| Safari | 162.6 | 28 | 1619 | 2144 |
| Safari | 189.5 | 19 | 1613 | 2141 |
| Safari | 234.4 | 21 | 1613 | 2141 |

这是全屏窗口下的现场快照，不是锁定渲染分辨率后的基准测试；浏览器截图视口大小不同，不能直接横向比较。Safari 长时样本约 `19–28 FPS`，Chrome 约 `40–54 FPS`，显示 Safari 在当前高对象/绘制负载下偏低。未单独采集每标签内存。浏览器检查不是完整 120 秒仿真验收；模拟机制的 120 秒结果见上节。

## 模拟范围

演示用于装备和观战接口联调，不是完整战役模拟。飞机采用简化的追逐、转弯和爬升控制；弹丸使用固定步长轨迹和扫掠碰撞；损伤与炮弹效果未实现完整装甲穿透、舰艇水动力或真实空气动力学。舰炮目标是机场以北隔离的中立靶区。武器参数和模型接口复用项目现有资源。
