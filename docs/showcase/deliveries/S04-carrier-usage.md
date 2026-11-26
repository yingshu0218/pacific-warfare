# S04：F6F 舰载使用态候选 r10

2026-11-11。私有候选自验冻结；统筹已实际复核 r10 的停放、进近、尾钩和损伤视图，通过本轮模型大形/使用态。最终 hash/清理轻量复核及 OPS 消费由统筹接续。普通 S08 公共源码未替换，未将静态摆放记作起降闭环。

交付入口：[候选清单](../../../candidates/s04-carrier-usage/candidate-manifest.json)、[四文件补丁](../../../candidates/s04-carrier-usage/carrier-usage.patch)、[完整状态/坐标契约](../../air_operations/S04-carrier-usage-contract.md)、[原图资料卡](../../references/aircraft/f6f5_1944/carrier-usage/modeling-brief.md)。无 Git 恢复点，三份原准入文件的精确副本和哈希保留在候选 baseline 目录。

## 改动与边界

- F6F 提供放轮、放钩、0..40°尾钩接触上偏、0..50°襟翼；carrier_ops 缺省为清洁飞行。四片襟翼沿本片后掠铰链转动，内片边界去除伸入机身的旧活动面。共享 builder 的轮高/轮盖修正仅 F6F 显式启用，A6M 保留准入行为。
- 简化短尾轮和前移主轮按真实圆胎接点解出约9.65°头仰。固定 model_root.y=−2.30m、原机身/主翼/尾翼/机罩网格、名义机长/翼展、六炮口和DM锚点保持。没有用移整机、缩模型或假收襟翼补甲板。
- 新 CPU helper `scripts/aircraft_geometry/f6f5_carrier_geometry.gd` 无渲染/Node依赖，提供轮胎圆周支承、自由/约束钩、静态承载变换、桨盘代理。渲染查询仅作一致性诊断，模拟按真实DM排除失去宿主的部件。
- 轮/襟翼/尾钩随各自翼/尾DM宿主脱离，静态批处理保留独立活动边界。模型不拥有命令、运动、触舰、抓索或部署计时；未修改 OPS、AircraftMotion、性能表、战损机制、CV01、S14 或普通场景。

## 最终验证

固定 Godot `4.7.2.stable.official.ed1daf0bf`、Compatibility。独立 `.local/s04-carrier-usage/r10` 的523份输入在验证后逐一hash一致。

| 检查 | 通过数 | 证据 |
| --- | --- | --- |
| 原机身/翼/尾/机罩实际网格数组与安装保持 | 17 | [airframe-preservation](../evidence/S04-carrier-usage/r10/headless/airframe-preservation.json) |
| 使用状态、六枪、CPU/Marker一致、隔离、DM宿主/重置 | 56 | [model](../evidence/S04-carrier-usage/r10/headless/model.json) |
| CV01完整姿态、三胎承载、桨盘/35°和50°襟翼净空、尾钩约束/升降面 | 31 | [deck](../evidence/S04-carrier-usage/r10/headless/deck.json) |
| 原F6F/A6M损伤模型回归 | 41 | [models](../evidence/S04-carrier-usage/r10/headless/regressions/models.json) |
| 原真实弹药/飞行终端损伤机制回归 | 90 | [mechanisms](../evidence/S04-carrier-usage/r10/headless/regressions/mechanisms.json) |

共235项、0失败。实际CV01顶面上的完整转动桨盘净空.237296m；35°襟翼最小.255595m，50°最小.109420m。可见20段轮胎相对理想圆周支承的离散误差主轮4.52mm/尾轮1.54mm。

原生12张均已实际打开：[停放侧](../evidence/S04-carrier-usage/r10/native/parked_side.png)、[前](../evidence/S04-carrier-usage/r10/native/parked_front.png)、[斜前](../evidence/S04-carrier-usage/r10/native/parked_front_quarter.png)、[后](../evidence/S04-carrier-usage/r10/native/parked_rear.png)；[进近侧](../evidence/S04-carrier-usage/r10/native/approach_side.png)、[斜后](../evidence/S04-carrier-usage/r10/native/approach_quarter.png)；[自由飞行](../evidence/S04-carrier-usage/r10/native/clean_quarter.png)、[腹视](../evidence/S04-carrier-usage/r10/native/clean_underside.png)；[约束钩侧](../evidence/S04-carrier-usage/r10/native/hook_contact_side.png)、[钩根/鞋底](../evidence/S04-carrier-usage/r10/native/hook_contact_detail.png)；[真实断翼](../evidence/S04-carrier-usage/r10/native/damage_wing_left.png)、[真实解体](../evidence/S04-carrier-usage/r10/native/damage_structure.png)。[capture.json](../evidence/S04-carrier-usage/r10/native/capture.json)保留实际状态、相机、可见三角面包络、净空、原OPS旧快照对照。相机裁剪已收为.5..2000m。

进近/停放/钩接触是明确标注的静态几何夹具；清洁姿态保留实际OPS mission快照，损伤结果来自现有弹药机制。未伪造起降执行视频。没有重复训练、Chrome或长时检查，也未启动HTTP服务。

最终导入/五组测试/原生/补丁与清理分别见验证run：`20261111T103711-3684cb58`、`20261111T103757-7a528408`、`20261111T103828-4abcabfc`、`20261111T111148-cfb90c9d`，完整日志复制于证据 validation-runs。补丁在基线私有副本 dry-run及实际应用均成功，四份输出hash与已测候选一致；临时目录自动删除。

## 历史退回与清理

旧r1–r4长尾轮/共面轮点及旧OPS承载姿态撤回；r5–r9只作迭代证据。r1类型错误、r2鞋底检查基准错误、r6轮盖23.44mm悬空、r9内片仍下探8.1mm的失败日志保留。r8虽227项测试通过，其原生实际三角面数据显示35°襟翼下探214.9mm，判为未通过；r10补齐放角净空检查并修正，无重写旧记录。

[清理审计](../evidence/S04-carrier-usage/r10/cleanup-audit.json)核对本任务此前28次已完成验证和67个子进程组全部消失；最后审计进程自身也由verify外层报告确认退出/清理。仅检查本任务PID/进程组，不关闭用户或其他聊天资源。11份本轮原始参考文件hash校验通过，研究图不进入运行资产。

## OPS 接续

按最终manifest的四文件hash消费纯几何helper；实际钩端替换旧4.4m临时偏移，不再使用r1–r4固定轮底点或旧pitch=0停放。按母舰实际法向重求轮圆支承，独立求两轮到三轮承载及自由钩→甲板约束上偏；静态约29.95°接触值不是运行时常数。单帧可见AABB不是全桨盘/全机碰撞体。

轮、钩、襟翼尺寸均为原图约束的简化工程近似，缺原厂尺寸公差/完整机构测绘。后续OPS真实起降/拦阻及15fps关键短段、S14/S08/Chrome集成须分别验收，不影响已交付普通19单位入口。
