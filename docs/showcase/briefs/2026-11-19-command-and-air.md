# 11 月 19 日 Showcase 接续执行

用户要求日美舰队指挥官根据实际态势决定攻击目标，并在默认 Showcase 看到实战轰炸、战斗机拦截轰炸机和战斗机狗斗。新建两个执行聊天，模型 GPT-6.2 Sol，推理强度 High。本聊天负责统筹、计划、任务分解、调度及最终验证。

## 基线与共享边界

- 在同一个本地项目实施。项目没有 Git。上一可用版的全部 539 份运行资源、工具、配置及 Web 包在 `.local/repairs/20261119_showcase_command/before`，哈希见同目录上一级的 `baseline-sha256.json`。
- `before.json` 是旧普通港湾 90 秒固定步长的真实执行记录。第一条大和交战指令指向港口岸炮，衣阿华则获令对舰；大和 90 秒内有 184 发射向岸炮、0 发射向水面舰，场景中 SB2C 巡航，B-25J 和 G4M1 只有静态模型，真实炸弹数 0。
- 用户纠正前统筹已留下部分源码和两个自然战局对照，尚未导出。执行聊天接手各自文件，使之达到可交付状态。使用 `.local/repairs/20261119_showcase_command/observe_battle.gd` 可复验生产 Session 与正式任务执行器；参数见脚本。
- 两个执行聊天可并行编辑各自文件。所有 Godot 验证使用 `tools/verify.py` 共用锁、限时运行。重型验证串行，统筹负责普通 Web 构建与 Ego Lite 实测。保留已有证据及用户进程。无定时交战、强制开火/伤害或轮流喂画面。

## CMD01 舰队指挥与态势选敌

负责 `scripts/command/commander/`、`scripts/command/contacts/combat_contacts.gd`、`scripts/behaviors/fleet_formations/fleet_tasks.gd`、`scripts/simulation/ship_motion/fleet_config.gd`、`data/expansion/fleet_profiles.json` 及该范围测试。会读取另一任务场景，不编辑其 JSON、界面、机动或导出工具。

- 接手当前态势评分。双方共用规则，依据己方新鲜接触、距离、接近趋势和可辨角色。水面交火威胁优先，岸炮在威胁本队且缺少更紧急水面目标时可被压制。脱离、目标失联、有新威胁时重新决定，接令、改派、失联/失败可在正常命令时间线追踪。护航舰的自卫也应遵守同一原则；航母在配置的外海区活动。
- 新接触字段 `role`（目视识别的静态类型）和 `surface_range_m`（游戏内静态粗范围）是可选，仅从己方探测得来；不含敌方实况、油弹、战损或命令。正常火控仍裁决射界与遮挡。已加意图码 `surface_threat`、`shore_battery_threat`、`carrier_station`、`intercept_bomber`、`intercept_fighter_cover`。保持这些消费者契约。
- 通过真实队伍分别安排双机拦截来袭轰炸机和接战敌方战斗机。保留同一接战任务和双机角色的稳定性，避免距离轻微变化改令使飞行执行状态重置。主从分配、水面目标转移、无情报不指派及原 human 命令保护需验证。既有独立任务和退却不应被误覆盖。
- 交付 `docs/deliveries/CMD01.md`，注明改动路径、采样、测试和剩余边界，冻结运行源后完成聊天。

## AIR01 默认港湾混合实战与观战

负责 `data/scenarios/s14_expansion_harbor.json`、`scripts/showcase/expansion/{carrier_harbor,expansion_missions}.gd`、`scripts/bombing/commander.gd`、`scripts/presentation/cameras/observer_camera.gd`、`ui/observer_{hud,text}.gd`、默认 Showcase 启动器 `tools/run_first_playable.py`、验证及 `scripts/behaviors/aircraft/` 中确认必要的空战执行修复。可读舰队指挥文件，按上方契约消费。需要跨边界修正时在交付注明供统筹协调。

- 让普通 Web 默认港湾同局有 B-25J、G4M1、SB2C 等在空作战任务，保留独立轰炸、拦截、训练及甲板段落。沿只读观察和真正的投放/碰撞，不以预设动作或强制结果代替。可调整合理初始态势，保留武器和飞行约束。至少一组出真实投放和弹着，有实际战斗机对轰炸机射击；截击可以成功或失败。两边战斗机须表现出互相接战、三轴机动和实际射击机会。
- 已部分接好同帧自动事件镜头、空中交战按钮、状态摘要和可展开指挥态势，需要核查实际可读性。首轮 r1 有实际战斗机对战斗机开火 48 发、13 枚炸弹和 F6F 射 G4M，B-25 被舰上防空击落。r2 把 SB2C 放回原始较远航段，使两军真实下达不同双机的空战/轰炸机拦截指令，零战对 B-25J 142 发，F6F 对 G4M1 33 发并有 12 枚真实炸弹；第一段战斗机几何存在接战姿态和短点射指令，成品桶却没有战斗机对战斗机的 `fired`。请查根因，不能把 `burst` 意图算成已开火。可读取记录 `integrated-r1.json`、`integrated-r2.json`，指挥稳定性由 CMD01 并行处理。
- 默认电影镜头应在合理观战时间实际拍到轰炸机、截击和狗斗，并保留炮战可见性。显式只看空中时，同一战局持续推进。统筹在 Ego Lite 核对实际可见画面与观战操作。
- 交付 `docs/deliveries/AIR01.md`，注明改动路径、真正的事件、运行命令、测试与剩余边界，冻结运行源后完成聊天。

## 统筹验收

核对修改/源哈希、可恢复基线、独立目标与原机制回归。确认普通入口直接生成本轮全部事件。统一构建并在 Ego Lite 核对页面、自动镜头中的实际飞机、空中交战按钮、双方指挥态势、重开和控制台。按本轮实际验证范围更新状态及启动说明。
