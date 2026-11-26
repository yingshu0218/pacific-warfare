# BOMB01 接入契约（r18私有验证完成，待统筹准入）

更新2026-11-11。r18机制、真实单位场景及原生证据已完成，仍待统筹独立复核与S14普通集成。正式候选见`candidates/bomb01/final-manifest.json`，冻结输入及可消费数据见`docs/showcase/evidence/BOMB01/final/`。普通入口、Session、注册目录与`tools/showcase_runtime.json`仍只由S14编辑；BOMB没有覆盖公共文件。初始基线与后加依赖分别保存在`candidates/bomb01/baseline-manifest.json`、`ops-inputs.json`和`extra-inputs.json`。不得把新公共源码静默换进旧stage；历史stage保留各自input-manifest和失败身份，最终r18共511份明确输入。共同遵守[S14组合边界](showcase/S14-BOMB-integration-inputs.md)。

## 命令与角色

`BattleOrder.order_type="bombing"`，`bombing={mode:"dive"|"level"}`。目标为`target_id`时，执行器只接收本阵营新鲜合法的ship/ground接触；校验与未来真人同入口。固定区域为`area`加`bombing.area_id`，必须与`world.shared_state.bombing_known_areas[faction][area_id]`的合法已知区域完全相符。攻击飞行和预测不读取敌方UnitState；碰撞、伤害系统仍按原架构全世界求真实结果。

SB2C/D4Y只接dive，G4M/B25只接level。机型性能的`role`使唯一AircraftTasks拒绝轰炸机的intercept/engage/escort/aircraft_training；导航patrol、regroup、retreat保留。自卫枪位未接火控，不会用狗斗或装饰弹流补充。

`BombingCommander`只表达上级场景目标和兵力：轰炸目标单次有限出动；拦截每1秒检查自己的接触/命令状态，指定目标同样须有己方接触。旧目标丢失或旧单终止后可观察其余来袭接触重新下令。没有投弹、命中、损失、单位姿态/位置或健康的时间表。观战消费真实BattleOrder历史、execution、`unit.task.aircraft`与`module_data.bombing`的phase/reason/abort_reason，不拼接预写执行台词。

## 同一执行器的安装

装配时持有既有`CombatFrame`、`CombatProjectiles`、`AircraftTasks`及`AircraftMotion`实例，不安装第二个aircraft域执行器或第二套碰撞/伤害世界。

1. 在catalog/world配置前，将已准入的机型定义和本候选显式弹药数据合入`DefinitionCatalog`，经过原校验。参数不自动扫描注册。AN-M64统一身份`us_an_m64_tnt_tm1950`，完整弹232.148575kg、TNT118.705123kg；不再使用240kg占位。
2. 将私有机型战斗代理/DM参数及ammo_profiles合入原CombatConfig；性能只提取四个轰炸机ID合入任务和运动各自的AircraftPerformance实例。不要把本任务保存的旧F6F/A6M性能覆盖S14自己的当前值。
3. 原CombatFrame先建立代理，原CombatProjectiles/CombatDamage仍只各一个。`BombStores.new(projectiles,parameters)`是新增武器模块，priority520，注册前tick必须0。它是库存和实际释放的唯一写入者；模拟顺序为任务300→运动400→投放520→弹丸600→损伤650。
4. 独立在空组合：设置`tasks.bombing_delegate=BombingMissionDelegate.new(parameters,stores)`，再注册唯一任务执行器。
5. 与冻结OPS r11组合：使用`ops_task_bridge.gd`（继承原OPS任务桥），设置`operations`和真正的`CarrierMissionDelegate`子类`mission_delegate`，**父级bombing_delegate保持null**；该桥拒绝双配置。reset/accept/step/released只有OPS路径一次。原OPS飞行桥继承力积分，BOMB不再注册自己的运动模块。S14旧SB2C导航专用子类若仍在入口挡bombing，应在唯一顶层分发处先选择已验收委托，不可旁开第二执行器。
6. `carrier_ops.on_deck`是权威甲板字段。高度高也拒绝甲板释放；不能用另造`air_operations`字段。D4Y摆架只在安全空中状态推进；甲板不预演完整摆架。G4M为地面拆盖战斗构型，没有开合舱门。
7. 只有carrier_eligible且实际存在本机carrier_ops/委托状态时，返航写`carrier_delegated_mission.return_requested/return_reason`；OPS接管回收，BOMB不先完成/释放该命令。G4M/B25不会申请航母回收。独立在空测试的`airborne_return_area_reached`只表示到达撤离空域，不表示已经落地。

## 飞行、载荷与首次接触

所有单位位置、速度、姿态仍由原力积分/DM写入。攻击有inbound、roll_in、dive或stabilize、salvo、pullout、egress、regroup、return；目标丢失、过低、超速、空弹、低油、操纵/推进受损或结构/火灾严重时中止，保留实际后续飞行。错误窗口不会自动补发命中。

挂点使用各机已发布模型坐标；D4Y按真实摆架轴变换。B25槽0/1下、2/3中、4/5上，按0…5消耗，保持同侧下层先清。库存逐槽状态、mass_kg、bay/crutch/brake及目标值为纯模拟数据，模型不扣弹。单tick请求、实际运动后再次校验、有限间隔与容量拒绝均不能补弹。

炸弹显式gravity_release、零炮口速度、母机实际线速度、独立重力/阻力、出生tick不推进；没有制导。原CombatFrame扫掠、Geometry及TerrainQueries决定首次海/陆/实体接触。保险必须同时满足时间/累计距离，未解除就是哑弹；触发延时只保存一次接触，不穿透后再次找目标。

SB2C/B25粗代理在全开舱门时只拆分中央机身盒为上盖/侧框/前后实体，形成真实挂点下方通路；其他机翼/发动机/尾部仍有碰撞。最后一枚炸弹实际越过机腹净空前保持舱门开放。母机初始脱离覆盖实际显示弹体、尾翼与挂耳的完整保守轴向包络，不只看中心/口径；空间筛选前先检查清离，避免高速出网格后留下永久豁免。完全清离后再相交仍会撞母机。出生保留挂架/摆架实际姿态；姿态按固定tick有限速率对齐气流，不改变速度或引导弹道。

爆炸只由真实armed接触产生，按最近实体代理一次曝光，距离平方衰减，并受同源地形/建筑/其他实体遮挡；friendly_fire沿原设置。装饰建筑只接触/遮挡，没有虚构健康/摧毁统计。炸弹显示半径、伤害半径、结构换算均为显式游戏近似，不声称历史穿甲/爆轰仿真。

## 模型、FX与损伤表现

`BombingAircraftView`只消费UnitState：实际姿态、桨相位、控制面、库存、舱门/减速板/摆架。D4Y/G4M/B25用已交付damage_modules，wing_left/right/tail对应left_wing/right_wing/tail；克隆片段使用原DM01最多3个实际fragment快照与本机真实cut marker锚点，翼带走所属发动机。烟/火/海面接触仍由原CombatEffects/DM事件与effect_emitters驱动，`BombingEffects`仅增加有上限的真实炸弹爆炸视觉。

保留限制：新双发机目前是推进系统合计损伤与共同模拟桨相位，未声称左右发动机独立气动/失效扭矩；受损后桨速仍来自原运动/DM滑转状态，不用墙钟播放正常桨动画。SB2C既有模型未发布左右预切损伤组，本批不假称已完成SB2C单侧断翼/片段；原整机受损/失控与后续模型分组接口需S14/模型所有者明确能力。防御枪精确射界/自遮挡/库存仍未完成。不得把这些限制在菜单标成完成。

## 验证及正式合入

受控初态机制测试、自然任务完成、实际模型原生短片分别记录。全部重型验证走同一verify锁；Chrome只在S14组合后验，BOMB本轮不打开浏览器。原炮弹同输入的事件、单位、RNG、发射/回收计数JSON逐字节相同。r18覆盖29项弹道/保险/损伤、34项任务/OPS生命周期、13项窗口前取消/低油/改派/延迟发现/目标丢失、20个真实挂点/弹体包络检查、四型自然攻击、六组真实单位场景及原有炮弹/火控/武器循环/几何/命令/飞行回归。六段原生影片为实际60Hz、每帧4tick、15fps，共2760帧，镜头只读、不插帧。报告与历史失败均保留，见[交付](showcase/deliveries/BOMB01.md)。

## S14显式合入清单与冲突处理

`final/integration/parameters.json`提供三种弹药、ammo_profiles及四型挂载/任务参数；`combat_profiles.json`提供四型unit_profiles；`performance.json`只含四型，不含旧F6F/A6M；`units.json`只含三个新ID，SB2C沿既有准入定义；`scenarios.json`含六个最小合法初态与上级目标。模拟ID沿用`us_b25j_1944_07`，不是模型proposal未注册的`us_b25j_1_1944_07`。数据先按ID合并再走原校验，不能直接追加成重复单位。私有fixture的目录扫描不是生产注册方案。

八个共享候选和八份新增脚本由manifest逐份列出。`final/patches`基于最初公共基线，供重基使用，不是对最新S14整文件覆盖许可。`ops_frozen`只是验证依赖，不可覆盖S14已修正的OPS。必须保留World的patrol `area.on_station_duration_s`校验、OPS移除隐藏110秒期限、显式期限和返航hook。BOMB240秒只限制攻击阶段，不重置拉起/脱离/重组/返航。

保留FleetPlanner的F6F/A6M `role:fighter`及甲板过滤，并仅由一个分配者管理同一截击编组。推荐生产FleetPlanner继续管战斗机，BombingCommander只装bombing目标；私有intercept目标是隔离测试示例，不能再与FleetPlanner争抢同一飞机。不能因无防御枪/枪弹0或最后一枚炸弹离架，就用通用retreat覆盖拉起/脱离。轰炸阶段、低油/受损中止及OPS交接由唯一delegate决定。

表现可参考`BombingAircraftView`与各模型的纯快照API；S14仍拥有实际Adapter/observer_text。视图不写模拟。库存`remaining/released/slots`、`bay/crutch/brake`、桨/操纵面、`bombing.phase/reason/abort_reason`与`damage.phase/aircraft.fragments`分别消费；DM释放命令后不能只显示“released”而掩盖实际crashing/wreck。炸弹使用真实`position_m/forward_m/up_m`快照，不从相机生成或瞬移。

六组测试中的停泊舰/不开火岸炮及有利追尾初态是机制夹具，不是强制战果；生产舰艇运动、防空、双方AI和菜单仍由S14接入。成功拦截不代表任何初态必能开火；早期正面对头/过高速追击未开火证据同样保留。

复建：根目录运行`python3 tests/bombing/prepare_stage.py 新名字`，经`tools/verify.py`先import再test。原始S04运动测试写入`docs/showcase/deliveries`，需预建该stage同名目录。所有Godot/录制/编码共用verify锁；native命令和输出manifest见交付。S14组合后另做Chrome、普通入口/重开、双方观战指令UI和性能验收。
