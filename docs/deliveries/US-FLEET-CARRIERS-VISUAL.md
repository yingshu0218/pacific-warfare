# 1942 年美军舰队航母外观：约克城、列克星敦、黄蜂

三艘均为 Godot 独立静态展品。观察时以舰艏 `-Z`、右舷 `+X`、水线 `Y=0` 为基准。外观参考采用指定时期的实舰照片，不复刻照片里的损伤、飞机、人员或临时摆放，也没有把后期同名舰的斜角甲板、舷号或舰岛套进来。

| 舰与目标时期 | 实舰外观资料 | 模型对照与保留项 |
| --- | --- | --- |
| 约克城号 CV-5，1942 年 6 月中途岛、受损前代表外观 | [80-G-21931，5 月 27 日进入珍珠港](https://www.history.navy.mil/our-collections/photography/wars-and-events/world-war-ii/midway/80-G-21931.html)；[80-G-13065，5 月 29 日进坞](https://www.history.navy.mil/our-collections/photography/wars-and-events/world-war-ii/midway/80-G-13065.html)；[DANFS 舰史](https://www.history.navy.mil/research/histories/ship-histories/danfs/y/yorktown-iii.html) | 照片的长直甲板、敞开帽沿式艏艉、前方高位三脚桅观察台、后侧分立轻桅和较低平烟囱可辨。游戏版独立重建，不以现有大黄蜂改名。保留三个静态中线升降机轮廓；操舰细节与小配件为简化。 |
| 列克星敦号 CV-2，1942 年 5 月 8 日珊瑚海早晨 | [80-G-16569，当日由约克城拍摄](https://www.history.navy.mil/our-collections/photography/wars-and-events/world-war-ii/battle-of-the-coral-sea/battle-of-the-coral-sea--events-of-8-may-1942/uss-lexington-underway--8-may-1942/80-G-16569.html)；[80-G-16806，当日飞行甲板近景](https://www.history.navy.mil/our-collections/photography/wars-and-events/world-war-ii/battle-of-the-coral-sea/battle-of-the-coral-sea--events-of-8-may-1942/damage-on-board-uss-lexington--8-may-19/80-G-16806.html)；[DANFS 舰史](https://www.history.navy.mil/research/histories/ship-histories/danfs/l/lexington-cv-2-iv.html) | 宽厚舰体、狭高舰桥塔、其后巨大平顶长烟囱，在侧视中形成分离的两个主轮廓。80-G-16569 及档案说明确认旧式大炮塔在这一时期已移除，故未放回旧轮廓。档案远景的小设备不可判读，以简化静态体块处理。 |
| 黄蜂号 CV-7，1942 年 8 月瓜达尔卡纳尔代表外观 | [80-G-12240，5 月 26 日实舰外观](https://www.history.navy.mil/our-collections/photography/numerical-list-of-images/nara-series/80-g/80-G-10000/80-G-12240.html)；[1942 年 6 月 3 日 Norfolk Navy Yard 右前视，档案照片副本](https://www.navsource.net/archives/02/020720.jpg)；[80-G-16864，8 月 7 日舰桥翼现场](https://www.history.navy.mil/our-collections/photography/numerical-list-of-images/nara-series/80-g/80-G-10000/80-G-16864.html)；[NH 43466，左舷舷边升降机档案](https://www.history.navy.mil/our-collections/photography/numerical-list-of-images/nhhc-series/nh-series/NH-43000/NH-43466.html)；[DANFS 舰史](https://www.history.navy.mil/research/histories/ship-histories/danfs/w/wasp-viii.html) | 与另两艘相比更短、甲板更窄。采用右舷多层舰岛、高窄烟囱及清楚的前后双桅；左舷保留固定舷边升降机平台轮廓。舰体的低对比色块参照照片中的明暗分区，但不是 8 月逐板复原。 |

## Godot 检查

三个场景位于 `res://scenes/ships/us_fleet_carriers/`：`yorktown_cv5_visual.tscn`、`lexington_cv2_visual.tscn`、`wasp_cv7_visual.tscn`。Godot 4.7.2 无界面实例化检查中，三艘都生成可见网格，不含碰撞体；沿舰长轴的显示包围尺寸分别为 246.74、270.66、225.96 米。其中约克城以 [NOAA 的 246.7 米总长记载](https://oceanexplorer.noaa.gov/photogrammetry/uss-yorktown-cv-5-2025/) 为比例目标，另两艘以 DANFS 长度栏为目标。尺寸仅用于游戏外观辨识，不是工程图。

实机用同一套斜视、侧视和俯视相机检查舰岛叠层、甲板端部、甲板升降机轮廓、舰体和外廊交界。三舰没有加入正式战局，不含互动升降机、航母作业逻辑或舰载机。
