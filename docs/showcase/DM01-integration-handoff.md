# DM01 → S14 / S08 接入

2026-11-11。F6F/A6M完整毁伤链与最终原生/Chrome自测完成，待统筹最终验收。字段见 `docs/aircraft-damage-contracts.md`；S14正常场景只需原有 AircraftSuite / CombatSuite 和型号 AircraftAdapter，保持 apply_state 及 advance→consume→apply_snapshot 顺序，不手动改健康/部件可见性。FX固定revision3 patch2。

- 权威部位：engine / wing_left / wing_right / tail / control；tail是真实尾翼结构，control是功能失能，近炸不能解释为断尾。
- 镜头/菜单只读 `damage.phase`、`damage.aircraft.detached_parts/fragments/contact_surface` 和实际事件 `aircraft_part_detached/aircraft_breakup/unit_impact`。不要看到crashing就提前播水花。
- `aircraft_motion.body_angular_velocity_radps` 是实际前后姿态差分，供脱离件继承。不要用heading/pitch遥测拼接三轴角速度。
- 每机3片/12秒，场景实际渲染48片；丢弃视觉不改碰撞/战果。reset/generation通过现有快照恢复原件，勿另写镜头侧碎片积分。
- 可独立选的受控验收入口：`tests/fixtures/dm01_review_stage.gd`，definition_id为两型正式ID，case_name为engine/wing_left/wing_right/breakup；通过生产CombatProjectiles.launch产生真实弹道/部位命中，绝不直接扣健康。该夹具是精准弹道演示，不是自然AI/库存测试；S14若复用此入口须明确标识、保留显式注册错误检查，切场正常递增generation。不要从旧assert副作用版本复制。自然场景照常使用生产火控与库存。
- 最终冻结：`.local/dm01-final-gearfix`，最终受控Web构建来源同一输入；`build/dm01-gearfix-rootview-web/build_manifest.json`保留完整来源。最终画面在 `docs/showcase/evidence/DM01/final-native/`、`final-chrome/`。旧轮舱盖/双视口失败材料不是验收版。
- 仅检视UI曾因FULL_RECT锚点后再次设置size，使容器与子视口变成2560×1440。已改为单一主视口检视，正常生产场景/模拟不改；布局探针与每个Chrome受控主体投影(640,360)均有记录。

S08性能待办：正常1倍453帧p95=18.8ms；请求4倍只有约1.95倍实效、p95=167.5ms。生产计时显示推进模拟p95=145.3ms、表现10.6ms，帧尾待追赶模拟积压11.22秒；每帧16tick预算与约7.35fps对应约1.96倍上限。DM没有删真实战斗/损伤或提高预算来掩盖。时钟一致性/交互通过不等于4倍性能通过；详见 acceleration-handoff.json，最终S14全单位规模/长测仍由S08检查。

本轮先完成上述DM小交付，再由原S04提供BattleOrder训练API。SB2C当前仅S14独立模型/性能与通用导航，不宣称拥有F6F/A6M预切毁伤；不得据此复制战斗机训练或性能参数。
