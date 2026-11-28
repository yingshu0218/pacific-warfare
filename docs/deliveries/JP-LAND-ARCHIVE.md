# 日军陆航外观展品 · 隼二型与飞燕一型

这是两件 Godot 游戏内独立静态摆件：设置了机体外壳、构型辨识所需的翼尾、固定展示姿态的螺旋桨与起落架。未注册对战单位，没有炮塔、开火、弹药、可操作的航空系统或碰撞逻辑。两架为单座定住外壳造型，不把机身固定位置的武装误处理成旋转炮塔。

| 场景 | 外观档案 | 对照结论和展示妥协 |
|---|---|---|
| `res://aircraft/jp_land_archive/ki43_ii.tscn` | [澳大利亚战争纪念馆 Ki-43-II，REL/12326](https://www.awm.gov.au/collection/REL:12326)；同期 [OG2758](https://www.awm.gov.au/collection/OG2758) 和 [OG2759](https://www.awm.gov.au/collection/OG2759)；[Pima 航空航天博物馆 Ki-43-IIb](https://pimaair.org/museum-aircraft/nakajima-ki-43/) 供整体外观交叉对照 | 保留短圆星形整流罩、三叶螺旋桨、狭尾梁、弧形翼尖。灰绿斑驳和白尾带取自 AWM 对 1943 年馆藏的描述；并非某一机号或其保存现状的复刻，也不把捕获后的缺损画进展品。 |
| `res://aircraft/jp_land_archive/ki61_i.tscn` | [澳大利亚战争纪念馆 129683：Ki-61.Ib 地面照片](https://www.awm.gov.au/collection/C237763)；[川崎重工航空事业沿革](https://www.khi.co.jp/history/business/aero.html) 供型号身份核对 | 对比照片核对长而细的液冷机鼻、向后倾斜的垂尾前缘、翼根下方隆起和液冷进气罩。采用一型早期短机鼻的游戏近似比例和中性灰铝涂装。馆藏照片并非精确三视图，几何不宣称量测复原；不把现存二型改当成一型原件。 |

## 本地验证

`godot --headless --path . --script tests/model_audit/test_jp_land_archive.gd`。检查两模型都可独立加载、可见几何与材质的有效性、机身长宽包络、有没有误装另一个型号的辨识块，以及没有碰撞和动画控制。Godot 4.7.2 Compatibility 原生斜视、侧视、俯视与正视截图均实拍，没有使用档案照片作纹理。

| 模型 | 目测包络宽 × 高 × 长（项目尺度） | 可见网格数 |
|---|---:|---:|
| 隼二型 | 10.840 × 3.310 × 8.912 | 237 |
| 飞燕一型 | 12.000 × 3.440 × 8.756 | 135 |
