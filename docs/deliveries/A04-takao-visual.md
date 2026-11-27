# A04 · 高雄号整舰外观

目标为 **1944-10-22、出文莱湾时段** 的独立游戏外观。整艘包括连续水上／水下船体、前高后低的甲板、高耸多层舰桥、前后形状不同的双烟囱、双桅、甲板主要外露体块、航空作业区和舰尾外形。仅展示用途，无内部构造、实物操作或战斗接口。晚期小件、颜色、甲板材质和水下细部是估形，不作同期实测复原。

- [NH 63435 档案说明](https://www.ibiblio.org/hyperwar/OnlineLibrary/photos/images/h63000/h63435c.htm) 和[原始扫描](https://commons.wikimedia.org/wiki/File:Japanese_Center_Force_ships_leave_Brunei_Bay,_Borneo,_on_22_October_1944_(NH_63435).jpg)：用于锚定实际舰名与时段，远景不能核实小件。
- [1939-07-14 同舰改装后试航](https://commons.wikimedia.org/wiki/File:IJN_cruiser_Takao_on_trial_run_in_1939.jpg) 实看舷侧和斜艏，辨识高耸多层舰桥、大小烟囱、甲板线；[1942-11-14 同舰](https://commons.wikimedia.org/wiki/File:IJN_cruiser_Takao_at_Solomon_Islands_in_1942.jpg) 提供另一角度，均不当作 1944 同日照片。
- [NH 97770](https://www.history.navy.mil/content/history/nhhc/our-collections/photography/numerical-list-of-images/nhhc-series/nh-series/NH-97000/NH-97770.html) 是改装后共用类舰识别图，实际查看原扫描中的外形侧视/俯视，只参考相对布置，**不用其早期识别估计当作 1944 实测尺寸**。游戏外形采用约 203.76 m × 20.73 m 的长宽以及 6.32 m 的统一设计吃水作为比例约束，不指称当天装载下的水线。

Godot 4.7.2 运行 `res://scenes/ships/takao_1944/takao_viewer.tscn`。1 斜视、2 舷侧、3 俯视、4 去水面。实际三角面测得长 203.760 m、船体宽 20.730 m、设计水线至最低点 6.320 m，船壳闭合；四种视角测试舰首、舰尾和桅顶进入画面。复跑 `godot --headless --path . --script res://tests/model_audit/test_takao_visual.gd`。共用展示几何和观察器后克利夫兰网格导出逐字节不变。整舰图由真实 Godot 网格离线渲染，未测试实时画面或 Web 性能。未加入正式观战单位。
