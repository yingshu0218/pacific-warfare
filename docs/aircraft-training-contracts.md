# S04 Showcase 真实训练订单

2026-11-11，已实现并通过机制、安全、原生连续画面与受影响回归，自检冻结、待统筹最终验收。单一入口仍是 `SimulationWorld.submit_order(BattleOrder)`；新增 `order_type="aircraft_training"` 与纯数据 `training` 字段，不使用intent魔法字符串。不改Session、相机、菜单或机型性能表。交付见 [S04-training](showcase/deliveries/S04-training.md)，场景接入见 [S14 handoff](showcase/S04-training-integration-handoff.md)。

```gdscript
var order: BattleOrder = BattleOrder.new()
order.order_id = "exercise:roll:1"
order.issuer_id = "s14_exercise_director"
order.source = "human"
order.faction_id = "us"
order.recipient_ids = ["us_air_1"]
order.order_type = "aircraft_training"
order.training = {"maneuver":"axial_roll", "direction":1}
var receipt: Dictionary = world.submit_order(order)
# 必须先执行再检查receipt，不把调用写进assert。
```

maneuver 为 bank_turn / climb_dive / axial_roll / roll_reversal / split_s；direction=+1右滚/先右转，−1左。可选 turn_angle_deg=90（45..180，仅bank_turn）、climb_height_m=100（60..250，仅climb_dive）、bank_angle_deg=65（45..min(65,机型最大倾角)，仅bank_turn/roll_reversal）、min_start_agl_m（只能提高安全要求）、max_duration_s（5..60；五类默认分别45/55/25/45/30秒）。无敌目标、区域/航点或模型变换参数。未知字段、非有限数字、无关参数均拒绝。

只接受 F6F-5 / A6M5a，使用各自完整原性能。拒绝起始姿态/速度不合适、低高度、低油、动力/损伤异常或不安全split_s包线；SB2C明确不接受战斗机训练。bank_turn至少600m、climb_dive800m、axial_roll/roll_reversal1000m；split_s同时检查实际高度、预测速度/高度损失。推荐平飞、115m/s、AGL2400m起始，最终以accept结果为准。

注册点仍是现有AircraftTasks（含继承它的SB2CShowcaseTasks）+AircraftMotion；专用AircraftTraining只生成控制输入，不另注册同域执行器，不需要Session补丁。自然AI分支不触发训练。

控制只设置既有lift_plane_normal/load_factor_g/方向/油门等输入；运动仍由生产AircraftMotion积分。先卸载滚入再拉杆，完整滚转的累计角由实际姿态平行运输差分跨±PI积分；真实高度、航迹转角/倒转和改出状态控制阶段完成，不按时间摆模型。

执行快照为 `unit.task.aircraft.training`（执行中）及 `module_data.aircraft_training`（保留最后结果）；含order_id、maneuver、direction、phase、status、reason、elapsed_s、roll_accum_rad/peak_roll_rad、heading_change_rad、height_change_m、peak_height_m、min_agl_m、bend_rad、target_turn_rad、target_climb_m、phase_history等实际数据。角度为弧度，距离米，时间秒。phase_history保存离开阶段时的实际累计角/转向/高度；不用于推算未来动画。

阶段变化/约2秒进展走原BattleOrder `execution[unit_id].progress/reason/changed_tick` 与事件；订单history保留正式状态变化，顶层progress不替代每架机实际进度。`receipt.accepted`只代表提交通过，不代表执行成功；推进模拟后读取订单executions与status。正常完成订单completed，安全中止failed；取消/替换沿用cancelled/superseded。终止后unit.task会清除，UI应按order_id读取保留的module_data最后结果。能力拒绝理由在订单failed记录。

低高度/地形风险、失速/超速、失去动力/控制/燃油、实际损伤、友机冲突（实际距离小于110米）、超时和新指令/取消均中止，清理训练控制并交还既有安全飞控。reset清理训练记忆。S14只消费真实阶段和稳定地平线相机，不为显示改变姿态。双机/四机编队仍用原有任务；训练演示起始几何应让各机有安全间隔。

本轮52项真实机动与68项安全检查通过，两型各五类连续原生记录共2506帧。完整轴滚实际峰值F6F 362.00°、A6M 363.78°，完成时会因有限滚速改出而略回滚，不能把末帧净角当作是否转满一圈的唯一依据；测试另以实际角速度积分验证跨越2PI。两型滚转与半滚倒转均有真实高度损失。15fps是录制采样率，不代表运行性能；训练Chrome由S14/S08最终场景覆盖。
