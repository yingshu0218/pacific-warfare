# CMD01 舰队态势与双机任务

2026-11-19。CMD01 机制验收通过，运行源码已冻结。普通 Web 导出和 Chrome 验收由统筹执行。

[源码冻结清单](CMD01-sources.json)记录六份运行文件及其修复前哈希，集合 SHA-256 为 `00693c0942a84f0dd1c57ddb3a4937f420c216b6063d71255438a4a6d45d429c`。工程没有 Git，恢复基线见 `.local/repairs/20261119_showcase_command/before`。本轮核对了基线中 35 份武器、弹药、火控配置与弹道相关文件，内容一致。

## 指挥与执行

- 双方用同一套规则和各自的接触记录。旗舰按距离、接近趋势和已辨识的静态火力范围选敌。对己方构成立即威胁的水面舰优先，缺少紧迫舰艇威胁时可压制能打到己方的岸炮。护航舰在自身可射距离内用同一规则自卫。火控继续裁定射界、遮挡和实际开火。
- 原目标失联且有新的可交战目标时，旗舰可在普通换令冷却内改派，时间线关联原令与替代令。没有替代目标时，舰艇沿最后已知接触搜索，搜索超时由执行器回报失败。具有外海巡逻区的航母接收该区的独立巡逻令。
- 目视可确认静态角色或对海火力粗范围，随后雷达更新可保留同一条接触已掌握的识别信息。仅雷达初次发现时只能按未识别类型处理。选敌与转向依据本方接触几何，敌方实况不进入指挥输入。
- 有足够战斗机时，来袭轰炸机和敌方战斗机分别交给两组真实双机。已接战的双机拥有优先保持任务的范围和短时失联窗口。接触排名改变不会拆分长机和僚机，也不会更换执行器订单 ID。接触长时间丢失、有适合接替的目标或敌机离开防御范围时可重新分派。可用机只有一组且有轰炸威胁时，该组可以优先拦截轰炸机。
- 正在执行的真人命令、独立任务和撤退受保护，普通场景的初始巡逻可交接给舰队指挥。所有调度沿现有命令校验、分发、接收和执行链。保留 `surface_threat`、`shore_battery_threat`、`carrier_station`、`intercept_bomber`、`intercept_fighter_cover` 意图码。

主要路径为 `scripts/command/commander/fleet_planner.gd`、`scripts/command/contacts/combat_contacts.gd`、`scripts/behaviors/fleet_formations/fleet_tasks.gd`、`scripts/simulation/ship_motion/fleet_config.gd`、`data/expansion/fleet_profiles.json`。新回归用例为 `tests/test_cmd01.gd`；`tests/test_commander.gd` 的旧分组断言改为验证实际较近的双机和保留的护航双机。

## 普通港湾采样

Godot `4.7.2.stable.official.ed1daf0bf` headless，以正式 Session、生产任务与 60 Hz 固定步长推进 90 秒。场景采用同时在线的 AIR01 源码，本记录为当时的完整战局。原始事件、命令记录和十秒间隔单位状态保存在 `.local/repairs/20261119_showcase_command/cmd01-harbor-90s.json`。下表发数按真实 `fired` 汇总。

| 观察 | 修复前普通港湾 | 本轮共同源码 |
| --- | --- | --- |
| 大和首令与对舰开火 | 首令打岸炮，90 秒向岸炮发射 184 发，对舰 0 发 | 首令 `surface_threat` 指向衣阿华，3.40 秒首发，共 60 发；衣阿华向大和发射 223 发 |
| 双机指令 | 旧港湾没有真实轰炸机拦截 | 双方都由 `pair_1` 拦截轰炸机、`pair_2` 接战战斗机；日方战斗机组在长机损失后由僚机沿原令接战 |
| 空战与弹着 | 旧港湾无实际炸弹 | 战斗机对战斗机发射 196 发，对轰炸机发射 208 发；24 枚炸弹均有投放、接触和爆炸事件 |

雪风初段向仍威胁本队的岸炮发射 10 发，随后因真实伤情接到撤退令。美国战斗机组在原目标失联后搜寻，约第 30 秒改派向另一架敌机，命令记录含原令终态与替代 ID。

## 验证记录

- 受控复现先在接手版本上捕获 6 个失败，涉及失联换令、双机任务重置以及撤退和独立任务被覆盖。修复后 CMD01 专项 23 项通过，接触 10 项通过，共用命令调度、权限、生命周期与视图隔离脚本通过。报告 `.local/validation/runs/20261119T070208-aeeffd7c/report.json`。
- S06 旧指挥、队形、撤退卡滞、舰船运动和确定性回放在隔离项目通过，共 83 项。报告 `.local/validation/runs/20261119T070338-6ccb9ab4/report.json`。正式目录的 74 个 S06 历史证据文件逐一核对 SHA-256，内容一致。
- 附加防空检查 `test_air_defence.gd` 的双目标分火断言失败。在保存的修复前运行源码上复现了相同的断言失败，两次均为 25 项中 1 项失败。基线报告 `.local/validation/runs/20261119T070258-fae7f830/report.json`。港湾记录另有 9 条低层 `set_target` 拒绝，发生在 G4M1 失活后、空中执行器持有的接触记录尚未更新的 0.15 秒内，高层舰队订单没有被拒绝。两项均记录作集成边界。
- 港湾固定步长报告 `.local/validation/runs/20261119T070030-21dd1630/report.json`。采样和机制命令如下。

```sh
python3 tools/verify.py --owner CMD01-mechanisms --timeout 45 --lock-timeout 55 test res://tests/test_cmd01.gd res://tests/test_contacts.gd res://tests/test_simulation_commands.gd
python3 tools/verify.py --owner CMD01-harbor --timeout 55 --lock-timeout 55 godot -- --script res://.local/repairs/20261119_showcase_command/observe_battle.gd -- --seconds=90 --label=cmd01-harbor-90s
```
