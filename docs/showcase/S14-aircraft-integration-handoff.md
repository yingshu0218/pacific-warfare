# S14 飞机最终接入契约

2026-11-11。原阶段依赖已落实；本页记录当前接口，最终结果见 [S14交付](deliveries/S14.md)，S08启动接续见 [交接卡](S14-S08-handoff.md)。S04训练接口权威为 `docs/aircraft-training-contracts.md` 与 `S04-training-integration-handoff.md`。

## 同一生产模拟与指令

- `AllUnitsShowcase.choose_exercise`显式重载整场，保留上一world的generation后递增；19稳定ID模型复用，效果/相机/HUD随重置清理。
- `ShowcaseMissions.reset/fixed_update`只通过BattleOrder发巡航/交战/护航/重组/撤离和训练，source=human、issuer_id=s14_exercise_director；UI标“演示任务”。不写单位位姿、飞机受损或命中。
- `SB2CShowcaseTasks extends AircraftTasks`继承S04训练路径，无第二个executor；只对SB2C保留导航及no_ammunition豁免，其他油量/损伤退出有效。战斗机依旧用自身参数和生产执行器。
- Session的可选`aircraft_tasks_script`与`combat_overlay_path`仍沿阶段装配，只有SB2C新增碰撞/伤害键，不覆盖旧profile；未重复安装AircraftSuite。

## 实际训练消费

发`order_type=aircraft_training`和`training={maneuver,direction:1}`。五项为bank_turn、climb_dive、axial_roll、roll_reversal、split_s，两型均有菜单。当前训练由`unit.task.aircraft.training`读取，完成保留结果来自`module_data.aircraft_training`。必须匹配当前order_id，并同时检查该单位execution.status和实际training.status才显示完成；旧记录及queued回执无效。安全/拒绝/中止沿原执行器，中文标签由`training_labels.gd`提供。

受控初态离地2400米、速度115米/秒，友机隔离，不缩小原110米安全条件。十项都按真实姿态和轨迹完成；完整轴向滚转峰值超过360°，半滚倒转经真实拉杆/改出。不是为战斗AI添加任意表演动作，原自然尾追规避仍独立保留。

`ShowcaseGuide`固定世界up，只读副本。训练34米单机、护航SB2C38米；四机总览与两对近景交替，超过650米对内距离则跟单机。没有硬绑定编队、镜头旋转冒充滚转或为入镜缩放模型。

## SB2C r2接入

原模型`aircraft/sb2c4/sb2c4.gd`、当前准入r2，+Y上/-Z前；adapter减y=2.38米为飞行参考，非实测重心。`set_showcase_configuration(true)`闭合弹舱/翼面并隐藏展示挂载，landing_gear收起；桨相位/舵面读生产状态。r2原点和clean接口兼容，无模型侧修改。

独立性能和一般碰撞估值未变；只接巡航、编队、集结/撤离和受护航。不接战斗机训练、战斗机追逐、实用武装、投弹、后射手、起降或预切DM。将来扩展由对应任务接入，不回填为S14已完成能力。

## 已验证与保留边界

S14真实四机120次航空发射，双方各1架自然损失，剩余重组；护航真实威胁响应、有限追击后返回保护范围，本种子航空发射0。完整循环和十项训练均有连续原生/视频，实际Chrome验证菜单、真实开始、两型完整滚转/倒转结果和近景；不重复宣称S04/FX/DM内部专项。

F6F/A6M飞控与性能、模型损伤、FX/shader、S13云海及冻结地图不由S14改写。CV01/MAP02不进入本轮19单位包。S08独立验普通启动、10分钟实际活动、三次R、4倍实效与积欠；原DM01的4倍不足仍未解决。
