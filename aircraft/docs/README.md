# Pacific aircraft models

本目录是可独立打开的舰载战斗机模型与检视场景，不替换仓库的主场景，也不修改根目录的 `project.godot`。

## 启动

项目基准为 Godot **4.7.2 Stable** 与 Compatibility 渲染器。仓库根目录执行：

```sh
GODOT=/Applications/Godot.app/Contents/MacOS/Godot
"$GODOT" --path . res://aircraft/scenes/aircraft_viewer.tscn
```

单独打开机型场景也可以：

```sh
"$GODOT" --path . res://aircraft/scenes/a6m5_52ko.tscn
"$GODOT" --path . res://aircraft/scenes/f6f5.tscn
```

查看器可从命令行指定初始模型与视角，便于复核：

```sh
"$GODOT" --path . res://aircraft/scenes/aircraft_viewer.tscn -- --model a6m5 --view top
"$GODOT" --path . res://aircraft/scenes/aircraft_viewer.tscn -- --model f6f --view side
"$GODOT" --path . res://aircraft/scenes/aircraft_viewer.tscn -- --model pair --capture /tmp/aircraft-pair.png
"$GODOT" --path . res://aircraft/scenes/aircraft_viewer.tscn -- --model f6f --hide-ui --capture /tmp/f6f5.png
```

`--model` 可取 `a6m5`、`f6f`、`pair`；`--view` 可取 `front`、`side`、`top`。截图使用 Godot 视口直接写 PNG。
截图时加 `--hide-ui` 可去掉查看器界面，便于保存无遮挡的模型视图。

## 查看器操作

- 左键拖动：环绕；右键或中键拖动：平移；滚轮：缩放。
- `1`、`2`、`3`：零战、地狱猫、并排比较；`0`：复位。
- `Space`：螺旋桨；`F`：襟翼；`G`：起落架；`C`：操纵面；`H`：隐藏界面。
- 界面按钮也提供机型切换、正视、侧视、俯视、复位和活动部件控制。

## 机型与尺寸

| 机型 | 版本与年份 | 机长 | 翼展 | 机高 | 主要配置 |
| --- | --- | ---: | ---: | ---: | --- |
| Mitsubishi A6M5a Model 52 Ko | 五二甲型，1944 | 9.121 m | 11.000 m | 3.509 m | 荣 21；2 × 7.7 mm Type 97；2 × 20 mm Type 99-2 Model 4；125 发/门 |
| Grumman F6F-5 Hellcat | 1944–45 | 10.236 m | 13.056 m | 3.990 m | R-2800-10W；6 × .50 in M2；400 发/枪 |
| Curtiss SB2C-4 Helldiver | 1944–45 | 11.049 m | 15.164 m | 4.496 m* | R-2600-20；2 × 20 mm AN/M2；后座双联 .30 in 活动机枪 |

运行时遍历网格并计算外包框，A6M5a 约为 9.116 × 11.000 × 3.509 m，F6F-5 约为 10.230 × 13.056 × 4.515 m。机长包含螺旋桨整流罩尖端与机尾；F6F-5 尾翼已收至尾端站位，机长与表列参考值相差约 6 mm。F6F-5 外包高度包含展示姿态中竖起的螺旋桨叶尖；规格表中的 3.990 m 用于对照机轮至垂尾顶端的机体高度，螺旋桨转动时叶尖高度会变化。翼面积来自当前机翼平面形数值积分，属于几何估算（A6M5a 约 21.2 m²；F6F-5 约 31 m²），不可当成原厂工程图尺寸。

A6M5 公开资料对机高的测量基准和数值有差异。本模型采用日本资料表的 3.509 m 三点姿态值；Plans of Fame 对其保存的 A6M5 实机列出 9 ft 8 in。机型、改装状态与姿态不同会影响比较，详情和原始链接见 [`REFERENCES.md`](REFERENCES.md)。

## 模型范围与限制

机体由带站位的参数化截面和翼型剖面生成，零件按机体、主翼、尾翼、操纵面、发动机、座舱与起落架分组，方便在 Godot 场景树检查。包含透明舱罩与框架、发动机气缸排、冷却襟翼、排气管、枪炮、襟翼/副翼/升降舵/方向舵、收放起落架、导航灯、国籍标记和面板线等可见细节。A6M5a 表现弹链供弹的 20 mm 机炮与机翼下表面无弹鼓鼓包；F6F-5 表现折叠翼接缝与火箭导轨底座。

这些是供实时观战与观察的程序化低多边形模型，不是可用于制造、维修或测绘的工程 CAD。翼型与截面经三视图和博物馆实机照片校形，但没有逐铆钉/逐蒙皮板复刻；未建模内舱、发动机内部管线、火控系统、液压连杆和完整弹药机构。座舱、炮口、管线及铰接运动作了可视化简化。F6F 的 Sto-Wing 只表现展开状态的翼面分界与外翼上反角，未实现实际斜轴折叠动画；下表面接缝的后掠量是视觉估值。部队编号、个体战术涂装、雨蚀、污渍、布面纹理与某架幸存机的修复差异尚未对应具体序列号。起落架演示是枢轴动画，未复现真实收放连杆轨迹。材质和灯光为检视展示设置，不代表历史色卡测色结果。

本目录内的机体几何、标记和涂装均由项目中的 GDScript 程序生成，没有打包第三方模型、纹理、插画或生成式图像。参考图仅用于比例与轮廓校对；逐项来源和授权说明见 [`REFERENCES.md`](REFERENCES.md)。
查看器界面的简体中文使用根目录已有的 `assets/fonts/NotoSansCJKsc-Regular.otf`，没有复制字体；字体来源和 SIL Open Font License 1.1 记录在 [`assets/SOURCES.md`](../../assets/SOURCES.md) 与 [`assets/fonts/LICENSE.txt`](../../assets/fonts/LICENSE.txt)。

SB2C-4 是独立模块化场景 [`sb2c4.tscn`](../sb2c4/sb2c4.tscn)，不替换项目主场景。它按机身、主翼、尾翼、座舱、动力、起落架、减速板、武器与挂载、操纵面分组，并在机体上提供带元数据的挂点标记。展示状态为起落架放下、无孔实体分裂减速板打开；减速板和操纵面尚未连接运行时动画。8 枚 HVAR 与 1 枚 500 lb 炸弹只作为结构和挂载展示样例，站位/数量未被标注为某次 SB2C-4 出击的标准载荷。完整子型资料、尺寸来源、视图估算和授权边界见[参考记录](../../docs/references/bombers/sb2c/README.md)。

SB2C-4 的机高标记为估值：4.496 m 参考同系列 -5 资料；机长和翼展采用 -4 的公开资料换算。具体资料差异与该模型限制列在参考记录中。

可单独打开 SB2C-4 检视场景：

```sh
"$GODOT" --path . res://aircraft/sb2c4/showcase.tscn
```

检视场景按 `1`–`7` 切换前上方斜视、后上方斜视、侧视、俯视、腹视、正视与正后视；`8` 为前侧三分之四，`9` 为机腹斜视；`B`、`D`、`W`、`C`、`T` 分别查看炸弹舱、翼根减速板、副翼、座舱和尾轮近景；`Esc` 退出。命令行加 `--mode clean` 可关闭减速板、隐藏挂载并关闭炸弹舱门。

## 实际运行截图

以下截图由 Godot 4.7.2 Compatibility 渲染器直接捕获；并排图用于比例对照，单机图用于检查表面细节。

2026-11-05 几何修正：发动机双排气缸与缸头改为径向排列，移除造成放射突刺的伪冷却鳍；缩短机炮外露段并封闭翼尖截面；螺旋桨改为带扭转和收尖的叶片，整流罩改成锥形，尾轮支柱接回机身。

2026-11-05 F6F 机翼复核：把实机照片列为外观主参照，并按 42 ft 10 in 翼展、334 ft² 翼面积和根/尖翼型厚度比校核平面形与翼厚。当前照片依据、限制和折缝说明见 [历史资料与参考图](REFERENCES.md)。下列新截图由 Godot 4.7.2 Compatibility 原生渲染捕获，用于检查翼面轮廓、厚度和上反角。

- [F6F-5 三分之四视图（本轮）](screenshots/f6f5-shape-3quarter.png)
- [F6F-5 俯视（本轮）](screenshots/f6f5-shape-top.png)
- [F6F-5 正视（本轮）](screenshots/f6f5-shape-front.png)

2026-11-05 A6M5a 外形复核：先对照 Planes of Fame 的 61-120 保存机照片及飞行照片，再用五二型上/下视示意图交叉核对翼端。修正机翼厚度由根部约 15% 渐变至翼尖约 9%（A6M2 资料外推到 A6M5 的家族级近似）、翼尖圆收、发动机罩黑色和左右 6/5 根推力排气管。翼展、机长保持原尺寸。照片来源、改型差异和近似边界见 [历史资料与参考图](REFERENCES.md)。以下为 Godot 4.7.2 Compatibility 原生渲染的检查截图。

2026-11-06 A6M5a 翼平面复核：旧轮廓中翼弦偏宽、前缘后掠过大，外翼又过早收成尖点。参照 AirPages 五二型上/下视线图（按 11 m 翼展作比例校核）、Tamiya 的短圆翼尖说明和 61-120 实机飞行照片，收窄内/中翼、减小外翼前缘后掠，并让外段弦长保持到更靠近翼尖后再圆收；翼展仍为 11 m。同步调整翼面日之丸位置和翼尖航行灯。下列截图重新捕获；参考资料和精度边界见 [历史资料与参考图](REFERENCES.md)。

- [A6M5a 三分之四视图（本轮）](screenshots/a6m5-shape-3quarter.png)
- [A6M5a 俯视（本轮）](screenshots/a6m5-shape-top.png)
- [A6M5a 正视（本轮）](screenshots/a6m5-shape-front.png)
- [A6M5a 侧视（本轮）](screenshots/a6m5-shape-side.png)

- [并排对照](screenshots/comparison.png)
- [A6M5a Model 52 Ko](screenshots/a6m5a.png)
- [F6F-5 Hellcat](screenshots/f6f5.png)
- [F6F-5 Sto-Wing 接缝俯视（Web 导出）](screenshots/f6f5-fold-top.png)
- [F6F-5 外翼上反角正视（Web 导出）](screenshots/f6f5-fold-front.png)

- [SB2C-4 前上方三分之四视图](../sb2c4/screenshots/sb2c4-front-three-quarter.png)
- [SB2C-4 后上方三分之四视图](../sb2c4/screenshots/sb2c4-rear-three-quarter.png)
- [SB2C-4 侧视](../sb2c4/screenshots/sb2c4-side.png)
- [SB2C-4 俯视](../sb2c4/screenshots/sb2c4-top.png)
- [SB2C-4 腹视](../sb2c4/screenshots/sb2c4-underside.png)

SB2C-4 第 3 轮监督复核未通过，具体意见见[监督记录](../../docs/deliveries/sb2c4-review-round3-supervisor.md)。第 3 轮图像已归档在[历史形体复核包](../../docs/deliveries/sb2c4-review-round3.md)，它们反映旧模型。当前继续改机身轮廓、座舱/后射手舱、尾轮和挂载外形；按用户要求本轮没有启动 Godot、生成截图或进行实测。不要用下列历史图判断当前源文件造型。

- [干净侧视（第 3 轮历史）](../sb2c4/screenshots/round3/sb2c4-round3-clean-side.png)
- [展开挂载细节（第 3 轮历史）](../sb2c4/screenshots/round3/sb2c4-round3-detail-front-port.png)
- [座舱根部（第 3 轮历史）](../sb2c4/screenshots/round3/sb2c4-round3-detail-cockpit-root.png)
- [尾轮连接（第 3 轮历史）](../sb2c4/screenshots/round3/sb2c4-round3-detail-tailwheel-root.png)

浏览器预览使用独立临时副本导出，网页导出文件不放入此目录；俯视截图用于检查 F6F 折缝与翼面轮廓。

## 运行与浏览器检查

2026-11-05，Apple M5、16 GB 内存，Godot 4.7.2 Stable / Compatibility：资源导入、独立查看器启动、Web 导出均成功；运行时网格外包框已量取并与上表资料尺寸核对。本次 Sto-Wing 修正后的 Web 预览在 Chromium 1440 × 900 视口中加载正常；按 `2` 选择 F6F、切换俯视/正视及隐藏界面均生效，页面无 JavaScript 错误。因 Browser 插件未提供且 Codex 内置浏览器连接超时，使用 Playwright Chromium 后备核验；截图期间出现的 WebGL `ReadPixels` 性能警告来自图像采集，没有伴随页面错误。Safari 与已安装 Chrome 的当前构建性能尚未实测。

本次没有记录数值 FPS、内存或 CPU 占用；Safari 与 Chrome 的当前构建性能数据仍待补测。
