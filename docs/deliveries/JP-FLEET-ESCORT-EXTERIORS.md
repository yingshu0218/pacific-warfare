# 利根、秋月 · 日舰展厅外观

两艘舰均为独立 Godot 艺术场景，未接入对战、物理、火控或伤害系统。几何是按照片辨认外形的游戏重绘，不是实舰工程图或逐点尺寸考据。艏朝 −Z，水线为 Y=0。

| 展厅舰 | 对照的历史外观 | 验收重点 |
| --- | --- | --- |
| 利根 · 1942 年外形 | [美国海军历史与遗产司令部 80-G-88024：1942-08-24 的利根](https://www.history.navy.mil/our-collections/photography/numerical-list-of-images/nara-series/80-g/80-G-80000/80-G-88024.html)；[NH 111736：利根级早期外形](https://www.history.navy.mil/our-collections/photography/numerical-list-of-images/nhhc-series/nh-series/NH-111000/NH-111736.html) | 主炮外观集中前甲板，较高的层叠舰桥和单根粗烟囱在中段，舰后没有主炮外观；低艉甲板以航空作业区轮廓、导轨和吊杆区分。 |
| 秋月 · 1942 年试航外形 | [吴市海事历史科学馆照片转载：1942-05-17 宫津湾外的秋月](https://commons.wikimedia.org/wiki/File:Akizuki.jpg)；[美国海军历史与遗产司令部 NH 96188：秋月级照片](https://www.history.navy.mil/content/history/nhhc/our-collections/photography/numerical-list-of-images/nhhc-series/nh-series/NH-96000/NH-96188.html) | 长窄舰体、高舰艏与低艉部、单根烟囱、两组前后背负式封闭炮塔外形。按试航照做细桅；不混入后期改装。 |

利根有 10 个、秋月有 6 个展厅可动炮位，计数只表示该艺术模型中绘制的网格组，不按军械清册认定。每组有独立转台和俯仰节点，固定底座不动；复位回中立，并不带动其他炮位。小设备和舰艉航空甲板细节为简化外形；糊片遮蔽的细节不作精确复原。

独立场景入口：

- `res://scenes/ships/jp_fleet_escort/tone_visual.tscn`
- `res://scenes/ships/jp_fleet_escort/akizuki_visual.tscn`

Godot 4.7.2 Compatibility 分别渲染了艏斜视、侧视、甲板俯视、艉斜视及可动展示。另可从项目根运行：

```sh
godot --headless --path . --script scenes/ships/jp_fleet_escort/verify.gd
```

检查覆盖模型实例化、独立转向与俯仰、所有相邻炮位保持原姿态、船体保持原姿态，以及选中炮位准确复位。206 项通过。
