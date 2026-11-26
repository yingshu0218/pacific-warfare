# USS Iowa BB-61：1944-12-28，S02 参考与装配

状态：S02 实施后待统筹验收。身份与日期来自官方舰照80-G-421124；[历史背景](../../../../iowa/docs/historical_basis.md)仍保留早期研究与异期使用边界，本文件和 [sources.json](sources.json)为本轮实际看图台账。没有把既有 provisional 坐标作为已知事实。

## 实际打开的完整原始照片 / 图纸页

| ID | 日期 / 原图 / 视角 | 用途 | 使用限制 |
| --- | --- | --- | --- |
| 80-G-421124 | [1944-12-28 高位艉斜全舰](original/80-G-421124.jpg) | exact-date 主炮、每舷5座副炮、层级、前后桥及烟囱、舰尾设备关系 | 透视与船坞遮挡，不量成正投影 |
| 80-G-304057 | [1944-12-27 艏斜全舰](original/80-G-304057.jpg) | 倾斜前缘、细艏与舷外张、1944开放舰桥、圆形装甲司令塔 | 比选定日早一天；强透视 |
| 80-G-304058 | [1944-12-27 近正艏](original/80-G-304058.jpg) | 舰艏横向轮廓、窄上桥、主炮每座3管 | 船坞遮挡舷侧 |
| 80-G-358652 | [1944-08-08 左舷近侧](original/80-G-358652.jpg) | 全舰长高比、双烟囱、纤细高前桥和后指挥塔 | 较早且远景，不能断言December轻AA |
| 80-G-235080 | [1944-01-24 右舷近侧](original/80-G-235080.jpg) | 整体共通轮廓、长前甲板、前二后一主炮关系 | 较早涂装边界和小件不可直接移植 |
| 80-G-235084 | [1944-01-24 高位艏斜](original/80-G-235084.jpg) | 连续上层炮甲板、每舷三高/两低副炮 | 远方姐妹舰排除，不量透视尺寸 |
| I-PLAN | [田宫31616第3页1944侧/俯图](original/tamiya-31616-1944-profile-and-plan.png) | 数字化主副炮中心、舰体甲板包络，配合dated照片确认而非沿用旧点 | 制造商模型图，涂装说明为June1944；不是船厂总布置 |
| I-ASSEMBLY | [田宫第2页装配](original/tamiya-31616-bridge-and-installation.png) | 连续结构甲板、真实副炮宿主、开放桥翼、各型炮架 | 不证明绝对高度或December所有小件 |

照片为官方海军/NARA原件的[档案照片镜像](https://www.usndazzle.com/ship.php?id=126)；[NHHC的421124条目](https://www.history.navy.mil/content/history/museums/nmusn/explore/photography/ships-us/ships-usn-i/uss-iowa-bb-61/80-g-421124.html)日期/编号已由检索核对，原图本轮从可访问镜像取得并逐张打开。WWII Museum和部分NHHC直接下载本轮403/超时，未把访问失败写成看过。[田宫公开说明书原件](https://cdn.simba-dickie-group.de/downloads/300031616/300031616_Anleitung_Instruction_BB-61_Iowa.pdf)完整读了3页；图纸作为形状和相对站位原始输入，不称军方实测图。图像读数约±0.8 m，绝对高度仍比例估计。

## 主副炮逐座

+X右舷、-Z舰艏，270.4 m总长的中点在z=0。x/z依同一原图，未镜像错置副炮。下列项目ID保持稳定，**不是美国海军51/52等正式座号的映射声明**。

| station_id | 固定炮型/每座管数 | x, z / m | 实际宿主 | 证据 |
| --- | --- | --- | --- | --- |
| main_01 | 406 mm 三联 | 0.000, -58.798 | weather_deck + 真实16in炮座 | I-PLAN 炮位；80-G-421124序位/方向 |
| main_02 | 406 mm 三联 | 0.000, -33.096 | weather_deck + 真实16in炮座 | I-PLAN 炮位；80-G-421124序位/方向 |
| main_03 | 406 mm 三联 | 0.000, 66.896 | weather_deck + 真实16in炮座 | I-PLAN 炮位；80-G-421124序位/方向 |
| secondary_01_port | 127 mm 双联 Mk28 | -7.570, -8.274 | battery_deck | I-PLAN 逐座描点；dated 舰照核错列/层级 |
| secondary_01_starboard | 127 mm 双联 Mk28 | 7.570, -8.274 | battery_deck | I-PLAN 逐座描点；dated 舰照核错列/层级 |
| secondary_02_port | 127 mm 双联 Mk28 | -12.323, 0.704 | weather_deck | I-PLAN 逐座描点；dated 舰照核错列/层级 |
| secondary_02_starboard | 127 mm 双联 Mk28 | 12.323, 0.704 | weather_deck | I-PLAN 逐座描点；dated 舰照核错列/层级 |
| secondary_03_port | 127 mm 双联 Mk28 | -7.746, 12.499 | battery_deck | I-PLAN 逐座描点；dated 舰照核错列/层级 |
| secondary_03_starboard | 127 mm 双联 Mk28 | 7.746, 12.499 | battery_deck | I-PLAN 逐座描点；dated 舰照核错列/层级 |
| secondary_04_port | 127 mm 双联 Mk28 | -12.323, 29.575 | weather_deck | I-PLAN 逐座描点；dated 舰照核错列/层级 |
| secondary_04_starboard | 127 mm 双联 Mk28 | 12.323, 29.575 | weather_deck | I-PLAN 逐座描点；dated 舰照核错列/层级 |
| secondary_05_port | 127 mm 双联 Mk28 | -7.746, 39.609 | battery_deck | I-PLAN 逐座描点；dated 舰照核错列/层级 |
| secondary_05_starboard | 127 mm 双联 Mk28 | 7.746, 39.609 | battery_deck | I-PLAN 逐座描点；dated 舰照核错列/层级 |

全舰主炮3座×3=9管，5-inch副炮10座×2=20管。每舷第1/3/5组在连续 battery_deck 顶面，第2/4组在外侧 weather_deck；不是沿舰全长等间距布置。5-inch 兼任防空但属固定副炮，全部保留。炮位 Y、炮轴与局部炮口坐标看正式 `data/units/us_iowa_bb61_1944_12_28.json`；每管炮口来自实际枪管末端的 Marker，不另猜世界坐标。

## 已修外形与模块关系

修正旧主炮-91/-59/+91 m造成的过大间距、旧副炮放到前主炮之间/前方的错误；重建三高两低错列和连续上层炮甲板。细艏包络重采样并加真实斜艏，去掉因此悬空的水线细杆。1944前桥采用圆形装甲司令塔、开放观察/导航甲板和窄高的连续圆弧支承塔；没有套入1945宽封闭桥。双烟囱独立，开口覆盖其合理椭圆/折角顶部，不再是大盖板上的小孔。后指挥塔和桅杆分离，保留资料中的主要层级与位置。

Root模型通过 `assets/naval/models/us_iowa_1944/` 中四个**相对资源目录软链接**复用原 `iowa/`；不复制或整体搬迁独立工程，排除其project.godot/缓存。原场景脚本用相对资源路径，独立查看器继续可用。适配器关闭其本地展示时钟，固定座、回转轴、独立3根主炮俯仰轴及实际炮口保持独立。

## 防空与材料边界

历史工作假定19座四联40 mm、52座单装20 mm不作为exact-date已证实清单；后期ONI不能倒推December完整小炮编制。本轮游戏配置 **19四联40 mm + 26单装20 mm**，全部具有固定甲板宿主，炮塔顶的轻防空未纳入本轮游戏配置。省略/选择不同专用AA组位明列为游戏安排，防止将父炮旋转耦合错误写入S01平面socket；没有删5-inch副炮。各站实际名单在 `iowa/data/december_1944.json` 及正式单位定义，与运行时一致。

Measure32 Design1B保留；两舷图案同源近似、色值和精确斑块未知。本轮修复迷彩随舰移动和炮室回转时的坐标固定，并合批静态外壳。验收另有全部网格统一材质的中性六视图，以免迷彩遮挡轮廓。没有新做AI几何参考，沿用 `simplified-historical-v0.2` 的材质和细节上限。

## 同模型证据与限制

[侧](../../../showcase/evidence/S02/us_iowa_bb61_1944_12_28_side.png)、[俯](../../../showcase/evidence/S02/us_iowa_bb61_1944_12_28_top.png)、[艏斜](../../../showcase/evidence/S02/us_iowa_bb61_1944_12_28_bow_quarter.png)、[艉斜](../../../showcase/evidence/S02/us_iowa_bb61_1944_12_28_stern_quarter.png)、[前炮区](../../../showcase/evidence/S02/us_iowa_bb61_1944_12_28_fore_battery.png)、[后炮区](../../../showcase/evidence/S02/us_iowa_bb61_1944_12_28_aft_battery.png)；同目录 `_neutral_` 为同相机全部网格统一材质版。

水下截面、桥台截面、绝对层高与小附件为上述图像约束下的程序复原，没有声称找到并量过1944船厂型线。OP-769来自1968 New Jersey，用于共用主炮炮室基本尺寸和独立俯仰，不作为Iowa December外观细节依据。循环射速、库存与新弹药参数仅用于让数据目录可载入，全部provisional，S05须核实；本轮不写火控/发射/弹道。浏览器兼容与性能由S08统一测试。
