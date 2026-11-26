# D4Y2 一二型：AV02 独立纯模型

1944-10生产构型，1:1米制，+X右、+Y上、−Z前，原点固定在机体展示基准而非地面或已测重心。入口[d4y2.tscn](d4y2.tscn)，独立检视[inspection.tscn](inspection.tscn)。本目录不注册单位，不依赖/修改共享AircraftBuilder或AircraftAdapter。翔鹤1941与本机1944的组合明确为跨年架空。

状态由宿主传入，不存在自动计时/飞行/射击/投弹/随机损伤。`apply_visual_state(Dictionary)`每次立即应用快照，宿主按自己的时钟插值。数字非有限值拒绝，比例夹到0–1；未给的主状态保留。`rear_yaw_rad`与`rear_elevation_rad`是本次指向值，未给时回到居中/35°，不应当作可验证真实射界。

| 字段/接口 | 行为与所有权 |
| --- | --- |
| `gear` | 0收、1放；两个主轮向内转、尾轮前收；末端整组隐藏和简化闭合盖。不实现轮舱/液压机构 |
| `hook` | 0隐于机腹、1放下24°；真实子节点钩端Marker跟随；不模拟拦阻索 |
| `flap` | 0–40°及0–0.12m后移，简化Fowler外观 |
| `brake` | 每翼3块翼下窄板，0–70°；`flap>0.001`时回收，避免两装置占同通道 |
| `bay` / `crutch` | 两扇曲面舱门0–95°；摆架0–34°，幅度不得超过bay；内部真实孔、承载杆、炸弹中心/释放点跟随轴 |
| `bomb_visible` | 只控制一枚250kg简化外观；闭舱时不画内部炸弹。模拟必须自己保存库存、决定释放并创建运动弹体 |
| `rear_gun` | 打开简化后罩、显单挺一式7.92mm（MG15）及支架；没有自动火控 |
| `rear_yaw_rad`, `rear_elevation_rad` | 展示夹限±40°、上仰20–70°；不是历史实测射界，不取代尾翼/机翼自遮挡校验 |
| `propeller_rad` | 宿主桨相位；发动机失效时宿主停止/减缓相位，不由模型制造失效 |
| `aileron_left_wing_rad`, `aileron_right_wing_rad` | 各自+X轴，±0.35rad，宿主自行决定左右符号 |
| `elevator_left_rad`, `elevator_right_rad`, `rudder_rad` | 升降舵+X、方向舵+Y，各±0.35rad |
| `set_flight_configuration()` | 收轮、钩、襟翼、减速板、弹舱与摆架，闭后罩；保留根姿态、桨相位与普通操纵面角度 |
| `set_landing_gear_deployed(bool)`, `set_arrestor_hook_deployed(bool)` | 二值兼容入口，转到相同快照接口 |
| `get_parked_transform()` | 从真实轮心/半径计算10.791°尾低姿态与Y=1.240352m；只返回变换，不改模型原点 |
| `apply_damage_state({part_id: attached_bool})` | 5组独立显隐。损伤/脱落/残片运动归DM；没有随机脱落或复制残片 |

`damage_modules`是真实独立节点字典，`markers`是真实Marker3D字典，`surfaces`是实际轴节点字典，`propeller`是可转桨节点。数据建议[data/proposal.json](data/proposal.json)和由Godot实际导出的[data/interfaces.json](data/interfaces.json)包含路径、方向、模块包络/碰撞建议。marker方向按−Z读取，后枪marker局部姿态已使−Z指向枪口前方（整机后上）。模块根为identity、几何用共同机体坐标，重挂脱落模块时保留变换；预切边界另有marker。破坏一侧翼会连同该翼主轮/副翼/襟翼/减速板一起离开，不会遗留活动零件。

静态宿主应用方式为 `ship.global_transform * Transform3D(Basis.IDENTITY, local_station) * model.get_parked_transform()`。飞行模型原点保持不变，不再次减起落架高度。轮胎接触是旋转后圆面竖直切线，不是把局部最下点直接搬到地面；主轮网格64段相对解析面偏差约0.032mm。**停机不得完全放下投弹摆架**，当前显示炸弹全伸时低于甲板约0.50m，完整摆架只用于空中投放。中/后升降机横向总余量0.50m，仅静态居中通过，不代表滑入、动态占用或容错已验。

保留必要简化：不造折翼；没有发动机内部、细孔、轮舱内传动、精密武器/炸弹复刻；后罩为显隐；轮组收放扫掠为简化外观。机身圆标按统筹授权省略，保留完整翼面日章，非特定战时无圆标涂装考证。轮径/站位、安装轴和枪架幅度均为照片重建。来源、核图和状态见[AV02交付](../../docs/showcase/deliveries/AV02.md)。起降、轰炸、防御火控与连续坠落必须由OPS01/BOMB01/DM及S14后续消费并分别验收。
