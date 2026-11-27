# 美军 1944 外观检视：海盗与闪电

两个都是独立 Godot 4.7.2 静态美术模型：1 单位 = 1 米，机鼻朝 -Z，翼展沿 X。没有挂载、火控、游戏单位注册、飞行参数或战术模拟。本次外观为收起起落架的定格；不能当作可飞行、可起降或可作战版本。

## F4U-1A Corsair，VF-17 55995

- [NHHC 80-G-425500](https://www.history.navy.mil/our-collections/photography/numerical-list-of-images/nhhc-series/nh-series/80-G-425000/80-G-425500.html) 目录锁定编号 55995、VF-17、1944 年 2 月布干维尔。公开目录条目已读，直连原图未通过本环境加载。
- 已直接查看同一架飞机的 [美国海军 80-G-217819 复制件](https://commons.wikimedia.org/wiki/File:Vought_F4U-1A_Corsair_of_VF-17_in_flight,_circa_in_March_1944_(80-G-217819).jpg)。取左上斜视的抬高座舱、长圆头、倒鸥翼折线、细收的尾梁、白色 29 与星徽和油箱白色封缝构成。照片很可能为 3 月，不能把前后日期的小标识当成完全一致。
- [NNAM FG-1D](https://www.history.navy.mil/content/history/museums/nnam/explore/collections/aircraft/f/fg-1d-corsair.html) 的 41 英尺翼展只交叉核家族尺度；不采用其后期机体/座舱配置。目标翼展 12.497 m，模型整长约 10.23 m，含桨毂、面向观战的视觉估值。单一固定桨姿，非旋转动画。照片不在发行资源内，也未摹绘所有徽标、机鼻小标识与战果旗。

## P-38J Lightning，西南太平洋 Marge 配色研究

- [Smithsonian NASM P-38J-10-LO](https://airandspace.si.edu/collection-objects/lockheed-p-38j-10-lo-lightning/nasm_A19600295000) 与已直接查看的 [NASM 照片](https://ids.si.edu/ids/deliveryService?id=NASM-NASM2023-00001-000001&max=1000) 核双发双尾梁、中央短舱、J 型深下颌、翼梁关系和总体大小。馆藏机 42-67762 曾改双座；不复制其后部座舱或涂装。目录为 11.70 m 长、15.80 m 翼展取整；[NASM 档案说明](https://airandspace.si.edu/stories/editorial/q-and-archives-division) 列系列名义翼展 52 英尺。
- [Marge 42-103993 原机照片与项目档案](https://pacificwrecks.com/aircraft/p-38/42-103993.html) 是西南太平洋 P-38J-15-LO 的配色来源；发掘方记录红鼻尖、桨罩、翼尖和垂尾尖。[美国空军报道](https://www.af.mil/News/Article-Display/Article/4558116/mission-marge-brings-legacy-of-americas-ace-of-aces-to-guam-airmen/) 另描述原残件退色红漆与 993 底层字样。直接查看过历史机鼻特写复制件（见该组的 [左侧鼻艺术照片档案](https://pacificwrecks.com/aircraft/p-38/42-103993/1944/p38j-marge-nose-vert.html)）。本模型**只采用该机有依据的配色布局**，暂未重制肖像、签字、战果标记或机号，红块面积与色值是艺术估计；不是逐件复原，也不是把 NASM 的馆藏机冒充为同一架。

## 启动及核验

- 独立查看：`godot --path . res://aircraft/us_archive/us_archive_viewer.tscn`；键 1/2 选机，V 切换斜前、侧面、俯视、斜后。
- `godot --headless --path . --script res://tests/us_archive/test_early_us_visual.gd` 核网格、尺寸、主要构型特征、图窗切换及静态模型限制。设置 `AIRFRAME_EXPORT_DIR` 后从实际模型导出 GLB。证据是 Godot 实际网格的离线渲染，不是对局截图。未验证浏览器。
