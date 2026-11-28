# 美军主力舰 · 驱逐舰独立外观

两个模型都采用舰体坐标 +X 右舷、−Z 向艏、Y=0 表现水线。模型为游戏展台和截图使用的哑光外观；没有战斗接入、控制、碰撞体、动力或舱内建模。

| 舰艇与场景 | 同舰档案对照 | 观察和修改 |
|---|---|---|
| **西姆斯号 USS Sims DD-409 · 1942 初期代表状态**；`scenes/ships/us_fleet_destroyers/sims_visual.tscn` | 海军历史与遗产司令部藏美国国家档案馆 [19-N-21804，1940-05-09 波士顿外海侧视](https://www.history.navy.mil/content/history/nhhc/our-collections/photography/numerical-list-of-images/nara-series/19-n/19-N-20000/19-N-21804.html)，同舰同批 [19-N-21806，1940-05-09](https://www.history.navy.mil/our-collections/photography/numerical-list-of-images/nara-series/19-n/19-N-20000/19-N-21806.html)；[19-N-26675，1941-12-16 诺福克舰艉局部，右侧为 Sims](https://www.history.navy.mil/our-collections/photography/numerical-list-of-images/nhhc-series/nh-series/19-N-26000/19-N-26675.html)；[DANFS 舰史](https://www.history.navy.mil/research/histories/ship-histories/danfs/s/sims-i.html)。 | 用波士顿侧视核正高艏楼、艏柱与甲板断阶、圆前壁舰桥、有斜度的单烟囱、单杆前桅。用诺福克近照复查尾端两处主炮外罩和尾部圆角平台，不将 1940 阶段甲板上的所有附件照搬到 1942。修订提高圆舰桥与烟囱、修正艏端外形、展示艏部舷窗列，并把尾部平台与甲板舱分层。未发现可清晰确认全部细节的 1942 同舰全舰照片，故标签为「代表状态」，不称珊瑚海精确复刻。 |
| **艾伦·M·萨姆纳号 USS Allen M. Sumner DD-692 · 1944-03-26 建成早期**；`scenes/ships/us_fleet_destroyers/sumner_visual.tscn` | [NH 86272，1944-03-26，同舰空中侧视](https://www.history.navy.mil/our-collections/photography/numerical-list-of-images/nhhc-series/nh-series/NH-86000/NH-86272.html)；[DANFS 舰史与同日照片 80-G-237953](https://www.history.navy.mil/research/histories/ship-histories/danfs/a/allen-m-sumner.html)。 | 对照全舰的连续低甲板、方舰桥、两座相邻烟囱、前桅相对位置与前二后一的双管外罩。修订拉高烟囱、减小其后倾；把尾部的长平面分成不同标高的平台、局部外罩与较小的舷侧部件。照片拍摄于大西洋，模型是同舰在 1944 年的早期外观，不把照片标作后来抵达的太平洋舰期。 |

档案照片是视觉资料，不是测绘图；细小设备、栏杆、战时涂色和水下线型为游戏表现，不能据此推断每一项配置。舷号为游戏识别辅助，低对比标示不主张还原照片上每个字样。游戏几何包络核对为 Sims 约 106.12 × 10.83 米、Sumner 约 114.76 × 12.50 米（长 × 视觉最大宽）。这两个数值不是对水线宽或水下尺寸的工程测量。

实机复核：Godot 原生渲染逐舰输出艏斜视、侧视、俯视和艉斜视。将侧视与各舰档案图逐项核对后再导出；Godot 无头测试实例化两个场景、验证尺寸/有限包围盒、无碰撞对象及两艘的可辨外形计数。Sims 367 个 MeshInstance3D，Sumner 380 个。
