# S05 战斗契约 v1

2026-11-10。先发布供 S04/S06 接入；实现与验证进度见 `docs/showcase/deliveries/S05.md`。沿用 S01，不扩展公共状态类或命令语义。单位米、秒、弧度、-Z 向前。

## 安装与参数

```gdscript
var config: CombatConfig = CombatConfig.new()
var errors: PackedStringArray = config.load_file("res://data/combat/showcase.json")
assert(errors.is_empty(), str(errors))
errors = CombatSuite.install(world, config) # configure 后、首 tick 前
assert(errors.is_empty(), str(errors))
```

`CombatConfig` 独立读取 sensors、unit_profiles、weapon_profiles、ammo_profiles、environment、limits。炮口/射界来自 DefinitionCatalog。ammo_profiles 可显式修正 caliber_m、projectile_mass_kg、muzzle_speed_mps、max_lifetime_s；weapon_profiles 可指定 catalog 中存在的 ammo_id（Fletcher 采用 AAC Mk34 定时弹，原 Mk32 Common 保持直击）并覆盖 cycle、转速、初始库存。unit_profiles.mount_limits 可限制具体炮位最低仰角。所有覆盖有来源/近似记录，绝不覆盖炮位/炮管数/安装坐标。参数不是 source 注释。缺少单位或弹种配置拒绝安装，防止静默禁用武器。S03 正式定义已冻结，S05 只维护独立战斗覆盖；原生成器仍产生 provisional 基准，不会覆盖本文件。A6M5a 由 S04 发布定义后匹配其正式 ID。

固定优先级：`combat_frame` 80 保存 tick 开始位姿；`combat_contacts` 100；S06 指挥 200；S04/S06 行为 300、运动 400；`combat_targeting` 450；`combat_weapons` 500；`combat_projectiles` 600；`combat_damage` 650。模块全部纯数据，`reset()` 清理本局状态。伤害在本 tick 末输出，运动/行为从下一 tick 读取。

炮位转动/周期仍逐固定tick更新。装填中的炮位按 weapon_profiles.reload_track_interval_s（当前0.1秒）缓存飞行时间解，并逐tick用当前己方接触外推方向；准备发射时始终重解当前炮口/运动目标，不用旧解放行。缓存按目标ID和tick失效并在reset清空。弹丸内部为无节点的带类型记录，快照转为防御性纯数据；三维512m宽相只缩小候选集合，不省略仿真tick或弹丸。

## 接触与决策边界

`world.commander_snapshot(faction_id).contacts` 是 Array[Dictionary]。条目键：`entity_id`、`domain`（ship/aircraft）、`classification`、`position_m:Vector3`、`velocity_mps:Vector3`、`observed_tick:int`、`observed_time_s:float`、`sensor`（visual/radar）、`fresh:bool`、`valid:bool`、`uncertainty_m:float`。位置/速度仅在实际观测时更新。失联保持最后观测，3 秒后 fresh=false（不再允许火控），20 秒后移除；参数在 config.contacts 中。识别失效只随重新观测/过期发生，不通过查询敌人 active 泄漏全知情报。

`CombatContacts.find(world, faction_id, entity_id, fresh_only=true) -> Dictionary` 返回复制接触或空字典。指挥/任务/火控不得用 `get_unit(enemy_id)` 获取追踪点；S05 探测器、碰撞与损伤拥有全局几何权限，表现仍可全知。探测有限扫描频率，检查范围、地平线、静态遮挡和舰体/上层建筑代理。雷达/能见度是明确标注的场景近似。

## 行为输入：单一写入者

每单位的域任务执行器（S04 aircraft，S06 ship）拥有 `unit.module_data.combat_intent`：

```gdscript
unit.module_data["combat_intent"] = {
    "fire": true,             # 主/副炮或飞机固定武器许可，默认 false
    "allow_aa": true,         # 舰艇防空职责许可，默认 false
    "burst_until_tick": world.tick + 12 # 飞机必须给出短点射窗口；舰炮忽略
}
```

目标沿用 `UnitState.target_id`，通过统一 `BattleCommand.SET_TARGET` 提交；`CEASE_FIRE` 仍为总闸。S05 不改 target_id，不另行创建高层指令。行为可每 tick 更新意图；fire/allow_aa 持续至覆盖，点射到期自动停止。执行器在取消/改派/退出攻击时必须清除意图与目标；reset 删除旧意图、恢复场景初态。飞机固定武器只沿机体/实际炮口方向发射，S05 不转飞机、不代替飞行员瞄准。

S05 自有 `unit.module_data.combat_runtime`：`mount_targets`、`mount_reasons`、`mount_status`、`last_salvo_tick`、`shots_fired`。舰艇主炮只用行为 target_id；可兼任防空的副炮/专用AA按己方 fresh 接触评分、分担和换目标冷却分配。状态给出 no_contact、out_of_range、traversing、arc、masked、reloading、empty、disabled、hold_fire 等真实原因。S04/S06 只读此字段，不改炮位角度、库存或弹丸。

## 损伤输出：S05 独占写入

`unit.module_data.damage`：`structure`/`structure_max`、`parts`（engine/steering/control/weapon:<mount_id>）、`propulsion_factor`、`control_factor`（0..1）、`disabled_mounts:Array[String]`、`fire`、`flooding`（0..1）、`phase`（operational/disabled/sinking/crashing/wreck/removed）、`phase_time_s`、`list_rad`。`structure` 是游戏损伤单位，不是史实装甲等效。护甲和弹径/能量决定部位效能；轻武器不能通过累积打穿战列舰装甲带，但可损伤暴露装备。持续伤情必须由真实命中引起。

S04/S06 将动力、操纵因子用于各自运动。军舰 control 归零进入 disabled、active=false 并停止射击，任务生命周期沿用 S01 释放；保留剩余结构、动力因子与原水位，不计时自动沉没。disabled 仍可被后续弹丸和真实火灾/进水损伤，只有结构归零或进水达到 1 才进入 sinking。飞机 control 归零进入 crashing。sinking/crashing 同样 active=false；S05 更新残骸进度/位移，wreck 保留有限时间后 removed。模型 active=false 的默认隐藏由表现层按 damage.phase 显式适配残骸，不能据模型节点判断作战能力。

### 实际离场与物理存在（S04/S05/S06）

S04 撤离写 `module_data.aircraft_motion.exited=true` 并输出 `aircraft_exit`；S06 写 `module_data.ship_motion.exited=true` 并输出 `ship_exit`。两者同时设置 `active=false`，表示实际退出战场，不是击毁或沉没。`CombatPresence.is_present(module_data)` 统一判定：任一 exited 为 true 或 damage.phase=removed 时不再物理存在；仅 active=false 不足以移除，disabled/sinking/crashing/wreck 仍保留实体阻挡。

弹丸碰撞网格、探测视线和空爆遮挡排除离场实体；实际空爆受伤目标也排除离场单位。650 损伤结算读取当前离场状态，拒绝尚未结算的旧 hit/unit_surface_contact，停止持续火灾、进水和损伤生命周期推进，不回滚离场前已经完成的伤害。离场单位不能再发射新弹；离场前已发出的弹丸继续原来的弹道、寿命和机械定时引信，不因发射者或指定目标离场被删掉。当前没有近炸/VT机制。

存在性是权威物理/表现接口，不是敌情查询接口。探测器停止刷新离场目标，但既有己方接触仍按原 observed_tick/observed_time_s 自然变旧、过期，指挥和火控不能据敌方 exited 提前删除接触。`world.reset()` 恢复场景初态和离场标记。

## 弹道、环境和事件

### 飞机运动到损伤的表面接触边界（S04/S05）

运动模块在 priority=400 检出真实触海/地时发一次 `world.emit_event("unit_surface_contact", unit.id, "", actual_contact_position_m, {"velocity_mps": actual_velocity_mps, "surface": "sea", "reason": "forced_ditch"})`；surface 只允许 sea/ground/building。S04 同 tick 清除 combat_intent，停止继续积分，不自行写 damage、宣布摧毁或生成水花。不要把主动出界/撤离当表面接触。

S05 的650模块接收并去重，统一设置 active=false、停止武器、损伤能力归零、phase=wreck。接触速度>=35m/s或垂直下沉速度>6m/s视作本场严重碰撞（structure=0）；较软接触保留结构但同样退出空战，并保留 destroyed=false。此阈值是游戏近似，不是水上迫降求生模型。输出 `disabled`（此前尚未失能时）、`damage_phase` 和一次 `unit_impact`，data 含 surface/velocity_mps/reason/destroyed/size_m。表现只从规范 `unit_impact` 生水花/尘土/命中声，避免两次显示。已在 wreck/removed 的重复接触不再结算。

S05 自有 crashing 自由落体也沿实际经过路径检查地表/海平面，再发相同 `unit_surface_contact` 并经过同一收尾；不会到某个秒数就在空中变残骸。wreck 经 limits.wreck_lifetime_s 回收。主动撤离仍是 S04 的任务退出事件，不冒充击毁。

友方可拦截弹丸，默认不造成友伤；config.environment.friendly_fire 可显式开启。仅发射者在弹丸离开自身代理前排除自碰，离开后可再次命中自己。静态代理位于 environment.solids（id、surface=ground/building、center_m、half_extents_m），ground 同时覆盖其海面投影，避免陆地脚下先判水花。海平面 `sea_level_m`。单位代理按模型大形的 hull/bridge/engine/steering/翼面/炮位盒组成，不存 Node。

所有弹丸逐 tick 扫掠，以相对运动求最早交会，先撞到谁就结束该弹；定时引信、表面、单位、寿命一次终结。显示不参与碰撞。弹丸容量不足时不扣弹、不推进装填，mount_status=capacity；下一 tick 重新尝试，不以效果池预算取消真实发射。容量、在飞数和拒绝次数可检查。

`BattleEvent` 沿用 S01 字段；位置均为真实模拟位置，data 至少带 `projectile_id`（适用时）、`ammo_id`、`caliber_m`。事件：

| kind | data 中的关键附加字段 |
| --- | --- |
| fired | barrel_index、muzzle_direction、velocity_mps、flight_time_s、tracer；weapon_id 为真实实例炮位 |
| salvo | mount_ids、rounds；只汇总本 tick 实际发射的主炮 |
| hit | part_id、surface、energy_j、friendly、damage_allowed；target_id 为首先相交单位 |
| airburst | radius_m、velocity_mps；仅重高炮的定时引信 |
| surface_impact | surface=sea/ground/building、normal、energy_j |
| unit_impact | 真实飞机表面接触归一化结果：surface、velocity_mps、reason、destroyed、size_m；不是弹丸事件 |
| projectile_expired | reason=lifetime；无伤害 |
| damaged | part_id、amount、structure、propulsion_factor、control_factor |
| disabled | reason、phase；真实战斗失效 |
| damage_phase | phase；沉没/坠落/残骸回收变化 |

`CombatEffects`（Node3D）接收 `consume(events:Array[BattleEvent], generation:int)`、`apply_snapshot(snapshot:Dictionary)` 与 `advance(delta_s)`；外部从 world.drain_events() 喂入，暂停时 advance(0)。按 generation+sequence 去重，有界网格/声源池，禁用仍更新事件游标。效果无权写世界或使用 world.rng。弹迹采用 fired 初态的表现外推，并由终结事件结束；空爆、水柱、尘土、火花、烟火从对应真实事件生成。声音为程序合成原创。

`apply_snapshot` 只需要 units 映射。显示热路径可按 `world.unit_ids()` 取各 `UnitState.snapshot()`，组装独立的 units/tick/time_s/generation 读模型；不要为了特效每帧复制 `world.snapshot()` 中的数千条弹丸快照。完整 snapshot 留给回归/审计；表现弹迹已由 fired/终结事件驱动。只读取复制状态，不把可变 UnitState 引用交给模型。

持续烟火读取正式快照的 definition_id、position_m、rotation_rad 和 module_data.damage.fire。六型的 `unit_profiles.<id>.damage_effects.{fire_anchor_m,smoke_anchor_m}` 是型号局部米制锚点：舰艇选外露甲板，飞机选机鼻发动机外壳附近，由单位姿态变换到世界坐标。效果准备时读取一次独立战斗配置，锚点不改变火情强度或任何模拟参数。大和与 Fletcher 的实际模型网格检查见 S05 交付证据。

离场快照立即停止新的持续烟火及发动机声源；消费 aircraft_exit/ship_exit 后的表现本地标记也阻止延迟的离场前快照重新启动烟火。此前已生成的短时烟云/弹迹可以按原寿命消散。generation 变化经 clear() 清空离场标记、快照和池，重开不会继承旧局离场状态。

## 接入验收边界

本契约不宣称 Showcase、飞机行为或浏览器通过。S05 提供局部机制测试和无 UI 效果场景；S07 集成六型、伤情表现和观战 UI，S08 按用户最新要求仅测 Chrome。基础参数来源、近似和实际命令在 S05 交付中逐项记录。

## DM01 航空毁伤接入（2026-11-11）

F6F/A6M 航空代理的翼部 `structure` 改为 `wing_left` / `wing_right`，旧尾部 `control` 改为独立结构部位 `tail`。既有近炸仍损伤功能 `control`，耗尽只导致失控，不能凭空断尾。真实部位毁伤与总结构耗尽才发布相应脱离事件。航空 crashing 使用连续有界角速度/剩余升力/阻力/重力；真实 surface_contact→unit_impact 接口及 ship/ground 分支保持，航空海面残骸下沉并在12秒回收。模型、碎片、body angular velocity 和烟源的权威字段见 [DM01 航空毁伤契约](aircraft-damage-contracts.md)，交付见 [DM01](showcase/deliveries/DM01.md)。
