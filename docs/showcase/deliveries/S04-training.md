# S04-training：两型战斗机真实训练机动

2026-11-11，已实现并完成本任务范围自检，等待统筹最终验收与S14接入。主任务清单状态由统筹更新。

## 交付行为

通过统一BattleOrder新增显式 `aircraft_training`：F6F-5/A6M5a可选择协调大倾角转弯、爬升/俯冲、完整轴向滚转、滚转换向和半滚倒转。任务helper仅下达既有升力面、载荷、油门和方向控制；生产AircraftMotion按原性能积分。转满一圈、转向、爬升、半滚俯冲和改出均按实际几何完成，不按展示时间摆模型。

实现仅涉及 `BattleOrder`、统一入口训练参数校验、`AircraftTasks`的显式训练分支和新 `AircraftTraining` helper。没有新增同域执行模块；S14现有任务子类可直接继承。自然战斗任务和双机/四机编队逻辑不改。SB2C不接受战斗机训练，其性能条目与原巡航入口保留。未修改机型性能、运动积分、模型、效果、S14 Session/相机/菜单。

接口见 [aircraft-training-contracts.md](../../aircraft-training-contracts.md)，具体接续见 [S04-training-integration-handoff.md](../S04-training-integration-handoff.md)。运行时UI可读取实际phase、累计/峰值滚角、航向变化、高度、时间、原因与订单逐机执行记录，终止后仍保留module_data最后结果。

## 验证

使用固定Godot 4.7.2 Stable、Compatibility，原生最小化且NO_FOCUS，统一经 `tools/verify.py --owner S04-training` 获锁、限定超时与清理。原生输入冻结为450文件的 [frozen-input.json](../evidence/S04-training/frozen-input.json)；验证报告和输出在 [validation/](../evidence/S04-training/validation/)。

| 检查 | 结果 |
| --- | --- |
| 两型五类真实机动 | 52项通过，10例全部完成 |
| 安全/拒绝/取消/替换/暂停/2x/reset | 68项通过 |
| 原有航空任务/编队 | 40项通过 |
| F6F协调飞行 | 17项通过 |
| 地形安全 | 27项通过 |
| 统一命令生命周期/权限与视图分离 | 通过 |
| 原生连续录制 | 10段，2506帧，1100×700、15fps录制采样 |

安全检查包括高空当地限速、失速裕度、低高度、低油、动力/控制损失、实际损伤、友机110米冲突、超时。真实生产弹丸14发命中发动机后，训练failed并由既有无动力滑翔接管。受损状态注入只用于边界测试，原生训练录制全程使用真实控制积分。

10段 [原生连续视频及时间线索引](../evidence/S04-training/native/index.json) 保留实际订单与事件；已打开检查两型五类的关键姿态和改出画面。F6F/A6M轴滚峰值分别362.00°/363.78°，实际角速度独立积分确认跨越2PI；有限滚速刹停后略回滚，末帧净角不是完整圈数的唯一依据。轴滚损高约327/286米，半滚倒转损高约773/716米；没有无损高持续倒飞。

协调转弯目标倾角65°、实际稳定约65°，有限滚转惯性短暂达到约71.5°，未提升机型性能。爬升目标+100米后卸载进入俯冲，实际峰值约+132米再改出；这些是现有简化飞控的真实响应。S14应消费阶段和实测量，不能把目标值当成实际值。

## 冻结与接续

[source_hashes.json](../evidence/S04-training/source_hashes.json) 记录实现、测试、文档及保留依赖；[evidence_hashes.json](../evidence/S04-training/evidence_hashes.json) 记录完整证据；[final_freeze.json](../evidence/S04-training/final_freeze.json) 为交付标记。[cleanup.json](../evidence/S04-training/cleanup.json) 记录全部已结束训练验证轮次的退出/清理与进程组，检查器自身另由其verify报告确认退出；不关闭用户原有窗口。恢复副本在 `.local/s04-training-before/`，仓库无Git恢复点。

本项未重复开Chrome；S14负责最终可选演示、指挥UI、相机与Chrome，S08负责综合浏览器性能。DM01已完成独立原生/Chrome验证；正常1x p95 18.8ms，而4x实测仅约1.95x、p95 167.5ms，仍是S08未通过项。本交付不宣称训练或全场景浏览器验收通过。
