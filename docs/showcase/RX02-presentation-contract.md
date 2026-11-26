# RX02 只读表现时钟交接

2026-11-12，RX02实施中。FirstPlayable与Session、镜头和地图归S14；效果、弹丸及损伤归S05，互不整文件覆盖。

已在 `FirstPlayableSession` 保留原 `units` 为真实固定tick快照、HUD/订单继续消费原值；另提供 `presentation_units` 与 `presentation_time_s`，由唯一只读尾部采样器保存相邻两个60Hz姿态，以world插值alpha生成，同帧供模型、相机、尾流和 `effects.apply_snapshot({"units":session.presentation_units,"time_s":session.presentation_time_s})` 使用。不会改UnitState、碰撞、指挥、油弹、RNG或战损阶段。

只插值实际相邻姿态（位置、四元数姿态、活动武器角和现有残片姿态）；重开/换场重置历史，未匹配的新部件直接用真实当前状态。离散伤情与库存仍读实际当前值。暂停锁定当前已显示时刻，不让暂停动作产生一tick跳位；显式测试step/reset时同步更新。

给S05的接口：实际弹丸可见性仍由其负责，可读取 `session.presentation_time_s` 和相同 `presentation_units` 对齐来源/烟火/挂点；实际事件坐标与结果不改。若需把事件或弹丸显示延迟到同一只读表现时刻，可在其表现模块按此时刻处理。普通页不依赖protocol2，测试探针只加少量当前帧锚点与时间，不重复历史。

追加的同帧离架接口（已实现，短测通过）：`session.presentation_bombs: Dictionary[id, Dictionary]`，行包含 `position_m / rotation_rad / velocity_mps / entity_id / slot / born_tick / terminated_tick`。由同一个末tick只读采样器读取现有CombatProjectiles的重力弹；只保留相邻端点，不另积分。出生END tick前不显示离架弹，`presentation_units[].module_data.bomb_rack.slots`同样保留上一已加载视觉，避免早一tick消失。到出生时刻，挂弹转为离架体并对齐真实出生点；消失前的一tick按实际终端事件位置插值。

RX01需将现有 `scripts/showcase/bombing/projectile_view.gd` 的只读输入从当前Round切到 `session.presentation_bombs`，模型模板/slot实体ID接口不变。RX02镜头也会读这一字典，保证所跟弹体和模型同一表现时刻。FX可用`session.presentation_time_s`延迟出生事件；实际事件与模拟Round不得改写。此文件不授权RX02覆盖RX01的效果/弹丸实现。

供统筹Chrome逐帧量测的可选小接口：在加载前提供 `window.S14X.protocol=2` 与 `window.S14X.observe_frame=function(row){...}`，每帧收到一个当前主体的 `model_m / focus_m / camera_m / screen_px / viewport_px / presentation_time_s / alpha / tick / generation / id`；位置均为数值数组，不是Vector3字符串。普通页未注入时没有这条序列化开销，也不会重复发送历史。原4Hz协议保留。

手动控制最终语义：自由观察右拖为原地环视，WASD/方向键在水平面平移，QE单独升降，Shift四倍加速；滚轮前后推进/缩放并按观察距离调整平移速度。跟随模式右拖仍可绕受跟随单位观察；键盘移动接管为自由视角。自动导演使用相同姿态帧但不置手动标志，继续导览时清除此标志。手动相机不再沿导演视线自动抬升或被整艘船的粗包围球突然推远，地面/海面最低眼高仍保持8米。

FirstPlayable桥已改：`presentation_events` 为仅到 `presentation_time_s` 的当帧事件；原事件仍由Session/UI/计数/协议照常消费。后坐、效果和只读事件相机仅消费这一延迟最多一tick的显示队列，`effects.advance`按表现时钟增量推进，使发弹p(t)与机身同刻。离散机体可见性、断翼掩码与新生碎片也保留至实际显示出生时刻；没有改真实部位损伤、碰撞或事件的time_s/position_m。

普通expanded入口已改为“港湾实战观战”：默认关闭港口路线导演，复用ObserverCamera按真实主炮/防空/空战/弹着事件观察。顶栏“实际交战”可恢复事件镜头，“港湾导览”显式开启地图路线；手动右拖/移动仍立即停止导演。新舰船字段按RX01 HANDOFF消费，HUD有浮力/动力/操舵/火控/炮位降效摘要；战报新增`sinking`计数，旧`sunk`只在船体完成实际下沉、进入wreck终态后累加，disabled漂浮不记沉没。

已观察到RX01/统筹完成既有`projectile_view.gd`的字典接线；RX02未覆盖该文件。短测现包括实际renderer在出生前无重复弹体、出生帧模型挂点与离架体同位，不只检验新字典。
