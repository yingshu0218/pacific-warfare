# DM01 航空部位毁伤契约

2026-11-11，读模型 v1。单位局部坐标为 +X 右、+Y 上、−Z 前，米/秒。仅 F6F-5、A6M5a 采用下述航空扩展；舰艇、陆基仍沿用 S05/S10 分支。健康飞行继续 S04 v3。毁伤参数是游戏近似，不宣称历史弹道或断裂载荷实测。

## 命中、部件与事件

`CombatFrame` 的航空代理明确标记 `wing_left`、`wing_right`、`tail`（尾翼结构）、`engine`、`structure`。`damage.parts` 为 0..1 部位健康；实际 `hit`/`airburst` 经 `CombatDamage` 累积损伤。engine=0 只失去动力，保留主动飞行/滑翔；不自动断翼。左右翼为零时只脱离对应机翼；tail=0 才脱离尾翼并失控。既有 `control` 为操控功能健康，近炸仍损伤 control；control=0 会失控但不表示尾翼已断裂，也不自动脱离任何实体。总结构耗尽时至多把余下两翼和尾翼各分离一次，保留主机身作为统一碰撞/接触单位。

`damage.aircraft` 含 `detached_parts`、`fragments`、`breakup`、`angular_velocity_body_radps`、`contact_surface`。`aircraft_part_detached` 事件由模拟发布，data 含 `part_id`、`position_m`、`rotation_rad`、`velocity_mps`、`angular_velocity_body_radps`、`local_anchor_m`、`lifetime_s`、`reason`。来源可追溯到 `damaged.projectile_id`。每部件一次，固定上限三片/单位、12 秒；碎片不参与战斗碰撞，独立按简化重力/阻力/角速度推进，接触后沉没或停留至回收。丢失机翼/尾翼代理立即从 `frame.proxies` 移除，同侧挂点武器禁用且不会重新启用。

碎片初始位姿为受击时真实单位变换 × 部件安装变换；速度为主机速度加当时世界角速度 × 部件偏置，无随机弹出。角速度取健康飞行实际 old_basis→next_basis 的相对旋转轴角/固定 dt，存为 `aircraft_motion.body_angular_velocity_radps`，不混合航向/航迹角速率；旧遥测字段保留。快照仅存纯数据 position/rotation/velocity，渲染不能决定损伤或积分运动。预切模型保留完整几何；标志、炮口、灯、操纵面归所属组；`StaticModelBatch` 仍在各组内部合批。渲染只切换原组可见性并最多实例化三片，共享网格而不修改共享材质。另有场景级实际残片 Node 上限48，超过时舍弃该视觉残片并记数；不修改模拟部位/碰撞/弹药/战果，避免晚出现的残片。reset/free 归还预算。

## 终端运动与接触

断翼/尾翼/结构失效进入既有 `crashing`、active=false，停火并交还任务。姿态从最后真实姿态连续积分，使用有界角加速度/角速度、剩余翼面积对应升力、姿态阻力及重力；不使用预制路径。发动机独立失效继续健康控制器的 glide 分支，桨相位连续且转速逐步降至风车转动。真实地形扫掠首次接触才发布 `unit_surface_contact` → `unit_impact`。空中不预播水花。主机体入海后沉入，陆上保持静止；12 秒内回收航空残骸，地面单位的30秒生命周期不变。

## FX01 接口与时钟

使用 [FX01 已发布接口](showcase/fx01-effects-contracts.md)，不修改 CombatEffects。航空 `damage.effect_emitters` 始终存在，至多四条：engine smoke/fire 由真实 engine 健康/火情生成，机首局部锚点取型号 `damage_effects`。严重结构火情可增加机身烟源；接触、离场、removed 输出空数组。碎片不产生额外烟源。`unit_impact` 由真实接触发出一次，FX01 负责水花/尘土与停止主机后续空中烟。

所有运动与寿命使用 fixed tick，模型 apply_state 重复消费同一快照不推进；暂停不变化、倍率只影响模拟进度、reset/generation 恢复原件并清理碎片。原有 advance → consume → apply_snapshot、Web STREAM/幂等暂停和 S13 绝对模拟时间环境契约保持。
