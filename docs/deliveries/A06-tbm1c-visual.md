# A06 · TBM-1C 外观初版

2026-11-27。以 1944 年 TBM-1C 为身份，程序网格只做可独立查看的展翼飞行外观，不接入普通观战名单。单色识别涂装是工作色，不是对某架飞机和涂装日期的复原。

## 已核参考

- [美国海军 BuAer 1943-07-01 外形三视图](https://commons.wikimedia.org/wiki/File:Grumman_TBF-1_Avenger_BuAer_drawing.jpg)：原图底部标明也适用 TBM-1 与 -1C。实际查看俯、正、侧整机，只用于长座舱、肥厚机身、展翼平面和尾翼大形；不复制内部结构。
- [美国海军 80-G-238779，1944-05-30 TBM-1C 飞行照](https://commons.wikimedia.org/wiki/File:TBM-1C_Avenger_of_VT-51_over_Majuro_Atoll_in_May_1944.jpg)：实际打开原图，斜视用于验证圆形机头、连贯长座舱和后方圆形玻璃罩、厚机身及高垂尾。透视不用于量翼展。
- [美国海军陆战队《Marine Corps Aircraft 1913–2000》附表](https://www.marines.mil/Portals/1/Publications/Marine%20Corps%20Aircraft%201913-2000%20PCN%20190004116000.pdf)：TBM-1C 长约 41 英尺、翼展 54 英尺 2 英寸。换算作为游戏外廓控制；未宣称首版曲线或高度为精确测绘。

## 当前验收

- Godot 4.7.2，米制。运行 `res://aircraft/tbm1c/tbm1c_viewer.tscn` 可查看，1／2／3 切换斜视、侧视、俯视；不改变根入口或 Web 预设。
- 从可见三角面核对：翼展 16.510 m、整机外廓长 12.500 m、当前姿态可见高 4.034 m（**不含展开起落架**，不能与停放高度相互代用）。
- 复跑：`godot --headless --path . --script res://tests/model_audit/test_tbm1c_visual.gd`。三视证据由实际 Godot 网格离线渲染；未做实时画面或浏览器性能验收。
- 尚未做真实涂装/编号、展翼以外姿态或场景接入。B6N2 仍待制作；克利夫兰、高雄两型待先锁定各自外观日期及参考。
