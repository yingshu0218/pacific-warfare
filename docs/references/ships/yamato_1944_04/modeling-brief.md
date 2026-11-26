# 大和号 1944 年 4 月：S02 参考与外形交接

状态：S02 已实施并提交统筹验收。所选身份固定为 1944 年 4 月改装后；不是 1941 或 1945 全套配置。原始图逐张实际打开，台账见 [sources.json](sources.json)。既有 [AI v03](target/yamato-outer-form-preview-v03.png) 继续只作材质与简化程度参考，不用于位置、炮管数或几何量测。本轮未生成新的 AI 几何依据。

## 实际看过的原图与用途

| ID | 原图 / 视角 | 本轮用途 | 限制 |
| --- | --- | --- | --- |
| Y-PLAN | [1944.2–6 完整俯视](original/yamato-1944-02-to-06-plan.png)，Modelkasten 公开预览 PDF6 / 印刷5 图3 | 三座三联主炮、前后两座中线三联副炮；舰体平面边界和前后关系 | 出版者复原图，不含绝对标高，不称船厂站位 |
| Y-SIDE | [1941-10-10 试航完整侧面](original/yamato-1941-trials-and-context.png)，PDF5 / 印刷4 | 共通舰体起伏、舰桥与烟囱比例、主炮总体关系 | 1941 舷侧 155 mm 和 AA 不能移到本配置 |
| R01 | [田宫官方完整艏斜前模型照](images/tamiya-78030-full-model.jpg) | 完整三维体量、艏艉与主要建筑关系 | 晚期套件；不是 April 1944 小武器清单 |
| Y-PROFILE | [田宫 78030 第18页：整舰侧/俯](original/yamato-late-fit-side-and-plan.png) | 下凹前炮甲板、抬升舯部、降低后航空甲板、前后 155 mm 层级 | 晚期套件只借共有结构；数值为图像比例 |
| Y-BRIDGE | [田宫第12页：舰桥/后桥斜视](original/yamato-common-bridge-assembly.png) | 连续圆弧与折角主体、外伸观察平台、测距仪与后桥 | 不引用其 1945 小型防空数量 |
| Y-HOSTS | [田宫第14页：真实承载与炮座](original/yamato-common-deck-and-barbettes.png) | 前副炮实际舰桥基部、后副炮真实炮座围壳、连续高炮平台 | 非原舰测绘，底座绝对高度仍图像估算 |

资料覆盖为侧面、完整平面、艏斜视和桥/炮座结构；没有能证明全部 April 1944 小附件的高分辨率同期照片。后期共通结构与选定日期的防空清单明确分开。Skulski/Draminski 的[出版者预览](https://api.pageplace.de/preview/DT0400.9781472832221_A35506816/preview-9781472832221_A35506816.pdf)印刷18、23–24亦已实际读页；干舷和武器编制沿用其依据。[原始 Modelkasten 预览](https://gigaplus.makeshop.jp/modelkasten/book/234313-.pdf)支持 dated 平面布置。

## 主副炮逐座证据

+X 右舷，+Y 向上，-Z 舰艏；原点是263 m总长的中点与检查水线交点。下列 Y 为回转武器的座面，不是炮轴；炮轴和实际炮口由模块局部变换给出。表内 ID 为项目稳定 ID。

| station_id | 固定炮型与管数 | 武器座面 x, y, z / m | 宿主 | 位置依据 |
| --- | --- | --- | --- | --- |
| main_01 | 460 mm 三联 | 0.000, 7.200, -50.254 | main_deck | Y-PLAN；Y-HOSTS/Y-PROFILE 核层级 |
| main_02 | 460 mm 三联 | 0.000, 11.400, -30.498 | main_deck | Y-PLAN；Y-HOSTS/Y-PROFILE 核层级 |
| main_03 | 460 mm 三联 | 0.000, 8.700, 64.577 | main_deck | Y-PLAN；Y-HOSTS/Y-PROFILE 核层级 |
| secondary_01 | 155 mm 三联 | 0.000, 16.000, -9.508 | fore_bridge_base_roof | Y-PLAN；Y-HOSTS/Y-PROFILE 核层级 |
| secondary_02 | 155 mm 三联 | 0.000, 13.600, 49.760 | aft_shelter_deck_roof | Y-PLAN；Y-HOSTS/Y-PROFILE 核层级 |

三座主炮共9管；两座副炮共6管，全部保留。前两座主炮与前副炮朝艏，后副炮与第三主炮朝艉。平面坐标保留同一 dated 图的描点；垂向关系重核并修正，未把旧估位升级为原厂尺寸。后副炮相对第三主炮保持超射层级，必要净空由真实炮座高度提供。

## 本轮差异与安装

- 舰体：原先几乎全程高前甲板改为资料中的下凹前炮甲板、舯部抬升和较低航空甲板；俯视描点包络用于甲板边界。宽度38.9 m为模型最大包络，载况/水线宽与此分开。水下壳体仍为程序截面；新增简洁防污红和水线色面。
- 舰桥：去掉规则方形阶梯外观，改成连续圆弧、多边形核心和较薄的外伸平台；缩小主测距仪中央过粗体量，保留约15 m测距基线；不增做微小细节。
- 155 mm：修正前炮座所依托的舰桥基部、后炮座的连续舱面围壳，区分固定底座、回转炮室和俯仰轴。没有临时柱/梁补缝。
- 每个 foundation 现挂在其宿主 Marker 下；actual host mesh 接触测试排除 foundation 自身。模块保留 Hull、SuperstructureDecks、Bridge、AftBridge、FunnelAndRigging、AftEquipment、各座 Foundation / Train / Elevation。

## 防空历史与游戏配置

历史工作基准：12座双联127 mm、24座三联25 mm、26座单装25 mm；两座13 mm双联的确切 April 日期/安装高度仍有限制。本轮游戏为 **12双联127 + 12三联25 + 8单装25 + 2双联13**，与主副炮合计39座。删减的是专用轻防空；没有改动主副炮编制。只保留有明确连续甲板宿主的组位，完整实际清单在 `data/yamato_1944_mounts.json`、正式单位定义与运行模型中一致。旧69座工作坐标存为 [pre-s02-provisional-mounts.json](pre-s02-provisional-mounts.json)，它不代表历史精确点位。

## 同模型验证与剩余精度

原生六视图：[侧](../../../showcase/evidence/S02/jp_yamato_1944_04_side.png)、[俯](../../../showcase/evidence/S02/jp_yamato_1944_04_top.png)、[艏斜](../../../showcase/evidence/S02/jp_yamato_1944_04_bow_quarter.png)、[艉斜](../../../showcase/evidence/S02/jp_yamato_1944_04_stern_quarter.png)、[前炮区](../../../showcase/evidence/S02/jp_yamato_1944_04_fore_battery.png)、[后炮区](../../../showcase/evidence/S02/jp_yamato_1944_04_aft_battery.png)。无迷彩/统一材质版本同目录带 `_neutral_`。全舰图有完整艏艉，局部近图单独标识。

数值标高、横剖面、球鼻艏、隐藏面和部分小型防空结构仍是根据上述图像的比例复原，不宣称毫米精确或原厂型线。船体/建筑的大形及主副炮与来源的符合程度交统筹据原图和当前截图独立判断；执行测试绿灯不替代历史外形验收。细密栏杆、内舱、机构和铆钉后置；浏览器性能由S08检查。
