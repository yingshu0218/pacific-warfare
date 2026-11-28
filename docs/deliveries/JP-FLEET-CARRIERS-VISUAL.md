# 加贺、飞龙 · 独立航母外观

两个场景都是 1942 年前后代表状态的静态游戏展品。舰体、主甲板、舰桥、烟道外壳与舷侧外观手工塑造。未让照片中无法辨认的细件看起来像精确考据，不复刻内部结构，当年涂装及细小舷侧设施也不作精确主张。

| 模型 | 不同的轮廓 | 优先核对的档案 |
| --- | --- | --- |
| 加贺，改装后单层飞行甲板型 | 宽厚的改装舰体、较平直且宽的木甲板、偏前的右舷舰桥、后接突出并向外下翻的烟道外形、两端甲板下缘支架。 | [NH 73060，1934–36 改装结束后](https://www.history.navy.mil/our-collections/photography/numerical-list-of-images/nhhc-series/nh-series/NH-73000/NH-73060.html)；[NH 75483，约 1941 年 12 月](https://www.history.navy.mil/our-collections/photography/wars-and-events/world-war-ii/pearl-harbor-raid/japanese-forces-in-the-pearl-harbor-attack/miscellaneous-views-of-japanese-forces/NH-75483.html) |
| 飞龙，1942 年代表状态 | 较窄且前后收尖的快舰轮廓、中段左舷叠层舰桥、对舷低置分段烟道外形、前后飞行甲板与船体轮廓分离。 | [NH 73063，1939-04-28 试航照](https://www.history.navy.mil/our-collections/photography/numerical-list-of-images/nhhc-series/nh-series/NH-73000/NH-73063.html)；[USAF 75712，1942-06-04 航拍](https://www.history.navy.mil/our-collections/photography/wars-and-events/world-war-ii/midway/USAF-75712.html) |

## 本轮分型修正

- **加贺**：右舷前段舰岛增设后部信号室与下层观察窗；舷侧展品分为嵌于后段船壳的 10 个单管炮廓轮廓，以及较高平台上的 8 座双联轮廓和 6 座选做轻型装饰。低炮廓和高平台不是同一套造型。
- **飞龙**：左舷舰岛增设舷外走道、后部斜肩及独立窗带。没有加贺式低位炮廓；独立做出 6 座较高的开放式双联轮廓及 6 座选做轻型展品。展厅把前者归入副炮展示分组，不表示实舰分类等同于加贺的低炮廓。
- 档案比对补充：[历史配置对照，Ewa Plain Battlefield，表内 Hiryu 与 Kaga as reconstructed](https://dlnr.hawaii.gov/shpd/files/2015/05/HI_HonoluluCounty_Ewa-Plain-Battlefield.pdf)。旧照片用于确认可见的舰岛和舷侧关系；被遮挡的局部和轻型装备是简化表现，不承诺逐点测绘还原。只调整 Godot 展厅的造型和装饰检视，不接入战斗。
- `tests/model_audit/test_jp_exhibit_refit.gd` 覆盖三舰的独立展品、左右舷、单管/双联分组、竖向错层和两艘航母的结构差别。整批用原生 Godot 渲染艏斜视、对舷艉斜视、侧近景和俯视后，统一跑展厅回归。
