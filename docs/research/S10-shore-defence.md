# S10 陆基兵器资料与接入准备

2026-11-10。阶段：**独立资料与实施准备**。统筹正在冻结 S04 最终航空证据；本阶段没有运行 Godot、修改共享运行文件或部署单位。总计划、coordination 和统筹验收由统筹维护。当前目录没有 Git 仓库；本轮只新增自己拥有的资料文件，后续改共享代码前须保存局部恢复副本。

## 型号结论

| 对象 | 选定方向与配置日期 | 已落实的依据 | 尚未落实的事项 |
| --- | --- | --- | --- |
| 岸防炮 | **5-inch/51 Gun Mk8 Mod0 ＋ Mount Mk13 Mod4**，按 OP1112 **1945-01-15** 数据页，开放单装柱式炮架、Common Mk15 Mod14 袋装发射药弹药；架空岸置配置 | 实际打开 USMC 1940-10-21 Battery A侧面、Guantanamo岸置正前原照及 OP1112 pp.162–163 原始俯/侧图与数据；炮架/兼容炮身/尺寸/机械极限明确，NARA目录有1940年供USMC的Mk13/Mods4、6记录 | 没有把照片中某一座炮反向认定为Mk8 Mod0。1945是所用技术表页日期，1941威克岛仅证明同家族岸防用途；基础埋深、精确后侧和个体批次仍未测绘 |
| 陆基防空 | **40-mm Automatic Gun M1 (AA) + Carriage M2A1**，按 **TM 9-252，1944-01-17**，展开支腿、落地射击、M3 开放瞄具 | 已实际打开原手册 fig.1、4、89、161：高仰角完整斜前、运输近侧面、落地后侧与瞄具。具体炮架明确，美国陆用单管 | 炮架个别轴高、展开宽度等由图估算；服役年需区分 M1 炮与 M2A1 炮架，不能从手册出版日倒推出初次服役日 |

两型资料卡分别位于 [5-inch/51](../references/weapons/us_5in51_mk13mod4_1945/modeling-brief.md) 和 [M1/M2A1](../references/weapons/us_40mm_m1_m2a1_1944/modeling-brief.md)。参考图与原始来源、已看状态、尺寸置信度分别记录，不把下载成功当作看图完成。

USMC 官方战史说明早期防御营曾把海军 5-inch/51 改作固定岸防；1944 手册独立证明 M1/M2A1 的陆用型式。这是**原创架空驻军的跨年代装备组合**，不是宣称 1941 年威克岛已经装备 M1/M2A1，也不宣称1945年USMC仍以5-inch/51为标准新装岸炮。实际部署拟归 `us`；地图中的 `suggested_faction=jp` 仅为建议，按 S09 契约由场景覆盖。原图中的色彩不明，游戏暂定克制橄榄绿并标注外观近似。[USMC《Condition Red》原文转录](https://www.ibiblio.org/hyperwar/USMC/USMC-C-Defense/index.html)，[TM 9-252 原文](https://legacy.maritime.org/doc/boforstm252/index.php)。

## 已核的尺度和行为边界

- 5-inch = 0.127 m；51 倍径给出 6.477 m 的倍径基准，**不等于含炮尾的整炮总长**。官方战史给出的 50 lb 弹与 3,150 ft/s 初速，换算为 22.6796 kg、960.12 m/s。17,100 yd = 15,636.24 m 是该史料所述射程，不能拿无阻力模型的理论抛物线射程替代。[USMC 原始图注](https://www.gutenberg.org/files/48810/48810-h/48810-h.htm#Page_10)。
- Mk13 Mod4 的原始数据明确机械俯仰 **-10°～20°**、手动操作、15in（0.381m）后坐；转向每手轮圈1°10′44″，俯仰每圈1°12′21″，不是“度/秒”的实测最大转速。约53in（1.3462m）底座纵向尺寸、40.3in（1.02362m）耳轴高、炮口到回转轴约186.25in（4.73075m）与炮尾后伸约75.25in（1.91135m）由原始图版读出，带approx的尺寸保留近似属性。53in是侧投影前24in/后29in，不能擅自当作圆形法兰直径。射程17,100yd对应20°仰角。原页见 [p.162](../references/weapons/us_5in51_mk13mod4_1945/images/op1112_cat0162.jpg)、[p.163](../references/weapons/us_5in51_mk13mod4_1945/images/op1112_cat0163.jpg)。
- M1 炮架轮距/轴距和运输包络来自手册数据；运输状态 5.7277 m 长、1.8288 m 宽、2.0193 m 高，轴距 3.2004 m。**展开阵地宽度不能直接用 1.8288 m**。全炮带附件重约 2,653.52 kg；最大仰角 90°、手动俯角 -6°，连续回转。3,000 yd = 2,743.2 m 是原手册的正常防空有效距离边界。120 发/分是快速连发值，4 发弹夹。[TM 9-252 §2–4](https://legacy.maritime.org/doc/boforstm252/index.php)。
- 首选 M1 1944 手册表 I/II 第 9 类：HE-T (SD, No.12) Mk.II、P.D. M64A1，1.96 lb = 0.8890 kg、2,870 ft/s = 874.776 m/s。为触发碰炸＋曳光燃尽自毁；No.12 曳光约 7–10 秒，不能按每个目标的截击时刻调空爆。该弹药条目中的 No.12 是曳光器身份，不是把英国炮架作为美国 M2A1 的形体依据。[TM 9-252 §109–112](https://legacy.maritime.org/doc/boforstm252/part4a.php)。

其余射速、炮架转速、散布、弹药库存、耐久与毁伤参数在未来数据中各自注明来源或游戏近似。首版有限弹药拟为岸炮 60 发、每座 AA 240 发，是场景携弹量，**不是历史编制或史实弹药库容量**；最终以自然运行/耗尽验收确定，不用无限补给延长表演。

## 安装和场景方案

复用冻结的 `data/maps/island_harbor.json`，不改 S09 地形生成、足印或安装点。拟使用 `harbor_coast_01` 一座岸炮、`harbor_aa_01` 与 `harbor_aa_02` 两座 M1；`ridge_aa_01` 保留空位，避免为高地镜头增加制作范围。`position_m` 是承载面；模型自带真实基座/落地脚，炮口另算。接口见 [地形契约](../terrain-contracts.md)。

| 阵地 | 当前承载面 [x,y,z] m | 装配重点 |
| --- | --- | --- |
| harbor_coast_01 | [-3010,32,-3200]，半径 32 m，yaw=-2.35 | 单装座圈和专属固定基座有来源；新宿主基础只接本型安装面。地图±70°/[-5°,45°]与炮架[-10°,20°]求交，实际[-5°,20°] |
| harbor_aa_01 | [-4930,18,-3540]，半径 24 m | 四个落地脚完整接触；两侧展开支腿、轮组、牵引杆与炮尾后摆保持空间 |
| harbor_aa_02 | [-5150,18,-3250]，半径 22 m | 同一模型第二实例独立回转/俯仰/后坐；AA 的机械90°与阵地85°取交集 |

现有初始空战区离港区 AA 较远。放行后先记录真实自然轨迹对阵地的最小斜距，再在新地图场景数据中调整初态/巡逻区，使敌机穿过 2,743 m 内，合理高度约 700–1,200 m；岸炮则有近海敌舰可见且可反击。拟先测港湾东南外海走廊，不能以坐标直线距离替代地形/建筑 LOS 实验。新增场景预计 4 舰＋8 机＋3 地面单位，共 15 个实体。

`data/scenarios/first_playable.json` 与 `showcase/open_sea.tscn` 保留原四舰八机基线。正式场景布局修改只落在新地图场景数据；默认入口是否选择新的 `island_harbor_defence.json`，在共享接入放行后与统筹确认文件所有权即可，不需要用户再次批准已授权的 S10 实施。

## 模块计划

固定宿主、炮架回转部、俯仰摇架/炮管分离；米制、+Y 上、-Z 零位射向。地面模型不包含相机、AI 或战斗判定。继承现有模型适配与 VisualRecoil 所需公开接口，先逐型做可重复生成器，再做场景装配。

```text
GroundUnitRoot（承载面与回转轴交点）
├── Foundation / M2A1Chassis（固定，含本型真实承载）
└── TrainPivot（座圈/上炮架、手轮、座位）
    └── ElevationPivot（耳轴明确偏移）
        ├── CradleAndBreech
        ├── RecoilBarrel
        └── Muzzle_0（真实炮口，朝 -Z）
```

M2A1 支腿、落地脚、轮和牵引杆均属于固定底盘，不随瞄准旋转；座位随上炮架回转而不随炮管仰起。M3 瞄具横杆与其支架按原图连接，不添加舰用四联炮盾。岸炮按OP1112低矮底座与法兰安装，岸置专属承载基础取明确标注的原创表面基座；不复刻未知地下锚固或借通用圆柱加高。AI 风格图按 S10 执行卡为可选，本轮未生成；后续若使用只约束 `simplified-historical-v0.2` 色面与材质，不能补历史未知几何。

## ground 接入草案

以下是待实施契约，不是已经存在的运行能力。

1. `domain="ground"`：单位与武器仍由现有 catalog、UnitState 和 WeaponState 表达；位置固定，速度为零，无 ship_motion/aircraft_motion、燃油、进水、沉没或坠机。定义保留国家、服役年和配置日期。
2. 场景 `ground_deployments`：稳定 entity id、site_id、definition_id、faction_id。在 configure 前从静态安装点解析成正式 spawns，并校验id、角色、阵营；terrain 安装后、首tick前由 GroundSuite 用同源 TerrainQueries 校验足印/坡度、安全半径、朝向和实际炮口。错误返回具名错误，不以移动/抬高模型自动补救。重开仍用相同解析初态。
3. `GroundTasks` 注册 ground 域的 `patrol` 与 `engage`。`patrol` 的陆基语义是守备指定区域的海面/防空警戒；`engage` 对可见且本型能打的明确目标。移动型 regroup/retreat/intercept/escort 拒绝并说明固定阵地能力。实际 `task.ground` 保存任务阶段、fire/allow_aa 意图、目标、受限原因、库存和武器可用数。取消/改派清意图并经 SET_TARGET 清目标。
4. 程序指挥的陆基计划只读己方 commander_snapshot，尊重人类来源任务和在执行归属；经同一 submit_order 下令。海面岸炮只打 ship；M1 本轮只打 aircraft。舰队在实际 fresh 的 ground 接触上可选择岸炮，舰上获准对地的火炮通过配置明确加入 ground 目标域，仍受射程、火控、弹道/地形和库存约束。
5. 探测沿现有扫描/己方接触，岸炮视力/测距近似明确标记，不能默认有舰载雷达。小型炮位目标点和 sensor_height 须真正露出地面，不能以地形根点瞄准导致炮弹全撞台地下方。
6. 损伤沿 CombatDamage；ground 分支的 operational → disabled / wreck，原位保留残骸和代理，摧毁/武器失效后停火。炮架失效与整体摧毁分别记录；按已有残骸寿命回收。没有凭空垂直位移或燃油消耗。
7. 正常现有 UI 增加真实驻军命令/执行，选炮位可定位。详情显示固定阵地、弹药、武器/结构与火情；战报独列 ground 可战/失能/摧毁。至少一条真实驻军命令可在正常界面看到，不能被现有每方4卡截断；具体用现有面板的滚动或紧凑受令列表实现，保留双方可读。事件跟随/地图符号按 ground 语义，不把它算飞机或写舰队跟随。S12 现代 HUD 与 S11 音频生产仍为独立后续工作。

## 已读代码对应的拟改文件

资料阶段只允许前四行；其余在统筹释放共享集成后实施，具体文件以必要改动为限。

| 类别 | 路径 | 目的 |
| --- | --- | --- |
| 新增，当前 | `docs/research/S10-shore-defence.md` | 本资料与文件/实验计划 |
| 新增，当前 | `docs/references/weapons/us_5in51_mk13mod4_1945/{modeling-brief.md,sources.json,images/}` | 岸炮身份、原图与未知项 |
| 新增，当前 | `docs/references/weapons/us_40mm_m1_m2a1_1944/{modeling-brief.md,sources.json,images/}` | 美国 M1/M2A1 完整原图和参数 |
| 新增，当前 | `docs/showcase/deliveries/S10.md`、`docs/showcase/evidence/S10/research-audit.json` | 阶段状态和本轮实际证据/清理；不标实施通过 |
| 新增，待放行 | `scripts/ground/models/`、`scenes/ground/`、`assets/ground/` | 两型模块与宿主装配，资源/来源说明 |
| 新增，待放行 | `scripts/behaviors/ground/`、`data/ground/showcase.json` | 部署解析、ground任务与程序指挥提案 |
| 新增，待放行 | `data/units/us_5in51_mk13mod4_1945.json`、`data/units/us_40mm_m1_m2a1_1944.json`、对应 `data/units/weapons/`、`data/ammunition/` | 两型历史/场景参数；不改舰用四联 Bofors 定义 |
| 新增，待放行 | `data/scenarios/island_harbor_defence.json` | 港湾驻军和有限射程交战布局 |
| 必要共享改动 | `scripts/simulation/state/definition_catalog.gd` | 现有只允许 ship/aircraft；扩展 ground 校验及反例 |
| 必要共享改动 | `scripts/game/first_playable_session.gd`、`scripts/game/first_playable.gd` | 安装、模型适配、真实 task.ground、发射类别、ground战报和终局 |
| 必要共享改动 | `scripts/simulation/weapons/combat_config.gd`、`scripts/simulation/collision/combat_frame.gd`、`scripts/simulation/damage/combat_damage.gd`、`scripts/simulation/projectiles/combat_projectiles.gd`、`data/combat/showcase.json` | ground代理、武器域/炮口火线、原位损伤、M1碰炸/固定自毁边界；默认旧参数保持 |
| 必要共享改动 | `scripts/command/commander/fleet_planner.gd`、`scripts/behaviors/fleet_formations/fleet_tasks.gd` | 舰艇根据实际情报选择/炮击 ground；不改 S04 航空机动 |
| 必要共享改动 | `ui/observer_hud.gd`、`ui/observer_text.gd`、`ui/observer_map.gd`、`scripts/presentation/cameras/observer_camera.gd` | 现有信息布局里加入 ground详情、计数、任务/镜头语义 |
| 新增/必要回归 | `tests/test_ground_*.gd`、`tests/ground_capture.gd`，现有机制测试 | meaningful域扩展、真实安装与实战证据 |
| 交付后更新 | `docs/ground-contracts.md`、`docs/showcase/deliveries/S10.md` | 最终实际契约、命令、来源、限制与 hash |

`CombatContacts` 已从定义读取目标 domain，可直接建立 ground 接触；仍须查目标点与地形遮挡。`CombatTargeting` 的普通指定目标分支已按武器 domains 过滤，AA分支明确只选 aircraft；不需要另写一套索敌。`CombatFrame` 有默认舰炮大小的武器代理，地面两型必须各给真实代理尺寸。`CombatDamage._disable` 当前将非 ship 进入 crashing，这是必须修复的域二分，不能靠设置零速度规避。

## 放行后的实验顺序

| 顺序 | 实际证据与失败条件 |
| --- | --- |
| 1 单型模块 | 从同一个 Godot 场景输出侧、前、俯、斜视，逐张与原图比；量座圈/落地脚/耳轴/炮口，无悬空、错连、反向。先完成岸炮再 M1，保留候选未知项 |
| 2 同图装配 | 1岸炮＋2AA，部署解析拒绝角色/坡度/半径/海面/重复 id 错误；全射界姿态检查炮口/炮尾和宿主；同素材两实例姿态不同 |
| 3 受控机制 | 真实 ground接受/拒绝/取消/改派与human同入口；己方探测/失联；转向未到位、射界、建筑/山体遮挡、弹丸首次命中；每发库存守恒、耗尽停火；disabled/wreck原位停火且代理仍阻挡 |
| 4 自主默认布局 | 不操作单位，记录岸炮对舰、两座AA对空、舰艇对岸首次实际 fired/hit/damaged 的实体/武器/目标、仿真时刻；不能只证明有命令或炮架会动。记录轨迹最近距离与 LOS、未出现交战则调整场景布局再测 |
| 5 确定性/恢复 | 相同种子和命令、不同 advance节奏、表现开关得到相同仿真；三次重开清理任务/弹药/损伤/引用；旧四舰八机、contacts、weapons、projectiles、damage、commander/UI与地形有意义回归 |
| 6 原生交付 | 当前真实场景连续画面、双方命令与炮位详情、模块/装配图、单位/弹丸峰值、绘制对照、源码起止hash；每轮有限超时并清理本轮资源 |
| 7 统筹/S08 | 统筹复核后，由 S08 基于最终新地图＋最终 S04＋S10统一重建，只用 Chrome 做声音、性能、10分钟与三次重开；本轮资料和原生证据不冒充浏览器通过 |

引擎/原生/视频编码/浏览器验证全部走 `tools/verify.py` 同一锁；资料阶段只进行文件读取、公开资料下载和看图。未购买、上传或提取游戏资产。
