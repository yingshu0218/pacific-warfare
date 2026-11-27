# 巴尔的摩号 CA-68 · 1944 年 10 月静态外观

这是新编写的完整独立游戏外观，不是找回先前提交的原文件；不接入任何操作、观战机制或内部结构。

- 1944-10-21 马雷岛改装结束时的外观作为版本锚点。主要外形证据是 [10 月 18 日同舰全侧斜视 NH 91462](https://www.history.navy.mil/our-collections/photography/numerical-list-of-images/nhhc-series/nh-series/NH-91000/NH-91462.html)、同舰尾斜视 NH 91464，以及同舰近日期的 [舰艏](https://www.history.navy.mil/our-collections/photography/numerical-list-of-images/nara-series/19-n/19-n-70000/19-n-74297.html)、[舰中](https://www.history.navy.mil/our-collections/photography/numerical-list-of-images/nara-series/19-n/19-n-70000/19-n-74298.html) 与 [舰艉](https://www.history.navy.mil/our-collections/photography/numerical-list-of-images/nara-series/19-n/19-n-70000/19-n-74299.html) 高位照片。保留前部层叠舰桥、高低双烟囱、双桅、宽艉、艉甲板两座装卸吊架和低平舱盖；不把照片后方的其他舰或图上注记复制到模型。
- [DANFS](https://www.history.navy.mil/research/histories/ship-histories/danfs/b/baltimore-v.html)：673 英尺 5 英寸全长、70 英尺 10 英寸船体宽、20 英尺 6 英寸平均吃水作为模型名义尺度；不等于照片当日精确载荷。
- Design 16D 的 [左舷](https://www.history.navy.mil/our-collections/photography/numerical-list-of-images/nara-series/80-g/80-g-100000/80-G-109724.html) 和 [右舷](https://www.history.navy.mil/our-collections/photography/numerical-list-of-images/nara-series/80-g/80-g-100000/80-G-109723.html) 原图均已查看。全舰侧面使用独立、方向正确的左右舷色块，不是一侧镜像。这里仅按档案线索重构大色块，灰蓝是工作颜色、上建及甲板色并未逐处考证。
- 外观细部都是非操作的游戏几何件。斜视原照与色版不是测绘，遮蔽位置和水下曲面、小件为估形。
- 场景 `res://scenes/ships/baltimore_ca68/baltimore_viewer.tscn`。Godot 4.7.2：模型 205.257 × 21.590 m，设计水线下 6.248 m，12,972 三角面，船体开边、非流形边 0；四角度所有顶点投影在图框内。用 `godot --headless --path . --script tests/model_audit/test_baltimore_rebuilt.gd` 复现，追加 `-- /tmp/baltimore.glb` 导出实际网格；离线板不属于实时游戏截图。
