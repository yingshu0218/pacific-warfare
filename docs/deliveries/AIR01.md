# AIR01 默认港湾混合实战与电影观战

2026-11-19。AIR01 已完成生产场景的机制与原生画面检查，前一冻结版由统筹在真实 Chrome 通过 15 项验收。低层锁定重试收尾已通过定向与默认港湾 headless 复验，最新冻结版本的普通 Web 重建和 Chrome 复核交由统筹。

## 运行改动

- 普通 Web 启动器默认选择 `expanded`，入口为 `showcase/carrier_harbor.tscn`，直接开始青岬港湾。G4M1、B-25J、SB2C 各有两架在空，分别提交水平对岸、水平对舰、俯冲对舰任务。下单依据本方接触，并保留人工命令优先。双方战斗机双机由 CMD01 根据各自接触选定拦截对象。
- 原候选的八个战斗机对战斗机点射窗口全部停在炮位 `traversing`。原飞行控制追逐已经变化的提前量，并在成功对准前就用完点射窗口。飞行任务现在用本方速度和己方接触估计提前量的短时变化。扣扳机保留当前距离、方向、已应用目标和友机避让条件。实际发射首弹后才开始点射时长和冷却，炮口、弹药、发射容差、射界、碰撞和伤害由原有模拟执行。
- 自动镜头分别保留活跃空中行动及真实投弹、弹着、枪弹发射的取景机会。首次枪弹发射可接替同类接近镜头，重复动作保留停留间隔，主炮也保留切回机会。拦截接近镜头优先让轰炸机清楚入画。上栏显示三队当前任务和投弹余量，**空中交战**在同一场战局里切换视角，**指挥态势**可从电影模式展开双方命令与执行历史。
- 保留原菜单中的独立轰炸、截击、训练及航母甲板段落。默认战局的初态、目标与任务来源列在 [场景配置](../../data/scenarios/s14_expansion_harbor.json)。[AIR01 源码 SHA-256](../showcase/evidence/AIR01/source-sha256.json) 覆盖本任务九份运行文件及三份验证脚本，冻结副本位于 `.local/repairs/20261119_showcase_command/air01/frozen`。当前目录无 Git 仓库。

## 同局事件与画面

正式港湾场景和正式 Session，种子 707，同一局推进 90 模拟秒，录像取样为每帧两个 60 Hz 模拟步。所有炮弹、枪弹、投弹和物理弹着均来自模拟事件。

| 实际事件 | 结果 |
| --- | --- |
| 双方舰对舰主炮弹 | 日方 21 发、美方 137 发。抽样中大和与衣阿华实际互射 |
| 战斗机对战斗机 | 196 发，首发 7.20 秒。地狱猫和零战均有实际发射；两边在对战任务中均出现实际滚转、垂直速度和航向变化 |
| 战斗机对轰炸机 | 208 发，首发 9.63 秒。零战向两架 B-25J 发射 196 发，地狱猫向 G4M1 发射 12 发 |
| 炸弹离架、接触、爆炸 | 两架 G4M1 合计投放 24 枚，24 个弹丸 ID 均关联到接触和爆炸。第一枚于 44.72 秒离架，约 64.60 秒在港区地形接触 |
| 电影镜头 | B-25J 接近时可见，G4M1 约 2.52 秒入镜，约 7.52 秒切实际战斗机交火，约 10.05 秒切零战截击，约 13.08 秒切大和，约 45.38 秒显示炸弹离架，约 64.62 秒切弹着 |

本样本中只有 G4M1 完成了投放。各机型保留自己的航路、投放限制、受损和取消条件。切换空中视角的瞬间，模拟快照保持一致，随后仍继续同局运行。重开会重新生成战局并回到自动电影。

## 复验

```sh
python3 tools/verify.py --owner AIR01-default --timeout 150 --lock-timeout 120 \
  test res://tests/test_air01_default_harbor.gd
python3 tools/verify.py --owner AIR01-native-final --timeout 160 --lock-timeout 120 \
  godot --render -- --script res://tests/test_air01_default_harbor.gd --position -1800,0
```

- [原生事件与取景记录](../showcase/evidence/AIR01/native.json)包含每次切换的主体、对应事件序号、双方入画情况和 24 条投弹接触链。原生渲染为 Apple M5 的 Compatibility，1280×720。实际开火画面中，两架交战飞机及曳光同时入镜。 [B-25J 接近](../showcase/evidence/AIR01/bomber_intercept.png) · [G4M1 作战](../showcase/evidence/AIR01/bombing_run.png) · [狗斗开火](../showcase/evidence/AIR01/fighter_dogfight_fire.png) · [截击开火](../showcase/evidence/AIR01/bomber_intercept_fire.png) · [大和主炮](../showcase/evidence/AIR01/surface_gunnery.png) · [炸弹离架](../showcase/evidence/AIR01/bomb_released.png) · [港区弹着](../showcase/evidence/AIR01/bomb_explosion.png)
- [修复前炮位诊断](../showcase/evidence/AIR01/r2-traversing.json)保存八个点射窗口的炮位状态和最接近的机身提前量。正式结论只统计 `fired` 与弹丸 ID。
- 独立正式段落验证到 D4Y、G4M、B-25 实际弹着，两场独立截击实际开火，F6F 训练通过实际机动完成检查，甲板双机段落进入实际离舰爬升。独立 SB2C 对移动舰仍会因过低中止并保留弹药，符合 [既有交付记录](S14-bombing.md)。独立段落记录在 `.local/repairs/20261119_showcase_command/air01/independent_segments.json`。
- 训练机制回归通过 52 项检查。共享验证器留存原生采样与进程清理报告 `.local/validation/runs/20261119T070501-d53a932e/report.json`。该原生报告对应首次冻结版。

- 基线对照复现了独立 SB2C 的相同事件计数及双机阶段序列，也复现了旧 S07 在 720p 的两条指挥区域布局断言。根项目的旧 BOMB01 私有夹具缺少 `tests/bombing/data/parameters.json`，独立作战结果改由上述正式 Session 验证。
- 旧 S04 2v2 用例仍通过。4v4 在本轮较早击落后暴露了旧接触缓存和命令校验之间的重试窗口。123.93 至 126.02 秒，同一飞机向已失效的同一接触重复提交低层锁定请求，126 次均被 `invalid_enemy_target` 拒绝，旧 4v4 的零拒绝断言因此失败。该现象在 90 秒默认港湾验收窗口之外的旧独立夹具观测到。收尾前原始诊断保留在 `.local/validation/runs/20261119T071139-b49cdfb8/01-output.log`。

## 低层锁定重试收尾

飞机任务执行器按受令飞机、目标和己方接触的 `observed_tick` 记录锁定拒绝。提交时拒绝立即记录，排队后被拒绝则通过原命令 ID 匹配执行结果。同版或更旧的接触继续等待，新鲜且更新的观测可重新提交。原有命令校验照常记录首次拒绝，飞机根据己方接触继续执行飞行任务。

```sh
python3 tools/verify.py --owner AIR01-target-lock --timeout 60 --lock-timeout 90 \
  test res://tests/test_air01_target_lock.gd
```

- 定向用例分别模拟提交时失效和已排队后失效。两架飞机在每版接触各只收到一次拒绝，复制旧观测和回退到更旧观测均无重试。实际状态恢复但己方尚未更新观测时仍等待，新观测到达后正常锁定。
- 同一旧 4v4 损失片段从 126 次降到首次真实拒绝的 1 次，发弹 275 发、命中 11 次及再接敌 32 次保持一致。保留当时零拒绝断言失败的原始诊断。定向复验见 `.local/validation/runs/20261119T071924-853af1be/report.json`，默认港湾和 4v4 损失片段复验见 `.local/validation/runs/20261119T071957-fa4a09e0/report.json`。
- 默认港湾重复锁定从 9 次拒绝降到 1 次，保留 F6F 对失效 G4M1 的首次真实拒绝。90 秒的舰炮、双类空中开火、24 枚投弹与弹着、机动统计和镜头切换时点及主体与原生基线一致。 [收尾后默认港湾记录](../showcase/evidence/AIR01/headless-target-lock.json)

## S04 完整战斗回归

共享锁于普通 Chrome 退出后取得。旧 2v2 继续要求零拒绝。4v4 最多允许一次由执行当前交战任务的战斗机发起的 `SET_TARGET`，该请求须因敌机已失效而被拒绝，且己方仍保有该接触。其他拒绝及重复均使测试失败。每架机每版接触的重试限制仍由定向用例验证。

```sh
python3 tools/verify.py --owner AIR01-S04-combat-final --timeout 120 --lock-timeout 150 \
  test res://tests/test_aircraft_combat.gd
```

31 项检查通过。2v2 在 160 秒内发射 318 发、命中并造成损伤 6 次，拒绝 0 次。4v4 发射 275 发、命中并造成损伤 11 次，保留 1 次失效目标锁定拒绝。两个场景重开后的完整状态与事件统计均一致，每发均扣除真实库存，实际触水与残骸状态检查通过。旧 S04 结果保留，新采样单独保存。AIR01 运行文件哈希复核一致，最终测试源码已纳入冻结清单。 [历史 S04 证据](../showcase/deliveries/S04-combat.json) · [完整回归结果](../showcase/evidence/AIR01/s04-combat-final.json) · [共享验证报告](../showcase/evidence/AIR01/s04-combat-report.json) · [源码哈希](../showcase/evidence/AIR01/source-sha256.json)
