# 统一运行契约 v1（S01）

发布：2026-11-10；实现入口 `scripts/simulation/simulation_world.gd`。本接口供 S02–S07 接入，S01 已经统筹独立验收，见 `docs/showcase/acceptance/S01-review.md`。S01 的职责是数据、时钟、命令分派和任务生命周期；飞行、探测、火控、发射、弹道、损伤与舰队 AI 由后续模块实现，不能把核心接口验收视为这些机制已完成。

## 坐标、定义和 ID

- 米、秒、千克、弧度；定义 JSON 中明确标为 `*_deg` 的字段在加载时转换。右手系，+X 右／右舷、+Y 上、-Z 前／舰艏。`rotation_rad` 使用 Godot `Basis.from_euler` 的 YXZ 约定；正 yaw 将前向转往 -X，正 elevation 绕 +X 抬炮口。
- `UnitDefinition` 是型号／具体配置；`UnitState` 是每个实例的可变状态，只存 `definition_id`。`DefinitionCatalog` 内部保留独立字典，每次 getter 返回新类型对象；调用者不能改到其他实例或复位基准。
- 定义 ID、实体 ID、阵营／编组 ID、模块 ID、命令 ID、指令 ID 是稳定字符串，允许字母、数字、`_.:-`；不得用节点实例 ID。炮位 ID 在单位定义内唯一；运行武器 ID 为 `<entity_id>/<mount_id>`。事件 ID 在一局内按顺序递增；`world.generation` 每次 reset 增加，UI 用它清空旧引用／事件游标。
- 国家 `country_id` 属定义；阵营 `faction_id` 属场景实例，二者分开。定义保留 `service_entry_year`、`configuration_date`。这允许跨年代场景而不抹去服役年份。
- `UnitState.module_data`、`world.shared_state` 和模块 `snapshot_state()` 只放纯数据，不放 Node、Resource、Callable 或场景引用。模块可把全局弹丸等放在自己的数据容器并纳入快照。表现消费复制的 `snapshot()`，不能修改世界。

| 类型 | 首批字段与职责 |
| --- | --- |
| `UnitDefinition` | 型号 ID、国家、域（ship/aircraft）、服役年、配置日期、尺寸、模型入口、炮位、固定武装／历史 AA／游戏 AA |
| `UnitState` | 实体／定义／阵营 ID，位置、速度、Euler 姿态、active、target、cease_fire、active_order_id、task、module_data、各炮位 WeaponState |
| `WeaponDefinition` | 弹种引用、每座炮管数、每管初始库存、cycle_s、转向／俯仰限制与角速度 |
| `WeaponState` | 实例武器 ID、定义／炮位 ID、train/elevation、逐管库存、cycle_remaining_s、enabled；S01 不自动发射／装填 |
| `MountSocket` | 宿主语义 ID、安装位置、基础 yaw、俯仰轴偏移、逐管炮口相对位置；朝向统一 -Z |
| `AmmoDefinition` | 弹径、质量、初速、重力、最大存活时间及来源；弹型／引信／毁伤待 S05 扩展 |
| `ScenarioDefinition` | 场景 ID、seed、tick_hz、阵营、spawns、groups；只定义初态，无场景节点依赖 |
| `BattleCommand` | 请求信封：command_id、issuer_id、source、faction_id、entity_id、kind、execute_tick、payload |
| `BattleOrder` | 高层战术意图及实际生命周期，见下文 |
| `BattleEvent` | sequence、event_id、kind、tick、time_s、entity_id、weapon_id、target_id、position_m、data |

S01 最初从大和与 F6F-5，以及 46 cm、15.5 cm、.50 口径弹药提取首批 provisional JSON。后续 S02/S03 会按各自模型验收更新炮位、炮口、主副炮和历史／游戏 AA 清单；当前状态以正式 JSON、对应板块交付和统筹验收为准，不沿用最初空 AA 清单的假设。尚无证据的弹道／周期／库存值仍为估值，由 S05 校准；旧模型上可见的武器不因此自动具备真实射击机制。

`historical_fixed_armament` 与实际 main/secondary/aircraft_fixed 炮位数量、每座管数严格核对；兼任防空的主副炮也必须放入固定编制。`dedicated_aa_game` 与实际 dedicated_aa 炮位核对，独立保留 `dedicated_aa_historical`。修改造型或位置之前仍须通过舰艇资料与几何验收；数据校验不能证明史实。

## 载入和固定时钟

```gdscript
var catalog: DefinitionCatalog = DefinitionCatalog.new()
var errors: PackedStringArray = catalog.load_files(
	["res://data/units/jp_yamato_1944_04.json", "res://data/units/us_f6f5_1944.json"],
	["res://data/ammunition/jp_460mm_ap.json", "res://data/ammunition/jp_155mm_shell.json", "res://data/ammunition/us_127mm_m2_ball.json"],
	["res://data/units/weapons/us_an_m2_127mm_single.json"])
assert(errors.is_empty(), str(errors))
var world: SimulationWorld = SimulationWorld.new()
errors = world.configure(catalog, {
	"id": "example", "seed": 123, "tick_hz": 60, "factions": ["jp", "us"],
	"spawns": [{"id": "yamato_01", "unit_definition_id": "jp_yamato_1944_04", "faction_id": "jp", "position_m": [0, 0, 0]}],
	"groups": [{"id": "jp_fleet", "faction_id": "jp", "member_ids": ["yamato_01"]}]
})
assert(errors.is_empty(), str(errors))
world.advance(1.0 / 60.0)  # real elapsed seconds; display calls this once per frame
world.set_paused(true)
world.set_time_scale(0.5)  # 0…16; invalid values rejected
world.reset()              # restores original scenario/seed and clears all runtime queues
```

`advance(external_delta_s, max_ticks=240)` 只按固定 `1/tick_hz` 更新，累计小数余量且不丢 tick。暂停和 0× 都不积累暂停期间的墙钟时间。`step_ticks(n)` 是测试／工具显式单步，允许暂停时推进；正式 UI 用 `advance`。`reset(seed)` 可选择新的非负种子；空参恢复场景种子。模块顺序、种子和按 tick 提交的命令一致时，同 Godot 版本结果一致；不承诺不同平台浮点逐位相同。

`advance(delta, budget)` 每次最多执行 budget 个 tick，默认 240；显示入口可选 8 等更小预算。未执行时间保留为积欠，用 `pending_ticks()`／`pending_time_s()` 检查，再 `advance(0, budget)` 逐次排空；不能再次传入同一墙钟时间。budget=0 只累计，-1 显式不设上限（离线工具）；小于 -1 拒绝。`interpolation_alpha()` 在有积欠时封顶 1，仅用于显示插值。显示 FPS、相机和效果池不得改变模拟；倍速超过设备算力时应显示真实落后情况，不丢 tick 追上墙钟。

数据校验返回 `PackedStringArray`，不会用日志伪装成功。失败载入不会替换原有效 catalog。检查重复 ID、引用、有限数值／合法范围／整数、炮口缺失／数量、固定编制和场景／编组阵营；历史来源状态另留在 `source.status`。

共用武器采用 `catalog.load_files(unit_paths, ammo_paths, shared_weapon_paths)` 的可选第三参数；每个共用武器文件是一个 `WeaponDefinition` JSON。首批 AN/M2 定义位于 `data/units/weapons/us_an_m2_127mm_single.json`，F6F 的 `weapon_definitions` 为空数组，其炮位和编制用 `weapon_definition_id` 引用这份规范定义。纯数据入口 `load_data(unit_records, ammo_records, shared_weapon_records)` 相同。大和的既有内嵌定义兼容保留；同 ID、内容完全相同的武器去重，内容冲突拒绝，未知引用拒绝。其他类型／实例 ID 仍拒绝重复。测试覆盖两个不同单位类型共享一门规范武器，库存和角度互不影响。

## 模块扩展与时序

继承 `SimulationModule`，在首个 tick 前 `world.register_module(module)`；按 `priority` 升序，同优先级按 `module_id` 排序。建议 S05 探测 100、S06 指挥决策 200、S04/S06 任务执行 300、运动 400、S05 火控／武器 500、弹道／碰撞／损伤 600。具体模块可拆分，确定后固定顺序。

每个 tick：递增 tick → 滚动事件邮箱 → 清理失效受令成员 → 应用已到期命令（同 tick 按提交顺序）→ 模块 `fixed_update(world, fixed_delta_s)`。模块在 tick 内新提交的命令最早下一 tick 执行，不递归即时分派。

公开接口：

```gdscript
extends SimulationModule

func _init() -> void:
	module_id = "air_tasks"
	priority = 300

func supported_order_types() -> PackedStringArray:
	return ["patrol", "escort", "intercept", "engage", "regroup", "retreat"]

func order_domains() -> PackedStringArray:
	return ["aircraft"]

func accept_order(world_ref: RefCounted, order: BattleOrder, unit_ids: Array[String]) -> Dictionary:
	# Capability validation ONLY: unit_ids is this domain's deterministic slice.
	# Do not start tasks, move units, or cache ownership until accepted and assigned.
	return {"accepted": true, "reason": "capable"}

func fixed_update(world_ref: RefCounted, delta_s: float) -> void:
	var world: SimulationWorld = world_ref as SimulationWorld
	for record: Dictionary in world.orders_snapshot():
		for id: String in world.owned_order_unit_ids(record.order_id, "aircraft"):
			if record.execution[id].status == "received":
				world.report_order_unit_status(record.order_id, id, "executing", "route_ready")
			# Execute actual task/flight rules here, then report actual progress/results.
			# No task completion is implemented by this illustrative fragment.

func on_order_units_released(world_ref: RefCounted, order: BattleOrder, unit_ids: Array[String], reason: String) -> void:
	# Remove ONLY these cached tasks. Other members may still execute this order.
	pass

func reset(world_ref: RefCounted) -> void:
	# Clear module caches, projectiles, schedules and counters.
	pass
```

`unit_ids()` 返回排序 ID，`get_unit(id)` 供模拟执行器修改实例状态。`unit_definition`／`weapon_definition`／`ammo_definition` 返回复制定义。`rng` 是按场景种子初始化的唯一世界随机源；不使用随机全局函数、真实时间或渲染帧数。模块的私有持久状态必须在 `reset()` 清空，在 `snapshot_state()` 返回纯数据以供回归比较。

## 高层战术命令与归属

S06 的指挥官只做意图决策；S04 实现 aircraft 任务执行器，S06 实现 ship 执行器；二者通过 `(order_type, domain)` 路由同时接受巡逻等同名命令，不各建一套命令入口。每个键最多一个执行器；同一命令中的舰、机分片分别校验，任一片拒绝则整条指令失败且不接管旧任务。混合命令保留一个 order_id，逐单位执行状态独立汇总。

`BattleOrder` 请求字段：`order_id`、`issuer_id`、`source`（ai/human）、`faction_id`、`recipient_ids`（单位／编组）、`order_type`、可选 `target_id`、`area={center_m:[x,y,z],radius_m:n}`、`waypoints_m`、`intent`。首批类型 patrol/escort/intercept/engage/regroup/retreat。巡逻必须有区域或航点；escort 必须指向友方，engage/intercept 指向敌方，intercept 还须为飞机。未注册或未来起降／攻击命令明确拒绝。具体能力和油弹条件由执行器校验。

```gdscript
var order: BattleOrder = BattleOrder.new()
order.order_id = "jp_patrol_001"
order.issuer_id = "jp_commander"
order.source = "ai"  # future human changes only the source/input producer
order.faction_id = "jp"
order.recipient_ids = ["jp_fleet"]
order.order_type = "patrol"
order.area = {"center_m": [0, 0, -5000], "radius_m": 2000.0}
var receipt: Dictionary = world.submit_order(order)
# accepted=true, reason=queued means structurally queued, not execution success.
```

该 helper 转为 `BattleCommand.ISSUE_ORDER` 后调用统一 `submit_command`；AI/human 使用同样身份、阵营、数据、受令者与 tick 校验。`command_id` 是 `issue:<order_id>`。完全相同重复投递返回原 receipt 并标记 duplicate，不重复执行；相同 ID 改内容拒绝。命令接受后深复制；后续修改原对象无效。`execute_tick=-1` 表示下一 tick；过去／当前 tick 拒绝。执行前再次校验对象及目标，失效时发出 command_rejected。

指令状态：issued → received → executing → completed/failed/cancelled/superseded；received 可直接进入终态，issued 可因执行器拒绝而 failed。`issued_tick`、`received_tick`、`changed_tick`、reason、progress、history 保留真实仿真时间。只有 tick 内执行模块可以回报进度／状态；UI 不能通过读视图篡改。类型不具备执行器时不创建“执行中”记录；明确拒绝理由通过 receipt 和下一 tick 的 command_rejected 事件呈现。

- `assigned_unit_ids` 是当前仍归该任务控制的单位；`execution[entity_id]` 保存 module_id、状态、原因、进度、changed_tick 与 replacement_order_id。
- `owned_order_unit_ids(order_id, domain)` 是每 tick 执行任务时的归属依据；不得一直沿用原 recipient_ids，否则部分改派后会出现双重控制。
- `report_order_unit_status(order_id, entity_id, status, reason, progress)` 回报单成员结果。第一个 executing 推动任务 executing；最后一个成员退出才汇总终态。混合结果优先 failed、cancelled、superseded、completed，逐成员结果仍完整保留。
- `report_order_unit_progress(order_id, entity_id, progress, reason)` 更新当前归属成员的真实进度，域执行器用它避免互相覆盖摘要。`report_order_progress` 可由 S06 提供整条任务汇总；二者都在 tick 内执行。
- 新命令仅接管重叠成员，旧任务剩余成员继续执行。`order_assignments_changed` 及 history 的 units_released 记录部分改派；只有无剩余成员才整体结束／替代。
- `transition_order` 是可信分派器对整条任务操作的接口（如整体取消／失败），域执行器正常完成应使用逐成员回报。取消通过 `BattleCommand.CANCEL_ORDER`，payload 包含 order_id、reason；同样检查阵营、队列和终态。
- 释放先清除仍由旧任务拥有的状态，调用所属执行器 `on_order_units_released`；整体终结再调 `on_order_ended`。取消旧命令不会清除已转给新命令的成员。成员 active=false 后下一 tick 自动释放；最后成员损失使任务 failed。目标失联／毁伤后的搜索、接替和失败判断交给 S04/S06，不用时钟假定完成。

内部执行用 `SET_TARGET`（payload target_id，可空以清除）和 `CEASE_FIRE`（payload enabled:bool）也经过同一个信封和阵营检查。射击／转炮是执行器内部行为，后续 S05 接口不能把每发炮都刷成一条指挥官命令。高层命令从不直接更改位置、库存或伤害。

## 情报与观众视图

`commander_snapshot(faction_id)` 只返回己方单位、编组、己方指令和 S05 `set_contacts(faction_id, contacts)` 提交的接触资料。未提交探测结果时 contacts 为空，不自动从敌方实时位置填充。联系人数据应包含最后位置、观测 tick、分类等；S05 负责真实性和过期规则，不能传入模型节点。

S06 指挥决策只消费上述视图；不要给程序指挥官注入 observer snapshot。`snapshot()`／`orders_snapshot()`／表现事件 outbox 是观众全知读模型，可显示双方真实指令和执行变化。模拟执行器拥有世界修改权限以执行运动／碰撞，但这不授权指挥官绕过情报入口。当前没有安全沙箱，模块代码需按这个边界审查。

## 事件和显示隔离

`emit_event(kind, entity_id, weapon_id, position_m, data, target_id)` 产生单调 sequence、固定 tick 和 time_s。首批指挥事件：command_applied、command_rejected、order_issued、order_status_changed、order_progress、order_assignments_changed、order_execution_changed；内部 target_changed、cease_fire_changed。S05 复用 fired、hit、damaged、disabled 等 kind；事件负载由实际机制产生，S01 不合成命中／伤害。

模块用 `events_for_tick(world.tick)` 读本 tick 前序模块事件，用 `events_for_tick(world.tick-1)` 读上 tick 全部事件。两份邮箱独立于显示，返回事件复制；每个模块自行过滤种类和去重，跨 tick 的长期因果必须转为状态。`drain_events()` 只清空表现 outbox，显示池满或效果关闭也不能取消模拟事件／射击。outbox 不静默丢事件，表现层应每帧 drain 后按自身预算决定显示；无人消费时它会增长。`reset` 清空全部邮箱、outbox、任务、命令、接触、随机流及模块缓存。

## 可复验消费方

```sh
python3 tools/verify.py --owner S01 --timeout 60 test res://tests/test_simulation_definitions.gd res://tests/test_simulation_clock.gd res://tests/test_simulation_commands.gd
```

测试直接载入上述两型实际 JSON，不加载任何模型。测试模块只提供受控运动／随机流／任务计数器，明确不是飞行或战斗 AI。覆盖帧步不同结果一致、暂停／倍速／重置、定义与实例隔离、去重／授权／目标失效、生命周期、部分改派、混合域执行与指挥／观众视图隔离。实际命令与日志见 S01 交付。
