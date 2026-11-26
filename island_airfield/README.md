# 沃莱艾环礁机场场景

独立 Godot 项目，主场景为 1944 年沃莱艾环礁法拉拉普岛日军机场。场景以米和秒组织，Compatibility 渲染器运行；不依赖根目录主场景或共享项目设置。

## 启动

```sh
GODOT=/Applications/Godot.app/Contents/MacOS/Godot
"$GODOT" --version
"$GODOT" --editor --path island_airfield
"$GODOT" --path island_airfield
```

本目录通过相对软链接只读复用项目自有的 A6M5a 程序几何和 Noto CJK 字体：`aircraft -> ../aircraft`、`assets -> ../assets`。机场、飞行、相机、界面与项目配置均在本目录内。Godot 导入缓存和网页导出目录已加入本地忽略。

## 操作

- 鼠标左键拖动：自由环绕；滚轮：缩放；右键拖动：平移。
- `1`：全岛俯视；`2`：跑道与设施；`3`：飞机跟随；`4`：九六式双联高射炮特写；`5`：九二式重机枪特写；`6`：两种装备并排尺寸对照。
- `Space`：暂停/继续；`R`：从机坪重新开始完整出动；`T`：在 1×、2×、3×之间切换演示速度。
- `L`：电影光照/中性光照；`H`：隐藏界面；`F8`：显示帧率、绘制调用和对象数。

飞机沿实际米制航路完成滑出、起飞、环岛航线、进近、着陆滑跑与滑回机坪；默认 3×演示时间。飞行路线使用程序航点，不求解气动力或起落架载荷。

## 浏览器版

需要与 Godot 4.7.2 匹配的 Web 导出模板。导出和本地预览：

```sh
GODOT=/Applications/Godot.app/Contents/MacOS/Godot
"$GODOT" --path island_airfield --export-release Web build/web/index.html
python3 -m http.server 8008 --directory island_airfield
```

然后打开 `http://127.0.0.1:8008/build/web/`。浏览器预览保留机场、程序飞机、全套相机和操作界面。M5 16 GB 的 Safari/Chrome 实测记录见 `docs/flight-cycle-verification.txt`。

## 文件

- `scenes/woleai_1944.tscn`：可直接运行的独立入口场景。
- `scripts/woleai_environment.gd`：珊瑚岛地形、海面、跑道、滑行道、机库、观测塔、防空阵地与沙袋。
- `scripts/sortie_controller.gd`：A6M5a 出动航线与地面/飞行状态。
- `scripts/airfield_demo.gd`：灯光、相机、界面与演示输入。
- `docs/historical_basis.md`：装备、尺度、资料来源和场景推定。
- `screenshots/`：Godot Compatibility 渲染器实机截图。

