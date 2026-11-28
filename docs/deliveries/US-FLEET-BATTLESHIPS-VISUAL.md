# 美国太平洋舰队主力舰：战列舰外观

两艘都是独立的 Godot 静态外观场景。只含展台几何和统一的哑光表面，不接关卡、运动、碰撞、武器或任何实际舰载系统。

| 舰船 | 独立场景 | 实际外观参考 |
| --- | --- | --- |
| 北卡罗来纳号 BB-55，1944-09-24，普吉特湾 | `res://scenes/ships/us_fleet_battleships/north_carolina_visual.tscn` | [NHHC NH 104850，右舷舰艏斜视](https://www.history.navy.mil/our-collections/photography/us-navy-ships/battleships/north-carolina-bb-55/NH-104850.html)；[NavSource 转存美国海军同日高位侧视照片](https://www.navsource.net/archives/01/055/015553.jpg)；[美国海军 3110-44，同日右舷舰艉斜视](https://www.navsource.net/archives/01/055/015548.jpg)。 |
| 西弗吉尼亚号 BB-48，1944 年后期重建外观 | `res://scenes/ships/us_fleet_battleships/west_virginia_visual.tscn` | [19-N-68374，重建后右舷](https://www.history.navy.mil/our-collections/photography/us-navy-ships/battleships/west-virginia-bb-48/19-N-68374.html)；[19-N-68375，同日左舷](https://www.history.navy.mil/our-collections/photography/us-navy-ships/battleships/west-virginia-bb-48/19-N-68375.html)；[19-N-68376，右舷舰艏斜视](https://www.history.navy.mil/our-collections/photography/us-navy-ships/battleships/west-virginia-bb-48/19-N-68376.html)。照片均摄于 1944-07-02；另用 [80-G-314220，1944-11-13 干船坞高位舰艏视图](https://www.history.navy.mil/our-collections/photography/us-navy-ships/battleships/west-virginia-bb-48/80-G-314220.html)和 [NH 89346，十一月顶部视图](https://www.history.navy.mil/our-collections/photography/numerical-list-of-images/nhhc-series/nh-series/NH-89000/NH-89346.html)复核后期主体外形。 |

## 逐舰对图结论

- **北卡罗来纳号**：修订了较长的舰艏低前台、偏前且高瘦的分层舰桥、圆形开放天线和两根分立的椭圆烟囱；保留舰艏双、舰艉单的三联炮塔静态轮廓和舰艉的低平台。左右舷涂色分开处理，右舷可见舰艉前方的亮色宽块和向艏部斜升的深色边界。同日高位照片用于交叉核对桥、烟囱和舰艉之间的间隔。
- **西弗吉尼亚号**：按改装后较短而宽的舰身、宽阶梯舰桥、单根宽烟囱、前后各两座双联炮塔及矩形格状桅顶外形制作。七月两侧照片分别约束斜条色块和舰桥宽层；十一月高位舰艏照片只复核外轮廓，不复刻坞内遮挡、维修状态和临时用具。不混用战前笼式桅形。

涂装按档案黑白照片做了可辨认的分区，准确色值不可从照片判定，未逐线复刻历史涂装；甲板小件、艉部起吊架与水下船体是游戏外观简化，并非修复图或建造图。

## 验证

- Godot 独立实例加载成功；逐个用原生渲染的船首斜视、侧视、俯视和舰艉斜视比对缩略形体，另输出水线视角核对实拍。
- 模型实际外包围长度 BB-55 约 222.15 米、BB-48 约 190.23 米；前者的舰体涂层外宽约 33.00 米，后者重建鼓包约 35.19 米（是模型实测，不是工程史料）。两个场景没有碰撞对象。
