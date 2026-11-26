# S14 全单位与兵器清单

2026-11-11，最终集成清单。当前实际入口：`res://showcase/all_units.tscn`。16份 `data/scenarios/s14_*.json` 均为 **19 个模拟单位、9 种型号**：4舰、6架 F6F、4架 A6M、2架 SB2C、1座岸炮、2座 M1。共享固定地图 `data/maps/island_harbor.json` 与 S13 云海。没有将模块、机场或仅有参考资料的机型重复计数。

SB2C r2、S04-training、FX01和DM01已按各自专项准入接入；完整场景与有界Chrome已自验，最终统筹状态见 `acceptance/S14-review.md`。S08仍需普通启动、10分钟、三次重开及4倍实效验收。

## 完整单位

| 型号/配置 | 纯模型/接入资源 | 实例与当前能力 | 出场及观看入口 | 准入/限制 |
| --- | --- | --- | --- | --- |
| 大和 1944-04 | `scenes/ships/yamato_1944_04.tscn` | `jp_bb`；舰队机动、全部固定主副炮、配置防空、真实库存/弹道/伤害 | 默认15–23s；单位“大和”；火力段 | S02、S02-deck 已冻结通过。历史/游戏AA分别见 `data/units/jp_yamato_1944_04.json`，S14不改装备 |
| 衣阿华 BB-61 1944-12-28 | `scenes/ships/iowa_bb61_1944_12_28.tscn` | `us_bb`；同生产舰队/火控链 | 默认23–31s；“衣阿华”；火力段 | S02冻结；配置见 `data/units/us_iowa_bb61_1944_12_28.json` |
| 弗莱彻 DD-445 1942-07-18 | `scenes/ships/fletcher_dd445/fletcher_dd445.tscn` | `us_dd`；航行、固定炮位、防空、损伤 | 默认39–47s；“弗莱彻”；火力段 | S03冻结；鱼雷发射器可见，鱼雷作战未接 |
| 雪风 1942-06-04 | `scenes/ships/yukikaze/yukikaze.tscn` | `jp_dd`；航行、固定炮位、防空、损伤 | 默认31–39s；“雪风”；火力段 | S03冻结；鱼雷作战未接 |
| F6F-5 六挺 .50 子型，1944–45 | 原型 `aircraft/scenes/f6f5.tscn`；运行 `scenes/units/aircraft/f6f5_flight.tscn` | `us_air_1..4` 四机；`us_pair_demo_1..2` 双机。有限滚转/载荷/动力积分、编队、攻/援、集结、护航、S04 v3规避、真实枪弹、DM01 | 默认0–7s双机、63–88s四机；菜单双机/四机/规避/护航及五项F6F训练；每机可跟随 | 沿已验健康飞行/DM01；新增五项真实训练均实际完成。完整滚转峰值362.00°，半滚倒转真实改出；不改性能表 |
| A6M5a 五二型甲，1944-02子型 | 原型 `aircraft/scenes/a6m5_52ko.tscn`；运行 `scenes/units/aircraft/a6m5a_flight.tscn` | `jp_air_1..4`；自身性能/武装、两个双机、真实战斗/DM | 单位“零战1–4号”；五项A6M训练、四机交战与护航威胁 | 同一aircraft_training入口的五项直接训练均实际完成；完整滚转峰值363.78°，使用自身性能；DM01沿已验接口 |
| SB2C-4 1944–45 子型 | 原模型 `aircraft/sb2c4/sb2c4.tscn`；新独立适配 `scenes/units/aircraft/sb2c4_flight.tscn` | `us_sb2c_1..2`；独立近似性能、生产飞控、双机巡航/集结/撤离、作为F6F护航对象 | 默认7–15s；护航段；“SB2C-4 1/2 · 受护航” | 当前r2模型已通过独立准入，S14消费原模型与clean接口；无投弹、后射手、实用机炮/挂载、起降或DM预切组件 |
| 5-inch/51 Mk8 Mod0 + Mk13 Mod4，1945-01-15资料配置 | `scenes/ground/us_5in51_mk13mod4_1945.tscn` | `us_coast_01`；真实警戒/炮口/库存/伤害 | 默认47–55s；“港口Mk13岸炮”；港口场地 | S10冻结；首服役年未知。数据保留unknown，不以手册日期冒充服役年 |
| 40mm M1 + M2A1/M3，1944-01-17 | `scenes/ground/us_40mm_m1_m2a1_1944.tscn` | `us_aa_01..02`；独立实例、真实防空/自毁/库存/伤害 | 默认55–63s第一组；两组均可单选跟随 | S10冻结；首服役年未知，场地/机械射界沿原契约 |

默认首次露脸优先安排在交战升级前。导览不改存活/伤害：本段主体已经退出时注明退出并暂看其他可用对象，仍继续后续段落。菜单重新演示明确重置整场并增长 generation；连续导览不重置存活单位。单位选择器始终列出所有19个稳定ID。

## 兵器检视区（不计入19个战斗单位）

港口检视位于码头平台附近。承载高度使用同源 terrain+建筑/码头 top 查询；没有改冻结地图。五个条目均可从“港口兵器检视”直接选择，不需要飞到远处寻找。

| 条目 | 实际资源/装配 | 计数及能力边界 |
| --- | --- | --- |
| 日军7.7mm Vickers + 九二式F三脚架 | `scenes/weapons/navy_vickers_77mm.tscn` 装入 `scenes/mounts/japanese_92_model_f_tripod.tscn` 的 `WeaponSocket` | 完整现有检视装配；不接战斗，不擅加军舰 |
| 九六式25mm双联及舰用架 | `scenes/weapons/type96_twin_25mm.tscn` 装入 `scenes/mounts/type96_ship_twin_mount.tscn` 的 `WeaponSocket` | 单管 `scenes/weapons/type96_25mm_single.tscn` 是此双联的子模块，已实际出镜，不重复算新兵器；架型号尺寸估值沿原数据 |
| 美军M2HB枪体 | `assets/naval/weapons/us_browning_50cal/m2hb/us_browning_50cal_m2hb.tscn` | 原资产无完整已准入炮架，放明确的博物检视托架；托架不是虚构历史战斗支撑，不接战斗 |
| 美军M1917A1枪体 | `assets/naval/weapons/us_browning_30cal/m1917a1/us_browning_30cal_m1917a1.tscn` | 同上，检视支承与枪体接触；不冒称地面战斗单位 |
| Bofors 40mm Mk2 Mod5 四联 | `assets/naval/weapons/usn_bofors_40mm/mark2_mod5/usn_bofors_40mm_quad_mk2_mod5.tscn` | 有原装底座与训练/俯仰接口，整组检视。舰上已使用的同类模型不重复算完整单位 |

主炮/副炮/舰用AA/鱼雷发射器分别随四舰出场：大和460/155/127、衣阿华406/127、驱逐舰127及其机炮/鱼雷。各舰定义的 mount ID/数量/管数/安装位置是权威，不由S14另造或增挂。原“炮塔壳体”等父子资产只是装配部件，不另算整炮或整舰。

## 设施与未造项目

旧 `island_airfield/scenes/woleai_1944.tscn` 是独立机场设施示例，已有跑道/机库/地形/旧兵器陈列。当前主地图已有港镇与岸防，未搬入另一整岛，不把机场算作机型；机场/航母作业仍属后续任务。仅有资料、任务卡或目标图的 G4M、B-25、D4Y、TBM、B6N、Ki-21 等不属于本轮已搭建可运行单位。CV01已独立准入但未计入此19单位冻结；MAP02及后续航母/轰炸另案接入。

## 当前证据

最终九型单位及五项兵器均有正常入口截图：`evidence/S14/final/native/inventory/` 和实际 Chrome `evidence/S14/final/chrome/unit_*.png` / `weapon_*.png`。原生十项训练、四机及护航均保留起始至真实完成后的连续序列；完整视频及哈希见 `evidence/S14/final/videos.json`。Chrome十项实际启动及两型滚转/倒转完成记录见 `evidence/S14/final/chrome/run.json`。

四机与护航有真实循环完成判定，护航本种子无航空发射；不将威胁响应包装为命中。单机训练实际结果与当前订单匹配后才显示完成。完整行为、边界及验证见 [S14交付](deliveries/S14.md)。

阶段 `evidence/S14/native/`、`phase_freeze.json` 和旧失败机位保留历史；最终画面以 `final/native/` 为准。`final/native-camera52/` 为被更近34米训练机位替代的记录，不合并计作最终录像。
