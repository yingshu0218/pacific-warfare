# A06 · B6N2 天山一二型外观初版

2026-11-27。仅展翼、收轮的静态游戏外观；不登记正式战斗单位，不改飞行、损伤、武器或观战入口。

- 参考 [Smithsonian PACMIRS 1674](https://www.si.edu/media/NASM/NASM-Manual-000033268.pdf?download=1) 印刷第 3–7 页（PDF 7–11）。已看原始扫描的正、俯、侧三视。正视和俯视标注 14.90 m，翼展表 14.894 m；侧视外廓长 10.865 m，总表另记 10.808 m，本游戏外廓以侧视为基准。用 [现存同型号的 Smithsonian 馆藏记录](https://collections.si.edu/search/detail/edanmdm%3Anasm_A19810429000) 的圆整值 14.90 × 10.90 m 作交叉核对。
- [AWM 129724 同型飞行照](https://www.awm.gov.au/collection/C237845) 与 [AWM AC0195 缴获后照片](https://www.awm.gov.au/collection/C22599) 只用来比对外形：狭长机身、压低的连贯座舱、圆翼尖、垂尾和四叶桨。标识及颜色不从缴获轮廓照片反推。当前绿灰是工作色，不对应已考据的具体机号。
- Godot 4.7.2 按实际三角面测得翼展 **14.900 m**、长 **10.865 m**、当前可见高 **3.689 m**，共 4,656 三角。可见高含固定桨位，不是历史停放高度。模型只保留外侧可见的形体，没有内部构造。
- 独立入口 `res://aircraft/b6n2/b6n2_viewer.tscn`，按 1／2／3 切换斜／侧／俯视。复用 TBM-1C 的展示几何工具和镜头；两型无尺寸耦合。后台验收 `godot --headless --path . --script res://tests/model_audit/test_b6n2_visual.gd`，并回归 TBM-1C 独立量测和 14 个正式场景加载。图为 Godot 实际网格离线渲染，不代表实时画面或浏览器性能。
