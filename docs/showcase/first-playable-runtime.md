# S07 观战入口与读模型契约

2026-11-10，S07原生范围已统筹验收。供S08构建与后续观战扩展使用；不替代runtime/combat/aircraft/fleet四份模拟契约。

## 入口与所有权

`res://showcase/first_playable.tscn`根为FirstPlayableGame；初态位于`data/scenarios/first_playable.json`，由正式catalog读取六型model_scene。安装AircraftSuite、CombatSuite和FleetSuite，场景不实现第二份运动、指挥、武器或伤害。用户与AI高层指令仍沿BattleOrder／BattleCommand入口，UI不从SET_TARGET生成指挥台词。

根默认入口仍为大和，旧Showcase和模型查看器保留。原生运行须显式传新场景。Web导出主入口安排由统筹／S08在构建副本或最终配置中明确，不能把默认大和Web加载计为新Showcase验收。固定Godot4.7.2与匹配模板，Compatibility；所有引擎调用经tools/verify.py单锁、超时、清理。

## 时钟、事件与缓存

- FirstPlayableSession持有SimulationWorld，普通帧只调用advance(delta,16)，不删除积欠。UI显示实际暂停／倍速和落后时间；暂停不向模拟积累墙钟时间。
- 每帧只从world.drain_events读取一次，分发给统计、相机、VisualRecoil与CombatEffects；特效预算和镜头不能改变事件、库存或world.rng。
- 单位通过UnitState.snapshot形成一份复制读模型，定义domain与mount_id→role按型号缓存；orders_snapshot每30仿真tick读取，重置／终结可立即刷新。完整world.snapshot只用于审计／回归，不在表现热路径使用。
- units字典属于Session的缓存复制状态，消费者只读。清理自己的引用时重新赋值，不能clear共享的读模型字典。模型／相机不获得可变UnitState或SimulationWorld引用。
- restart调用world.reset并清Session历史，world.generation增加；UI指令／目标选择、相机候选与摄影缓存、特效游标／池、炮管偏移复位。模型节点按稳定ID复用，避免生成重复实例。

## 摄影与表现

ObserverCamera只接收单位复制视图、静态尺寸／主炮安装朝向和BattleEvent。初始跟拍10秒，事件镜头最短9秒，普通镜头14秒；额外切换冷却有效。真实近距任务距离／阶段，以及主炮库存、装填、可用状态、实际转向对准程度，可令镜头提前跟拍。齐射跟拍允许有限等待实际落弹；没有定时战果、预设飞行轨道或预测命中显示。

自动镜头使用主炮跟拍这一持续标签，不把旧salvo当当前闪焰。水柱1.8秒、空爆0.9秒后分别称落弹海域／防空空域。手动右拖接管保持同一按键手势，松键／按钮切模式／重开清拖动状态。单位退出后回退到最后位置，可恢复自动。

VisualRecoil仅根据实际fired移动现有炮管网格，按仿真时间后坐／复位；安装轴、炮口Marker与纯数据弹道不变。CombatEffects消费S05正式锚点与CombatPresence；正常离场不再形成持续火烟或发动机源，仍在战区的失能／沉没／残骸依S05 phase保留。S07按damage.list_rad显示舰体倾斜，S05负责真实沉没位移。

## UI与战报

正常界面保留双方并行指挥卡，展开指挥态势显示实际issued／received／executing及终态、逐成员改派和原因。阶段／原因映射为中文，时间用仿真分秒；观众可见双方，指挥官的情报来源不变。点击命令定位受令成员或目标，结束对象保留最后相关位置。

速度、默认选中单位和暂停标签在重开后同步实际world状态。声音默认关闭，必须用户点击启用。中文使用随包Noto Sans CJK SC及OFL许可；Web预设包含递归JSON及字体许可。

战报从实际事件和状态记账：sinking／crashing与浮水disabled分别统计；unit_impact.destroyed区分坠毁和软迫降；ship_exit／aircraft_exit分别认定真实驶离／飞离，不按inactive或structure单项猜测。弹药与燃油来自各实例实际计数。自然结束包括一方失去可战兵力、任务全部结束、长期脱离或15分钟展示上限，另可手动结束，均不摧毁残存单位。

## 审计与复验

完整命令见[交付记录](deliveries/S07.md)。first_playable_run.gd记录实际战果、执行阶段及automatic_camera_shots／visible_events；后者要求实际发射对象在当前跟随和视锥内，空爆／落弹需仍在效果寿命内。first_playable_auto_capture.gd运行正式场景及相同自动相机，只收起信息UI，不调用follow／locate或改相机位姿，按真实事件截三类原生图并写源码SHA256。

当前种子707在240.383秒自然结束，不是10分钟长跑。浏览器 Chrome（用户最新要求仅测试 Chrome）、M5／16GB持续测量、真实播放速度和10分钟多轮验证均属S08，不为延长镜头修改装备、伤害或强制保活。S07正常／失败记录和清理结果分别索引到交付与cleanup_audit.json。
