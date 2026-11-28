# 加贺、飞龙 · 独立航母外观

两个场景都是 1942 年前后代表状态的静态游戏展品。舰体、主甲板、舰桥、烟道外壳与舷侧外观手工塑造。未让照片中无法辨认的细件看起来像精确考据，不复刻内部结构，当年涂装及细小舷侧设施也不作精确主张。

| 模型 | 不同的轮廓 | 优先核对的档案 |
| --- | --- | --- |
| 加贺，改装后单层飞行甲板型 | 宽厚的改装舰体、较平直且宽的木甲板、偏前的右舷舰桥、后接突出并向外下翻的烟道外形、两端甲板下缘支架。 | [NH 73060，1934–36 改装结束后](https://www.history.navy.mil/our-collections/photography/numerical-list-of-images/nhhc-series/nh-series/NH-73000/NH-73060.html)；[NH 75483，约 1941 年 12 月](https://www.history.navy.mil/our-collections/photography/wars-and-events/world-war-ii/pearl-harbor-raid/japanese-forces-in-the-pearl-harbor-attack/miscellaneous-views-of-japanese-forces/NH-75483.html) |
| 飞龙，1942 年代表状态 | 较窄且前后收尖的快舰轮廓、中段左舷叠层舰桥、对舷低置分段烟道外形、前后飞行甲板与船体轮廓分离。 | [NH 73063，1939-04-28 试航照](https://www.history.navy.mil/our-collections/photography/numerical-list-of-images/nhhc-series/nh-series/NH-73000/NH-73063.html)；[USAF 75712，1942-06-04 航拍](https://www.history.navy.mil/our-collections/photography/wars-and-events/world-war-ii/midway/USAF-75712.html) |

加贺与飞龙的展品场景分别是 `scenes/ships/jp_fleet_carriers/kaga_visual.tscn`、`scenes/ships/jp_fleet_carriers/hiryu_visual.tscn`。每舰选做 12 处舷侧装饰展台；不是历史装备数量表。展台用游戏通用展示节点隔离转向块与俯仰块，不带可用组件、弹药、实战参数、战斗，也不宣称平台布置与档案的实舰精确一致。Godot 测试逐个摆动并回零全部 24 个展台，周围的展台及舰体不随之改变。原生截图检查了艏斜视、侧视、俯视及艉斜视。
