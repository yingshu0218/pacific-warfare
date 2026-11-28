# 武藏号 · 1944 年 10 月文莱湾代表外观

场景：`scenes/ships/jp_musashi_1944/musashi_visual.tscn`，已纳入全单位展厅。独立建模，未实例化大和号场景或借用其作战数据。

- [NHHC NH 63473](https://www.history.navy.mil/our-collections/photography/numerical-list-of-images/nhhc-series/nh-series/NH-63000/NH-63473.html) 是主体轮廓来源。观察艏艉低长线条、中段舰桥与后倾单烟囱的相对高度。日期档案注明可能是 10 月 22 日；不当作该日的确定影像。
- [NHHC NH 73090](https://www.history.navy.mil/our-collections/photography/numerical-list-of-images/nhhc-series/nh-series/NH-73000/NH-73090.html) 的左侧远景用于交叉确认身份和外形，不据远景补画看不见的细件。[美国海军国家博物馆武藏资料](https://www.history.navy.mil/content/history/museums/nmusn/explore/photography/wwii/wwii-japan/ships/musashi-battleship.html) 汇集本舰其他视角。
- 模型保留紧凑塔式舰桥、后倾烟囱、前高后低的艉部水上机作业区。中心线展品有 3 座三联主炮外壳、2 座三联副炮外壳；舷侧防空位为开放式和有罩外观的代表性简化，不是完整历史库存。只用独立的闭口几何做展厅摆姿，不加入发射、作战逻辑和实际性能。
- 原生 Godot 检查：艏斜、艉斜、侧、俯视及舰桥近景。检查了独立层次、支撑、尾部台阶和三联轮廓；局部和颜色按统一展厅风格简化。
- `tests/model_audit/test_jp_musashi_archive.gd`：72 项通过。共 39 舰、18 机，展厅风格回归无失败；通用摆姿回归覆盖 208 处独立艺术模型。
