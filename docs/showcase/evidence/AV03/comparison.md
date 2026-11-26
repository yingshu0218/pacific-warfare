# AV03 原图与同模型对照

2026-11-11。原始照片、PDF原页渲染和Godot画面分别保存。相机、模型姿态及源码哈希在每张PNG的同名JSON内。当前风格沿用已认可简化标准，没有新造AI结构图。

| 原始成品照片 | 最终Godot模型 |
| --- | --- |
| ![M01 完整斜前](../../../references/aircraft/g4m1_1942/images/tamiya_full_front.jpg) | ![斜前](final/quarter.png) |
| ![M02 完整近侧](../../../references/aircraft/g4m1_1942/images/tamiya_09.jpg) | ![侧视停放](final/side.png) |
| ![M03 高位展开翼](../../../references/aircraft/g4m1_1942/images/tamiya_10.jpg) | ![同一模型俯视](final/top_flight.png) |
| ![M04 完整后斜](../../../references/aircraft/g4m1_1942/images/tamiya_01.jpg) | ![斜后](final/high_rear.png) |

原图为Tamiya一一型成品照片，非战时实机。模型相机朝向近似，未取得摄影内参，不作逐像素测绘；侧图是停放、顶图是水平收轮，状态差异显式保留。模型不移植359号、K-310或其他迷彩机的身份。大机身、长尾段、双发和翼尾比例已交统筹；r1偏圆罩体和翼尖被退回，r2采用阶梯风挡/较平屋顶、贴合舱沿、梯形翼尖，完整圆标与省略小侧窗已获认可，不继续细化。

| 主要装配原图 | 实际装配 |
| --- | --- |
| ![D01 小弹挂架](../../../references/aircraft/g4m1_1942/images/tamiya_03.jpg) | ![12枚60kg级弹体](final/bay.png) |
| ![D04 背部水泡](../../../references/aircraft/g4m1_1942/images/tamiya_06.jpg) | ![背枪与必要承载](final/dorsal_gun.png) |
| ![D05 原式尾罩](../../../references/aircraft/g4m1_1942/images/tamiya_07.jpg) | ![尾部单炮](final/tail_gun.png) |

弹舱为地面拆盖的真实战斗形态；盖板安装只用于无弹ferry配置。鱼雷图M05只证明互斥载荷外观，不表示本轮已做鱼雷。枪位各有独立轴/枪口；杆、截面和角度限位是照片估计，未宣称复刻内部炮架。浅色罩体为不透明简化玻璃，不要求内舱。

![正常观战距离](final/observer_flight.png)

![MAP02实际跑道1:1组合](final/airport_runway.png)

![MAP02实际机坪1:1组合](final/airport_parking.png)

以上机场画面直接读取现有MAP02同源地形/设施渲染器与数据，没有另造小地坪顶替，也未修改地图；飞机按8.04m支承面和真实轮组停放变换安装。它证明静态形体与接地，不替代OPS滑行、起降、动态净空或BOMB行为。
