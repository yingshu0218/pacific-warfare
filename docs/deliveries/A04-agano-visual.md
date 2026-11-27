# 阿贺野号 · 1942 年 10 月全舰独立外观

这是重新编写的游戏外观，不是此前提交的源文件或逐字节恢复。以 [三笠纪念馆收藏的日本海军同舰照片](https://commons.wikimedia.org/wiki/File:Japanese_cruiser_Agano.jpg) 为直接外部依据：佐世保外海 1942 年 10 月。保留上扬艏部、细长舰身、层叠前桥、单宽斜烟囱、双桅和可见的后甲板停放机轮廓。舰桥窗、翼台、后部作业甲板、栏杆和艇架为照片引导的独立网格，不是简单重缩放其他舰船。

- [美国海军造舰资料](https://www.history.navy.mil/research/library/online-reading-room/title-list-alphabetically/j/japanese-naval-shipbuilding.html) 用于舰名／舰级背景；[NPS 同级舰考古报告](https://www.npshistory.com/series/archeology/scrc/37/chap3.htm) 中平甲板、艏舷弧和球艏描述仅作同级外轮廓交叉参考，较晚的酒匂号照片不作为同舰配置来源。
- 模型名义外廓约束 174.100 × 15.200 m、设计水线下 5.630 m。照片斜视、黑白，不是尺度／涂装测绘。遮蔽部分、小件和水下形状以及颜色是工作估值。停放机不指定型号，装备是纯静态外部视觉，未接正式观战或任何操作。
- 入口 `res://scenes/ships/agano_1942/agano_viewer.tscn`，按 1–4 检视斜视、舷侧、俯视、全船（无水面）。以 `godot --headless --path . --script tests/model_audit/test_agano_rebuilt.gd` 复测；追加 `-- /tmp/agano.glb` 导出实际网格。Godot 4.7.2 实测 10,232 三角面，主体船体开边/非流形边为 0，四镜头全部顶点在框内。离线图来源于实际 Godot 网格，不是实时游戏截图。
