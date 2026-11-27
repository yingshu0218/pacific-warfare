# A04 · 克利夫兰号 CL-55 整舰外观

本版为 **1944-05-19、秋季改装前** 的独立可查看游戏外观，不接入正式观战。整舰包括连续水下/水上船体、天气甲板、舰桥和前后甲板室、双烟囱和两组桅杆、主要外露体块、栏杆、勤务小艇与舰尾设施；仅作游戏识别，不提供内部结构或运作参数。工作色用于区分体块，不当作确证的战时油漆。小件与水下外形为视觉估形。

## 资料与核对口径

- [美国海军 CL-55 舰史](https://www.history.navy.mil/research/histories/ship-histories/danfs/c/cleveland-ii.html)：按其中记载的长 610 英尺 1 英寸、宽 66 英尺 6 英寸、吃水 20 英尺制作游戏体量。吃水为模型设计水线至龙骨的约束，不是档案照片当天的实测载荷。
- [80-G-232270，1944-05-19](https://commons.wikimedia.org/wiki/File:USS_Cleveland_(CL-55)_underway_in_Solomon_Islands_waters_on_19_May_1944.jpg)：已查看扫描并放大舷侧，核对艏艉方向、双桅双烟囱和整体上建体量；背景中的另一事件不作为游戏内容。
- [NH 98059，1944-01-12](https://commons.wikimedia.org/wiki/File:USS_Cleveland_(CL-55)_in_floating_drydock_ABSD-1_off_Espiritu_Santo_on_12_January_1944._(NH_98059).jpg) 和 [2173-44，1944-01](https://commons.wikimedia.org/wiki/File:USS_Cleveland_(CL-55)_in_floating_drydock_ABSD-1_off_Espiritu_Santo,_in_January_1944.jpg)：同舰干船坞照片辅助识别舰艏和上建层级；不是 5 月同日正投影。
- [NH 55173，1942 年末](https://www.history.navy.mil/our-collections/photography/numerical-list-of-images/nhhc-series/nh-series/NH-55000/NH-55173.html)：实际看了较早的高位斜视，补充甲板分层辨识，不把前期涂装或小件当作 5 月的确证。

## 复验

- Godot 4.7.2 运行 `res://scenes/ships/cleveland_cl55/cl55_viewer.tscn`，1 斜视、2 舷侧、3 俯视、4 完整船体（切去水面）。复测入口 `godot --headless --path . --script res://tests/model_audit/test_cl55_visual.gd`。
- 实际网格量得船体全长 **185.953 m**、最大船体宽 **20.269 m**、设计水线下 **6.096 m**（不计外部装饰投影）。验证船体三角面闭合、四种镜头的舰首/舰尾/桅顶都在画面中，并回归正式场景加载。
- 交付图使用实际 Godot 网格离线渲染，不是实时游戏截图，也没有据此宣称 Web 帧率、操作、交战或统一模型入册通过。
