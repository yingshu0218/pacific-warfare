# 大鹰号：1943 年 9 月 30 日横须贺外观

**大鹰（Taiyō／原春日丸），无舰岛的改装航母外观。** 不是大凤（Taihō），不套用姊妹舰云鹰、冲鹰，亦不混入大鹰号 1944 年延展后的飞行甲板和晚期细节。以公开档案可辨的大比例为准，仅独立静态游戏展品。

## 参考及证据界限

- 直接查看了 [吴市海事历史科学馆藏横须贺实舰照片，1943-09-30](https://commons.wikimedia.org/wiki/File:Japanese_aircraft_carrier_Taiy%C5%8D.jpg) 的 3377×2226 原图，并分别放大前后段。以其近舷侧轮廓约束客货轮原船体的高艏、圆艉、舷侧舷窗与低平台、飞行甲板明显在舰艏之后结束、艏艉下方见光的支撑空间和中段长机库立面。照片为黑白近侧视，不用于凭空确定高度、对舷构件、精确甲板线色、逐件位置或水下形体。
- [日本国立国会图书馆所藏海军舰船清册（航母）](https://upload.wikimedia.org/wikipedia/commons/f/f0/NDL12924244_Pros._Doc._No._6263-_Japanese_Navy_Ships_%28carriers%29.pdf) 将大鹰明确记作春日丸改装。该身份记录不是尺寸/照片来源。[美国海军 80-G-65853](https://www.history.navy.mil/our-collections/photography/numerical-list-of-images/nhhc-series/nh-series/80-G-65000/80-G-65853.html) 未能在大鹰、云鹰、冲鹰中确定舰名，不以其替代上述明确同舰照片。
- 游戏比例基准采用长 180.20 m、型宽 22.50 m、展示水线吃水 7.70 m 及早期短甲板 162.00×23.50 m。[早、晚阶段甲板尺寸区分](https://www.navypedia.org/ships/japan/jap_cv_taiyo.htm) 为次级尺度参考；其变型、载况及口径并不完全统一，不把输入值宣称为照片实测。材质为中性展示工作色；吊艇、舱窗、支撑、下水线和静态平台为可见轮廓估形，不复刻内部和可用零件。没有飞机、可动升降机或战斗接口。

## 独立检视与复验

- Godot 4.7.2 从 `res://naval/carrier_gallery/taiyo_viewer.tscn` 打开，键位 1 斜视、2 舷侧、3 甲板俯视、4 去水面。
- `godot --headless --path . --script tests/carrier_gallery/test_taiyo_gallery.gd`；设置 `TAIYO_GLB=/absolute/path/taiyo.glb` 可导出通过相同检视入口实例化的真实外观网格。
- 实测船体 180.200×22.500 m、展示吃水 7.700 m，飞行甲板 162.000×23.500 m，9,676 个三角面，船壳开边与非流形边 0。四视角入画、相机和水面切换通过；通过三角网格穿线检验艏艉下方留有真实开口、中段机库封闭、桥顶未穿出甲板。交付对照图由实际 GLB 离线渲染，非游戏实时截图。
