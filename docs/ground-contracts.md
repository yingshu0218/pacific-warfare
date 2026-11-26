# S10 固定岸防炮组契约

2026-11-11。实现范围为静止 `ground` 域，既不调用舰艇运动，也不调用飞机运动。两型配置、原图适用范围和估算见 `docs/references/weapons/` 内各自参考卡。`service_entry_year=0` 仅在 ground 且 `source.service_entry_year_status=unknown` 时合法，表示本子型首服役年未核实；资料日期仍保存在 `configuration_date`，不把手册年份当作首服役年份。

## 装配和安装

`data/ground/models.json` 是模型与单位 MountSocket 的共同数据源；`python3 tools/s10/generate_definitions.py` 重建两份单位、武器与弹药 JSON。模型仅实现 `apply_state`、`apply_weapon_state` 和真实炮口变换；没有自主时钟。固定承载、水平轴、俯仰轴、后坐炮身分离，Marker 不跟随后坐视觉偏移。`mount_visuals.recoil_axes` / `recoil_stroke_m` 为 VisualRecoil 的可选扩展，旧模型沿用原路径。

场景 `ground_deployments` 每项为 `{id,site_id,unit_definition_id,faction_id}`。`GroundDeployments.expand` 在 world.configure 之前读取 S09 稳定点，生成位置、朝向和 `module_data.ground_initial`；不修改地图。`validate` 在地形编译安装后检查角色、占位、半径、承载高度、建筑冲突、最低炮口及合法俯仰。位置不会被悄悄抬升。炮组接受舰炮的同一首次相交代理；代理只包围炮架，不放大成舰炮塔。

`ground_initial` 保存 `site_id,role,radius_m,train_limits_deg,elevation_limits_deg`。武器机械极限和场地极限实时取交：Mk13 为水平±70°、俯仰[-5°,20°]；两个 M1 为水平±180°、俯仰[-5°,85°]。米、秒和固定模拟 tick。

## 命令和己方情报

统一 BattleOrder 没有新增命令类型：ground `patrol` 表示区域防空或水道警戒，`engage` 表示指定己方接触。GroundTasks 是这两个类型的 ground 执行器；移动、护航和撤退被能力校验拒绝。GroundCommander 每6秒只读取 `commander_snapshot(faction)`，持有未终结命令的炮组不会被改派（包括真人命令）。指定目标失联32秒后执行失败，指挥官可再下警戒任务。

任务输出 `combat_intent {fire,allow_aa,lock_target:true}`，由统一目标分配器、火控和弹丸处理。`lock_target` 阻止通用 AA 自选逻辑绕过炮组的指定目标/区域；旧舰机没有此字段，原分配路径保留。下级 SET_TARGET 仍走 command bus。`unit.task.ground` 保存真实 order_id、phase、reason、target_id、site_id，正常 HUD 和时间线读取这些记录。

探测器发布接触时附加 `aim_offset_m`（地面目标为可见炮架高度）；火控读取缓存接触的这个值，不能读取敌方当前炮架状态。舰队仅在新鲜己方接触里选择 ground，新增场景日方 `shore_priority` 可优先选择已探测岸炮；接近目标的航点留在射程外侧，仍受 S09 海岸避障限制。没有强制命中。

## 弹药和损伤

Mk13：127mm、22.6796kg、960.12m/s、上限15,636.24m；60发、8秒操作循环、3°/秒人力转动是明确模拟估算。M1：40mm、0.88904kg、874.776m/s、有效防空2,743.2m、120rpm、240发；人力转动20°/秒、俯仰8°/秒是估算。没有修改现有舰机性能。

M1 HE-T(SD) 使用碰撞终止，未碰撞时固定8.5秒曳光燃尽自毁（原手册7–10秒范围的单值近似）。`ammo_profiles.self_destruct_s` 与 `self_destruct_radius_m=2` 是独立机制；`burst_radius_m=0`，不按目标截击时间设置重高炮引信。2米自毁破片半径为粗略游戏代理，沿用地形/建筑遮挡。

ground 损伤分工作、disabled（炮架/操纵失效，仍可受击）、wreck（结构耗尽，原位残骸）、removed（默认30秒清除）。无进水、下沉、坠落或漂移，失效后停止探测/射击。继续使用 CombatPresence 和原来的首次碰撞规则。`damage_phase` 增加 domain；session 将 ground_disabled / ground_destroyed 独立统计，不计入坠机或舰船失能。DM01 后续改飞机损伤时必须保留此分支。

## 集成边界

**S10 运行接口冻结：2026-11-11 00:44:18 +08:00。** 47个源文件/检查的 SHA-256 见 [source_hashes.json](showcase/evidence/S10/source_hashes.json)。后续 DM01 保留 CombatDamage 的 ground disabled/wreck 原位分支、damage_phase.domain 与 session 的 ground 分类；CombatFrame 本轮未修改，地面代理使用现有 `proxy_half_extents_m` 配置。FX01 无需修改地面行为即可消费现有 fired/hit/airburst/surface_impact 事件。此冻结只声明 S10 输入，不锁住 S02/S13 的并行工作。

新入口 `showcase/island_harbor.tscn` 使用 `data/scenarios/island_harbor_defence.json`；根大和入口、旧 first_playable.json/open_sea.tscn 和冻结地图不改。S13 environment_view 的绝对模拟时间、相机更新及 STREAM/幂等暂停路径保持不变。模型阶段和本轮验收为原生/headless，最终 Chrome、声音、10分钟/三次重开仍由 S08 对汇总版本验收。
