# G4M1 一一型 / AV03

**1942-07，火星11型双发、三叶桨、原式机鼻/侧水泡/尾罩战斗构型**。1:1米制，+X右/+Y上/−Z前。根原点固定在机体几何基准，不是地面或已测重心；飞行宿主平移为零，不沿用SB2C的−2.38m偏移。纯模型[g4m1.tscn](g4m1.tscn)，独立检视[inspection.tscn](inspection.tscn)。本目录不依赖共享AircraftBuilder/Adapter，不注册单位，不改普通入口。

`apply_visual_state(Dictionary)`立即消费快照；宿主自行插值/推进相位。模型无_process、计时器、飞行、射击、投放、扣弹或随机受损。数值仅接收有限int/float；比例夹0–1，未给项保持；布尔与载荷枚举检查类型，不把错误输入变成动作。

| 字段/方法 | 行为 |
| --- | --- |
| `propeller_left_rad`, `propeller_right_rad` | 两桨独立相位，绕各自+Z；宿主决定转速和失效后停止 |
| `gear` | 0收、1放；两主轮沿本机简化+X轴向后收至−75°；尾轮简化+X轴前收100°。末端隐藏组、主舱盖切换；不表现精密轮舱/传动，尾轮机构仍待厂图核实 |
| `flap` | 0–35°，两翼分别为独立宿主；只是外观角，不是经过风洞标定的气动量 |
| `aileron_left_rad`, `aileron_right_rad` | 各自局部+X，±0.35rad，宿主决定符号 |
| `elevator_left_rad`, `elevator_right_rad`, `rudder_rad` | 升降舵+X、方向舵+Y，±0.35rad |
| `dorsal_open` | 简化背部滑罩显隐；关闭时藏背枪。不是G4M2动力炮塔 |
| `guns` | 按`nose/dorsal/waist_left/waist_right/tail`传`{yaw_rad,elevation_rad}`，各自+Y偏转/+X仰俯，限位见下表/JSON |
| `payload_mode` | `bombs_12x60`、`empty_open`、`ferry`三选一；盖板为地面拆装，不是飞行中开合门 |
| `bomb_visible` | 12个bool的数组，独立显隐实际炸弹节点；保持模拟库存归属，不自行发射/生成弹体 |
| `apply_damage_state({id: attached_bool})` | 六个真实部位组显隐；不产残片、不改模拟战果 |
| `set_flight_configuration()` | 仅收轮与襟翼，保持根变换、载荷、炮位、相位和其他控制面 |
| `set_landing_gear_deployed(bool)` | 二值兼容入口，调用同一快照接口 |
| `get_parked_transform()` | 返回轮心/半径推导的6.307°停放变换，Y=2.043078m；不修改自身原点 |

枪位数量/口径已核对为4×7.7mm、尾部1×20mm；武器族识别提案为海军九二式/九九式一号，具体子改型和批次备弹未核实。以下是**表现限位建议，未测绘，不授予实际开火许可**：

| 枪位 | 基准方向 | 相对偏转° | 上仰° |
| --- | --- | --- | --- |
| nose | −Z | ±40 | −35～45 |
| dorsal | +Z | ±180 | 15～80 |
| waist_left | 左外侧略后 | ±35 | −30～50 |
| waist_right | 右外侧略后 | ±35 | −30～50 |
| tail | +Z | ±22 | −20～25 |

每门枪有真实base/yaw/elevation轴和随动枪口Marker，−Z表示该枪口的射出方向。USAAF泛称手动转动360°不等于所有射线可用；宿主必须同时验证罩体状态、目标角、机体/桨盘/翼尾/地形和友军遮挡，不能直接按上述夹限发射。枪架只做必要外部承载，内部机构不复制。

`markers`、`guns`、`propellers`、`surfaces`和`damage_modules`字典可供宿主使用；实际路径、位置、方向、部位包络与来源限制见[Godot导出的接口](data/interfaces.json)。`left_wing/right_wing`各自拥有发动机和该主轮；独立`engine_left/engine_right`仍可单独失效或隐藏。断翼使该侧发动机/轮组随翼离开；单发动机状态不导致整翼消失。尾部含翼尾、舵、尾轮与尾炮。脱落重挂时保留global_transform，碰撞包络只是提案，勿把父/子AABB重复当成独立命中体。

默认12枚60kg级简化炸弹（720kg），两组六枚；四纵列、每列三枚，具体弹种/引信尚未核准。每枚释放点在真实显示弹体中心、尖端朝−Z；BOMB01保存库存并决定释放。`ferry`无弹、装可拆整流盖；鱼雷只有`TORPEDO_RESERVED`参考点，未制作/未合格安装，不能与炸弹混挂。无尾钩、折翼或航母回收。

停放：`Transform3D(Basis(Vector3.UP, heading), surface_station) * model.get_parked_transform()`。主轮中心`(±3.85,−1.98,−4.05)`/半径0.52m，尾轮`(0,−0.96,8.00)`/0.21m；桨半径估计1.70m。MAP02硬地顶面8.04m，用真实查询支承，不移动基准/拉长尾轮制造接地。8停机位、跑道与滑行道已静态检查；16m滑行道每侧翼尖外伸4.44m，不能据此声称动态滑行或机群通行完成。

固定几何按材料与损伤宿主在本机helper合并，活动轴/桨/轮/逐枚载荷保持独立。当前全构型104个MeshInstance、55,884个三角面（原始208网格）；这是源模型预算，非Chrome机群性能。尺寸/性能未注册提案见[proposal.json](data/proposal.json)，不拷贝战斗机飞行参数。模型/证据及缺口见[AV03交付](../../docs/showcase/deliveries/AV03.md)。
