# 资源与资产状态

## 当前 Showcase 准入（统筹更新，2026-11-11）

S01–S07 已按各自范围独立验收，以下六型已用于4舰8机原生观战场景；S09/S10现已扩展为群岛与三座真实ground炮组，S13云海和S02甲板修改也已复核。FX/DM最新表现与S14全单位展示仍在接续，最终Chrome与普通启动待S08，不等于全规模V1通过。详细历史精度／简化范围以各资料包和验收记录为准。

| 正式型号 | 纯模型入口 | 已通过证据 |
| --- | --- | --- |
| 大和 1944-04 | `scenes/ships/yamato_1944_04.tscn` | [S02验收](showcase/acceptance/S02-review.md)；3座三联460mm、2座三联155mm，独立历史／游戏AA清单 |
| 衣阿华 BB-61 1944-12-28 | `scenes/ships/iowa_bb61_1944_12_28.tscn` | [S02验收](showcase/acceptance/S02-review.md)；3座三联406mm、10座双联127mm，根资源适配已完成 |
| 弗莱彻 DD-445 1942-07-18 | `scenes/ships/fletcher_dd445/fletcher_dd445.tscn` | [S03验收](showcase/acceptance/S03-review.md)；5座单联127mm，鱼雷装置仅外观 |
| 雪风 1942-06-04 | `scenes/ships/yukikaze/yukikaze.tscn` | [S03验收](showcase/acceptance/S03-review.md)；早期3座双联127mm，鱼雷装置仅外观；日期重建与测量缺口保留 |
| A6M5a 1944 | `scenes/units/aircraft/a6m5a_flight.tscn` | [S04验收](showcase/acceptance/S04-review.md)；两挺7.7mm＋两门20mm，收轮纯飞行模型 |
| F6F-5 1944 | `scenes/units/aircraft/f6f5_flight.tscn` | [S04验收](showcase/acceptance/S04-review.md)；六挺.50，收轮纯飞行模型 |

六型统一战斗、实际炮位、弹药与代理见 [S05验收](showcase/acceptance/S05-review.md) 和[战斗契约](combat-contracts.md)。飞机新原点与正式安装接口见[航空契约](aircraft-contracts.md)。根默认入口仍是旧大和展示；新入口为 `showcase/first_playable.tscn`，已接入真实舰队/航空/战斗、电影相机与双方指挥界面，见[S07验收](showcase/acceptance/S07-review.md)。旧飞机查看器和机场入口保留。SB2C、机场航空作业及其他独立武器不因本轮验收自动通过。

## 2026-11-11 新增准入与待办

- 已通过S10模型/安装/机制与原生复核：`scenes/ground/us_5in51_mk13mod4_1945.tscn` 和 `scenes/ground/us_40mm_m1_m2a1_1944.tscn`，见[S10](showcase/acceptance/S10-review.md)。
- 健康F6F/A6M的S04 v3飞行已有独立复核；DM01的发动机/翼尾毁伤、有限解体机制阶段冻结，最终连续画面/Chrome待验，见[DM01](showcase/deliveries/DM01.md)。
- SB2C第三轮后的修订已存在，但尚无该版本实测；不能拿旧截图代替。已安排[当前模型准入任务](showcase/briefs/SB2C-showcase-admission.md)，S14需纳入此机，不把它误作尚未建模。
- [S14全单位展示](showcase/briefs/S14-showcase-scene.md)已创建独立Sol6.1 max聊天；覆盖清单、出场段落与观看入口由该任务发布，原六型限制不再用于排除已建资产。独立武器模块与完整单位分开登记，未造的航母/轰炸机不计入当前覆盖。

## S01 初始盘点存档

盘点日期：2026-11-10。范围为首个 Showcase 的六型模型；S01 只读检查和数据提取，不进行造型、原生画面或浏览器验收。S02 等聊天正在修改其专属资源，下表是 S01 初始恢复点及已读源码的状态，不覆盖后续交付。

## 工程与资源根

| 资源根／入口 | 实际情况与接入限制 |
| --- | --- |
| 根 `project.godot` → `res://scenes/main.tscn` | 大和展示，脚本 `scripts/main.gd`，几何 builder `scripts/ship_geometry.gd`；包含环境／相机／UI，不能直接当纯单位模拟节点。默认入口本轮未改。Compatibility，1440×900。 |
| `aircraft/` | 根工程内的资源目录，没有独立 project.godot；`aircraft/scenes/aircraft_viewer.tscn` 为查看器，两型机各有独立场景；共享 `aircraft/scripts/aircraft_builder.gd`。 |
| `iowa/project.godot` | 独立资源根，默认 `res://scenes/iowa_viewer.tscn`，纯舰组件 `res://scenes/iowa_bb61.tscn`；从根工程直接加载时其 `res://scenes/…`、`res://data/…` 等路径需要 S02 明确适配。Compatibility，1600×1000。 |
| `island_airfield/project.godot` | 独立资源根，默认 `res://scenes/woleai_1944.tscn`；相对软链接 `aircraft → ../aircraft`、`assets → ../assets` 已实查；不是第三份资源副本。Compatibility，1600×1000。 |
| `showcase/showcase.tscn` | 旧联调入口，`showcase.gd` 混合节点、模拟、镜头和显示池；保留原状，不视为本轮统一集成。 |
| 根 `assets/`／`data/`／`scripts/naval/` | 含共用炮架、机枪、字体、材质和参数；独立武器样件与衣阿华内资源尚未统一。M2HB／M1917A1 地面／舰用样件不等于航空 AN/M2。来源记录在 `assets/SOURCES.md` 和各武器目录。 |

本目录无 `.git`，`git rev-parse --show-toplevel` 实际退出 128。已建立 `.local/snapshots/S01-before-20261110/project.tar.gz`，699 个文件、两个软链接，压缩后 70,846,059 字节，SHA-256 `491d3994dd521fea7b4ea685a73955f0b730346ac175cf7d7116897fbaa78a54`；逐文件归档回读通过。忽略 `.local/`，该目录有 `.gdignore` 防止 Godot 扫描备份。具体恢复说明见 [validation.md](validation.md)。

## 六型模型

| 型号／配置 | 实际资源与已知接口 | 真实状态／缺项 |
| --- | --- | --- |
| 大和，1944 年 4 月 | `scenes/main.tscn`、`scripts/ship_geometry.gd`；`data/yamato_1944_mounts.json`；`WeaponMount` 有独立 train/elevation、瞄准和障碍 guard；原始清单 3×三联 46 cm、2×三联 15.5 cm，另有 AA | 已有样件。固定炮位 x/z 来自图像换算，绝对高度和部分承载仍有估值；最新舰体／上层建筑及逐座编制验收未通过。S01 提取固定主副炮数据与炮口公式；非历史核准。S02 负责新版接口和造型。 |
| 衣阿华 BB-61，1944-12-28 | `iowa/scenes/iowa_bb61.tscn`、`iowa/scripts/iowa_ship.gd`；模块化炮塔／底座，`get_weapon_mounts`／`get_mount_by_id`；3×三联 16-inch、10×双联 5-inch；主炮逐管俯仰 | 已有独立样件。`december_1944.json` 明写炮位估值；旧 README 与当前测试的轻 AA 数量有差异（旧文档 52 座 20mm，当前测试 26），需 S02 逐座厘清。根资源适配、碰撞代理及本轮外形验收未完成。 |
| 弗莱彻 DD-445 | 初始恢复点没有同名模型／场景；仅规划条目 | 未建模。舰名已选，日期／舰桥型式仍需 S03 锁定并制作，不由其他舰体代替。 |
| 阳炎级代表舰 | 初始恢复点没有模型／场景；仅规划条目 | 未建模。具体舰名和日期待 S03 确定；主炮／鱼雷与外形待资料包和模型。 |
| A6M5a 五二型甲，1944 | `aircraft/scenes/a6m5_52ko.tscn`、`aircraft/models/a6m5_52ko.gd`；共享 builder；现有起落架／操纵面演示；机鼻 7.7mm 与翼炮几何 | 已有样件。旧文档记录轮廓改进与估值，未按本次标准验收；普通 A6M5 保存机来源不可直接证明甲型差异。正式飞行原点、结构化炮口、碰撞代理和新运动接口交 S04。S01 尚未新增该型定义。 |
| F6F-5，1944–45 子型（非某架指定序列号） | `aircraft/scenes/f6f5.tscn`、`aircraft/models/f6f5.gd`；规格 10.236m 长、13.056m 翼展、3.990m 机体高；六个 Browning muzzle 几何中心 | 已有样件，未通过本次外形／使用场景验收。展示原点在放下轮子的姿态，螺旋桨使外包高度与规格高不同；S04 必须定义飞行原点适配。S01 抽取六炮口与规格／400发每枪，弹道／周期仍 provisional。 |

军舰的主副炮数量、炮型、每座管数、位置是固定验收项；专用 AA 的历史清单和游戏清单必须独立。S01 新大和定义只纳入五座固定主副炮，游戏 AA 数量为 0（尚未接入）；这不能解释为历史上无 AA，也不能把模型上全部可见炮位自动算作可开火。

SB2C-4、机场和独立武器仍存在；SB2C 最新监督验收未通过，均不作为这次六型 Showcase 完成依据。旧截图和 AI 目标图没有在 S01 重新视觉验收。

## 导出、版本与现有测试

引擎实查输出 `4.7.2.stable.official.ed1daf0bf`。本地模板目录 `/Users/infinity/Library/Application Support/Godot/export_templates/4.7.2.stable/` 中 `version.txt` 是 `4.7.2.stable`，存在 no-threads debug/release Web ZIP（10,232,720／10,245,903 字节），实际打开压缩目录可见 godot.js、godot.wasm、HTML、音频 worklet 等。S01 没有重装模板、没有导出 Web，也没有据目录名宣称浏览器通过；正式导出仍须通过真实构建确认资源打包。

- 根与衣阿华已有 Web 预设，关闭线程／extensions，输出 `build/web/index.html`；根 include_filter 当前是 `data/*.json`，新嵌套 `data/units/` 与 `data/ammunition/` 的打包尚未验证。S07/S08 应检查并更新；S01 不改导出／默认入口。
- 机场 Web 预设有自身排除表（含 F6F 等），不能直接拿作新统一场景预设。
- 原工具 `tools/check_project.py` 有超时和诊断检查，但没有跨聊天锁及进程组清理；旧 `preview_web.sh`、模板抓取脚本未启动。后续统一用 `tools/verify.py`。
- 初始根测试有 weapon_motion、hull_geometry、mesh_batching 和 guarded_motion／aa_shield／weapon_clearance 审计；衣阿华有 test_mount_assembly。部分审计会写 docs 中的 JSON，执行前检查输出归属。
- S01 实跑旧 weapon_motion，遇到 `TrainPivot_main_01` 字典 key 错误；旧 mesh_batching 调用不存在的 armored_housing。恢复快照中的旧测试与 builder 已有同样不一致：builder 当时已命名 TrainPivot，且没有 armored_housing 方法；不能归因于 S02 本轮修改。包装器均返回失败并回收，未把它们算通过。统筹已将旧模型／测试兼容交 S02 核对，不由 S01 越权修复；最终状态以后续 S02 交付为准。
- 独立现有 `scripts/naval/audit_usn_bofors_40mm_quad.gd` 在包装器中通过，真实验证安装标记、四管分组、限位和两实例独立运动；没有加载整舰或创建渲染窗口。

新纯状态机制检查与实际日志见 [S01 交付](showcase/deliveries/S01.md)。没有原生画面、Safari／Chrome 性能或六型资产正式准入结论。
