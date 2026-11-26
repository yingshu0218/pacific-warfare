# S04 真实训练机动 → S14 接入

2026-11-11。训练实现、两型十段原生连续记录、安全边界和相关健康回归已完成；冻结入口为 [final_freeze.json](evidence/S04-training/final_freeze.json)。本项自检完成，统筹验收与场景最终Chrome另行记录。

## 调用与注册

唯一入口是 `SimulationWorld.submit_order(BattleOrder)`，`order_type="aircraft_training"`，参数放 `training` 字典。完整例子和参数范围见 [航空训练契约](../aircraft-training-contracts.md)。演示导演沿用 `source="human"`、`issuer_id="s14_exercise_director"`、真实faction与recipient ID，UI标“演示任务”。每次段落使用唯一order_id，不能直接改unit transform。

AircraftTasks内部调用纯控制helper `AircraftTraining`；已有 `AircraftTasks + AircraftMotion` 可执行，不增加模块、不改Session。S14的 `SB2CShowcaseTasks` 继承此入口：F6F/A6M训练在该注册组合中已测试完成；SB2C明确拒绝，原巡航/重组/撤退保持。performance.json含SB2C条目，文件与接续前哈希一致。

可选择 `bank_turn` / `climb_dive` / `axial_roll` / `roll_reversal` / `split_s`。建议演示初始平飞、115m/s、AGL2400m、无敌机，方向±1；以提交后的真实订单执行状态为准。固定角度/速度并不保证任意高度和损伤状态获准执行。S14当前旧split_s若仍发普通自然接敌任务，应换为本入口，只有实际半滚倒转完成才能显示成功。

## UI与相机读取

执行中读 `unit.task.aircraft.training`；终止后读 `unit.module_data.aircraft_training`，核对order_id。实际phase序列如下：

| 机动 | 实际阶段 |
| --- | --- |
| bank_turn | roll_in → pull_turn → recover → completed |
| climb_dive | climb → dive → recover → completed |
| axial_roll | roll → recover → completed |
| roll_reversal | roll_in → pull_turn → roll_reverse → pull_reverse → recover → completed |
| split_s | roll → pull → recover → completed |

安全终止为phase/status `aborted`，订单failed；取消/替换订单保持原cancelled/superseded。module_data保留reason和实际进度直至新训练或reset。订单 `execution[recipient_id]` 每次阶段变化或120tick更新progress/reason；顶层progress可能仍为forming，不能代替逐机状态。receipt只确认排队/校验；不得据此播放成功台词。

滚转进度按实际姿态跨±PI积分，`peak_roll_rad`用来识别是否已经转满一圈，`roll_accum_rad`可因改出略回滚；相机只读实际位置和姿态，保持世界地平线稳定。半滚倒转使用真实航迹弯曲与接近反向平飞判定。状态/时间线不得由视频或预计时长替代。

## 证据与边界

[native/index.json](evidence/S04-training/native/index.json) 索引10段MP4、对应实际订单/事件/轨迹JSON和关键帧；两型各五种完整录制，15fps为采样率。完整轴滚峰值362.00°/363.78°，高度损失约327/286米；半滚倒转反向约179.4°，高度损失约773/716米。两型使用各自性能，AircraftMotion与performance未改。

机制52、安全68、原任务40、协调飞行17、地形27项及统一命令回归通过。安全覆盖低AGL、密度失速裕度、当地限速、低油、动力/控制损失、实际损伤、友机冲突、超时、取消、替换、暂停/2x/重开。另有真实14发发动机弹丸命中中止训练并交回滑翔的证据。

本项只交付控制与数据接口，不改S14场景、菜单、导演、Guide、Session或相机。编队展示继续原长僚/分队/重组逻辑；训练时预留110米以上友机安全距离。最终可选入口和Chrome由S14/S08接续。本轮无训练浏览器窗口/HTTP服务；原生与编码均经verify锁、超时和清理。DM01既有成片与证据保持冻结，4x性能未通过事项继续归S08。
