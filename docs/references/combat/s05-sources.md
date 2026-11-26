# S05 战斗参数依据与近似

2026-11-10 实际检索并打开下列原文页。这里核实弹径、代表弹质量、初速和射速；不以网页绿灯或模型准入证明完整弹道/装甲仿真。执行参数在 `data/combat/showcase.json`，生成脚本 `tools/build_combat_parameters.py`；来源说明不参与运行。

| 武器/弹种 | 历史依据与本次取值 | 程序处理 |
| --- | --- | --- |
| 46 cm Type94 / APC Type1 | 1460 kg、780 m/s；1.5–2 rpm，近似中间战斗距离周期35秒；回转2°/s、俯仰8°/s。[NavWeaps Type94，含 USNTMJ O-45 的讨论](https://www.navweaps.com/Weapons/WNJAP_18-45_t94.php) | 保留 AP 基准；35秒为常量近似，未模拟降至装填角、逐管发射延迟。每管100发全部AP是场景供弹，不声称真实弹种配比。 |
| 15.5 cm Type3 / AP Type91 | 55.87 kg、920–925 m/s、约5 rpm、回转5–6°/s；采用920 m/s、12秒和5°/s。[NavWeaps 15.5cm](https://www.navweaps.com/Weapons/WNJAP_61-60_3ns.php) | 对海；不把高仰角能力当作有效自动AA指挥。每管150发。原模型最低仰角-10°保持安装机械界，战斗不依赖负角击穿自身。 |
| 12.7 cm Type89 / Common Type0 | 23.45 kg，700–725 m/s，初始14/持续8 rpm；取720 m/s、7.5秒；原资料确认可用定时引信。[NavWeaps Type89](https://www.navweaps.com/Weapons/WNJAP_5-40_t89.php) | 原基准23kg修正为23.45；只在航空目标上设置定时引信；24m是游戏有效破片半径，非保证摧毁半径。每管300发。 |
| 25 mm Type96 | Common约0.24kg、Incendiary Common约0.25kg，900m/s；循环200–260、有效110–120 rpm。[NavWeaps Type96](https://www.navweaps.com/Weapons/WNJAP_25mm-60_mg.php) | BB代表0.25kg、DD Common修正0.24kg；均以0.5秒近似有效供弹节奏，未逐15发换弹匣。2000发/管为本场配置；直击，无重高炮空爆。 |
| 13.2 mm Type93 | 实际口径13.2mm；AP约51.8g、805m/s，实用250 rpm。[NavWeaps Type93](https://www.navweaps.com/Weapons/WNJAP_13mm-76_mg.php) | 旧ID含13mm但运行口径修正.0132；0.24秒；以普通动能弹近似混合弹带，不模拟燃烧弹药理。2500发/管。 |
| 16in/50 Mk7 / AP Mk8 | 1225kg、762m/s、2 rpm；回转4°/s、俯仰12°/s；1940年代回转±150°，第二座最低0°。[NavWeaps Mk7](https://www.navweaps.com/Weapons/WNUS_16-50_mk7.php) | 30秒周期；130发/管为场景全部AP供弹，不称实际AP/HC配比；第二座另有最低仰角限制，不改变模型安装。 |
| 5in/38 Mk12 / AAC Mk34 | AAC25kg、792m/s；有轴心供弹的底座15–22 rpm。[NavWeaps Mk12](https://www.navweaps.com/Weapons/WNUS_5-38_mk12.php) | 取15 rpm、4秒。Iowa450发/管、Fletcher300发/管是本场供弹。Fletcher 的原 Mk32 Common（24.5kg）保持定义，通过战斗配置选择已载入的 AAC Mk34；不用Common弹冒充定时AAC。均采用机械时间引信，不把1942舰装上VT。 |
| Bofors 40mm / HE Mk1 | 0.900kg、881m/s；循环120、实用80–90 rpm。[NavWeaps Bofors](https://www.navweaps.com/Weapons/WNUS_4cm-56_mk12.php) | 取85 rpm平均有效供弹，2000发/管；直接碰撞，不按目标距离制造空爆。 |
| Oerlikon 20mm / HE Mk3 | 0.123kg；平均枪管835m/s；循环450、实用250–320 rpm。[NavWeaps Oerlikon](https://www.navweaps.com/Weapons/WNUS_2cm-70_mk234.php) | BB原820修正835m/s；取300 rpm；1500发/管是场景供弹。保留实际全部安装，不用抽掉炮位降负载。 |
| 1.1in/75 Mk1 / HE-T Mk1，Mk2炮架 | 0.416kg；新枪823、平均792m/s；循环150、实用约100 rpm。[NavWeaps 1.1in](https://www.navweaps.com/Weapons/WNUS_1-1-75_mk1.php) | 保留823新枪初速；0.6秒，800发/管场景配置，直击。炮架Mk2不是已淘汰的实验Mark2炮；本轮未加入SD自毁。 |
| 12.7cm/50 Type3，TypeC双联 / Common Type1 | 23kg、915m/s；5–10 rpm；TypeC -7..55°，训练4–6°/s，俯仰正式6–12°/s。[NavWeaps Type3](https://www.navweaps.com/Weapons/WNJAP_5-50_3ns.php) | 7秒/6°/s/12°/s；150发/管。本场对海职责，不把不适用快速空战的炮架当高效AA；Type1可配时间引信，但本场不用。 |
| AN/M2 .50航空枪 | 原始海军教材给750–850 rpm及约2900ft/s；飞机固定枪须靠机体转向。[USN《This Is Your Gun》G-2](https://www.ibiblio.org/hyperwar/USN/ref/AirGunnery/GUNS.html)；[1947 TM9-225](https://www.military-references.com/wp-content/uploads/books/machine-guns/M2_Browning_Aircraft_Basic_TM_9-225_1947.pdf)交叉核射速。 | 采用800 rpm（.075秒）、884m/s；45.8g为M2代表弹质量近似，尚未逐批次弹药表核准。F6F保持6枪与400发/枪；[海军馆藏](https://www.history.navy.mil/content/history/museums/nnam/explore/collections/aircraft/f/f6f-5-hellcat.html)确认6枪，[USNI Hellcat说明](https://www.usni.org/magazines/naval-history-magazine/2002/august/best-carrier-fighter)记录2400发。 |

[USN OP1112（1945）原始目录](https://legacy.maritime.org/doc/guncat/index.php)提供美舰炮架背景及原始资料入口；本轮没有把所有表页逐一量测，所以未据此声称所有炮架机械细节均有独立一手核准。NavWeaps为二手技术汇编，常引用USNTMJ、BuOrd等；表中已明确选择与未知项。

## 统一的游戏近似

- **弹道**：固定重力9.80665m/s²、无空气阻力、继承平台速度。不是历史射表，远距离飞行时间/入射角/能量不能当史实。range_m是交战许可上限，寿命是回收边界；不修改历史初速以平衡阵营。
- **命中/装甲**：分段船体盒、舰桥/烟囱盒、暴露炮位盒、飞机机身/翼尾薄盒。船体梁宽/长度来自正式模型数据；大和和两DD船壳按其站位取盒，Iowa按通过准入的大形分段。盒只是外包近似；不等于精密网格碰撞/内部舱室。炮架盒不含炮管细长体，不模拟炮管被击断。
- **毁伤**：`sqrt(energy_j)*damage_scale`乘明确的装甲/弹径效能及爆距衰减。护甲效能系数是粗略游戏代理，不叫历史穿甲公式。BB结构6000/5400，DD850/780，F6F90是游戏损伤单位。装甲带采用典型厚度410/307mm作整体代理，忽略角度/局部薄甲/跳弹；炮室650/495mm亦是粗代理。不能由这些数字推断真实舰船抗沉性。
- **持续伤情**：由实际HE命中开始失火，由水线附近有效命中开始进水。舰桥/操纵失能不自动沉没；后续结构或进水才造成沉没。无修理班、逐舱水动力和复杂火灾传播。
- **探测**：光学8–20km，舰载雷达22–50km是白昼场景能见度/扫描包络，不是某雷达型号的历史性能表；雪风1942没有雷达。地平线用3570×(√h1+√h2)米，静态地形和其他舰体可遮挡。无天气、电磁传播、雷达杂波和测角误差模型。
- **火控**：主炮/副炮/AA同一供弹入口；散布为每管独立均匀角圆盘；定时误差均匀±.18秒。散布、误差、AA范围和损伤半径均为游戏近似，未为阵营胜率反向调参。
- **供弹**：机枪/机关炮使用有效持续节拍摊销换匣/供弹，不呈现复杂供弹动画。各实际炮位都参与目标、射界、转速、库存和碰撞检查，只有真实职责/射界/状态导致停火。
- **友伤**：默认关闭伤害、保留拦截；发射者离开自身代理后不再永久免疫自碰。爆炸也按同一友伤开关并检查几何遮挡。
- **资源**：8192在飞弹丸、144显示槽（捕获时256）、8瞬态声音+4发动机循环。满弹丸池明确拒绝且不扣弹；显示槽优先保留空爆/弹着，丢显示不丢模拟。无 tick 丢弃或指定目标命中捷径。

S04 新增飞机参数：Type97鼻枪采用600rpm同步节拍（.1秒），500发/枪，11.3g代表弹、750m/s；Type99-2 Model4采用500rpm（.12秒），125发/炮，0.128kg代表HE、750m/s。[澳大利亚战争纪念馆实物说明](https://www.awm.gov.au/collection/C144576)核对Type97为Vickers E系的7.7×56R航空枪，不能套用同名坦克机枪。[Chinn/BuOrd《The Machine Gun》卷I第五部分](https://www.ibiblio.org/hyperwar/USN/ref/MG/I/MG-5.html)核对日制/Oerlikon航空机炮背景；具体52甲弹链125发沿用S04实际打开的厂商子型手册。[Pacific War Encyclopedia Type97](https://pwencycl.kgbudge.com/J/a/Japanese_7p7mm_Type_97_gun.htm)给代表AP弹11.3g/750m/s；600rpm是同步后的选用近似，尚无本轮完整同步器测试表。Type99代表弹质量与Model4精确射速仍标provisional，不把其他Type99子型或游戏维基当作已核准的一手表。

S03 的 `tools/s03/build_destroyer_data.py` 仍可生成其provisional基准。S05不手改这些输出，战斗覆盖独立保留。S04已发布A6M5a及飞行原点，S05已同步全部航空碰撞/传感器代理；A6M鼻枪通道保留，F6F盒统一减2.30m。新原点/通道独立几何与真实发射检查均有验收。

2026-11-10 集成修正：六型 `damage_effects` 是表现锚点，不是历史起火位置或新增毁伤模型。舰艇选择现有正式模型的外露甲板；飞机贴近机鼻发动机壳，随单位姿态变换。大和与 Fletcher 在实际 12% 火情下做网格射线核验，火焰中心分别距实际甲板约0.64m、0.81m，烟雾中心约1.64m、1.56m，上方均无遮挡。其余两舰位置按各型号甲板高度配置；没有为可见性调大 damage.fire，也没有统一移到舰桥顶。证据见 `docs/showcase/evidence/S05/damage_effect_anchors.json`。
