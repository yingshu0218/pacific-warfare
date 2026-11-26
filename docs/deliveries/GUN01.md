# GUN01 舰炮目标分配

2026-11-19，舰炮模块已实施并通过 headless 回归。普通 Web 和 Ego Lite 集成由统筹验收。

## 运行行为

舰炮使用单位现有任务目标和开火权限，从本方有效且新鲜的接触中选择。备选水面目标须与任务接触同域。分配时按炮位角色、现有武器域、射程和大致射界筛选，以接触距离、空中目标接近趋势及本舰已分配的可用炮位数排序。同一有效目标可以被多座炮共射。弹尽、损坏失能或停火均释放舰炮分配。目标锁限定在指定接触，舰炮防空仍需任务授权。

姿态读取 `world.shared_state.command_postures[faction_id].fleet.posture`，缺省或值不识别时按平衡执行。

| 姿态 | 炮位分配 |
| --- | --- |
| 进攻 `offensive` | 主炮优先任务目标。任务目标超出该炮位射界或被执行器判定受阻时，可转向同域备选目标。两用炮优先分担水面火力，在缺少合适水面目标时可参加防空。 |
| 平衡 `balanced` | 主炮优先任务目标。两用主炮在无可用任务目标时仍可防空。两用副炮根据本方的水面和空中接触及已有分配兼顾两域。 |
| 保守 `conservative` | 水面火力集中到任务目标。获准防空的两用炮优先空中接触。 |

专用防空炮在获准时分担空域接触。只要原分配仍可用，炮位在已有配置的目标冷却期内保持目标，装填中的炮位继续跟踪。权限、任务目标、姿态或接触有效性的变化可提前触发重分配。遮挡、真实提前量、炮口清障、装填及发射仍由现有武器执行器裁定。接触失效依照现有情报新鲜度，目标停止被探测后仍可能保留短时航迹。

`combat_runtime.mount_targets` 仍按炮位 ID 给出目标 ID 或空字符串，`mount_reasons` 给出分配原因，`mount_status` 仍由武器执行器报告。新的水面备选用 `surface_contact_allocation`，舰炮停火、失能与空弹分别可见 `hold_fire`、`disabled`、`empty`。单位任务目标由既有单位任务链维护，飞机和陆基单位沿用原分配分支。

`salvo` 以同一舰、同一 tick、同一真实目标下成功发射的主炮为一组。事件中的 `target_id`、`mount_ids` 和 `rounds` 均对应当组 `fired`，`last_salvo_tick` 仍记录最近主炮实射。齐射继续使用原有火控及实际逐管库存。

## 实射证据

爱荷华混合夹具以原有炮位、炮口、武器执行器和库存运行。两组主炮在第 60 tick 同时打向不同目标。专用防空炮在两 tick 之前对空开火。所有炮位的库存差等于各自的 `fired` 数，重开后炮位、目标、发射时刻、炮管编号和库存差一致。

| tick | `weapon_id` | 目标 | 扣弹 |
| --- | --- | --- | --- |
| 58 | `iowa/oerlikon_14` | `air` | 该次发射扣 1 |
| 60 | `iowa/main_01`、`iowa/main_02` | `task` | 各 3，共 6，生成一条齐射 |
| 60 | `iowa/main_03` | `aft` | 3，生成另一条齐射 |

同一星舷混合接触夹具的两用副炮实射计数如下。弗莱彻另有独立用例，验证缺省姿态、无水面任务且允许防空时，兼任防空的主炮仍对空实射并按该接触生成齐射。

| 舰队姿态 | 任务水面目标 | 备选水面目标 | 空中目标 |
| --- | ---: | ---: | ---: |
| 缺省 / 显式平衡 | 0 | 8 | 6 |
| 进攻 | 8 | 12 | 0 |
| 保守 | 0 | 0 | 10 |

S05 原双目标断言在第 480 tick 检查时失败。原夹具只提高整体和通用部位耐久，未覆盖飞机的机翼及尾部独立阈值。基线采样中两机在第 300 tick 前已双双失能，第 480 tick 的炮位已无可用目标。修正版仅在夹具中提高独立阈值，并把两机放到两舷以让各舷原装炮位分别具备清晰的射界。双目标分配断言保留，同时要求不同接触在一秒内都出现本舰的实际发射，并逐炮位核对库存扣减。指定的左舷炮位在被禁用前确有实射，禁用后退出分配和发射。[基线失败](../../.local/validation/runs/20261119T075549-eb120a6c/01-output.log) · [基线探针](../../.local/validation/runs/20261119T075721-9d5de451/01-output.log)

## 文件

| 路径 | 交付 |
| --- | --- |
| `scripts/command/air_defence/combat_targeting.gd` | 舰炮分配与短期保持，原 .uid 沿用 |
| `scripts/simulation/weapons/combat_weapons.gd` | 按真实目标汇总主炮齐射，原 .uid 沿用 |
| `tests/test_air_defence.gd` | S05 双目标防空夹具与实射断言，原 .uid 沿用 |
| `tests/test_naval_target_allocation.gd` | 新增舰炮分配、权限、复位及实射验证 |
| `tests/test_naval_target_allocation.gd.uid` | 新增测试 UID `uid://b0abaenahffsu` |
| `docs/deliveries/GUN01.md` | 本交付记录 |

新增运行文件和运行 .uid 均为零。根目录无 Git 元数据，以统筹保留的 `.local/repairs/20261119_dual_command/before` 快照核对现有文件。

## 验证和范围

所有 Godot 调用均经 `tools/verify.py` 共享锁，运行版本为 `4.7.2.stable.official.ed1daf0bf`。

```sh
python3 tools/verify.py --owner GUN01-final --timeout 55 --lock-timeout 55 test \
  res://tests/test_naval_target_allocation.gd res://tests/test_air_defence.gd \
  res://tests/test_gunnery.gd res://tests/test_ground_combat.gd \
  res://tests/test_contacts.gd res://tests/test_weapon_cycle.gd \
  res://tests/test_projectile_impact.gd
```

最终模块回归退出码 0，277 项断言通过。其中舰炮 61、防空 51、枪炮 69、陆基 48、接触 10、武器循环 24、碰撞 14。另一次同版本运行中，现有 2v2、4v4 飞机实战及重开共 31 项断言通过。报告确认各进程清理成功。[最终模块报告](../../.local/validation/runs/20261119T080920-0e9a917e/report.json) · [飞机回归日志](../../.local/validation/runs/20261119T080759-a64bff81/08-output.log)

根工程缺少早期 BOMB01 隔离夹具的 `tests/bombing/data/parameters.json` 和 `units.json`。直接运行该旧夹具时，拦截测试在加载阶段失败并由验证工具超时清理，轰炸测试遇到同一问题后中止。普通场景中的轰炸、截击和观战由统筹在当前 Web 包复核。[拦截夹具日志](../../.local/validation/runs/20261119T080522-55109945/09-output.log) · [轰炸夹具日志](../../.local/validation/runs/20261119T080759-a64bff81/09-output.log)
