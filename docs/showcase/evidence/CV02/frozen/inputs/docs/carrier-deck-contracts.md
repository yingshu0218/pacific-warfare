# 航母甲板最小契约 v0.1

CV01 发布，2026-11-11。供 CV02 / OPS01 共用字段语义；不注册新单位、不改共享模拟。模型与历史布局仍需统筹验收。Essex 实例数据在 `naval/essex_cv9_1944_04_15/data/deck.json`，开发资源整目录可从当前19单位 Web 包排除。

## 坐标与状态归属

- 米、秒、弧度，1:1、缩放为1；+X右舷、+Y向上、-Z舰艏。原点为所记录全长中点的基准水线。
- `boundary_xz_m` / `polygon_xz_m` 的每点是 `[x,z]`；`position_m` / `points_m` 为 `[x,y,z]`。边界含边，不能把包围矩形当实际甲板。
- 数据均为舰体局部坐标。世界点 `ship_transform * local_point`，世界方向 `ship_transform.basis * local_direction`。承载飞机姿态必须随母舰完整姿态变化。
- 模拟拥有占用、起降、队列、维修与损伤；模型只消费 `apply_state` / `apply_equipment_state`，没有自行计时、移动飞机或补油弹。

## 数据字段

| 字段 | 含义 |
| --- | --- |
| `schema_version`, `ship_id`, `configuration_date`, `source_status` | 版本、稳定舰ID、历史日期与可信范围；图像比例估值不冒称厂图测量 |
| `flight_deck.height_m`, `boundary_xz_m`, `thickness_m` | 飞行甲板可见顶面、真实外轮廓与板厚；升降机孔另扣除 |
| `obstacles[]` | `id`, `polygon_xz_m`, `bottom_m`, `top_m`, `host_id`；舰岛/炮区/禁入外缘；是几何障碍而非飞机智能 |
| `reference_lines[]` | `id`, `kind` (`takeoff` / `landing`), `points_m`, `half_width_m`, `source_status`；均为参考走廊，不意味着可同时使用 |
| `zones[]` | `id`, `kind` (`parking` / `folding` / `holding` / `exit`), `polygon_xz_m`, `height_m`, `requires_folded_wings`；容量由实际机型包络和占用计算，不写虚构固定架数 |
| `elevators[]` | `id`, `center_xz_m`, `size_xz_m`, `upper_height_m`, `lower_height_m`, `translation_axis`, `node_path`, `opening`；升降机独立活动，孔范围与可见台面一致 |
| `paths[]` | `id`, `kind` (`holding` / `exit`), `points_m`, `half_width_m`；候机/退出的几何参考路径，OPS01仍须按翼展、障碍与动态占用校验 |
| `arresting_wires[]`, `barriers[]`, `catapults[]` | 可见设备的几何参考，不实现阻拦索动力学、弹射或拦阻行为；不把液压弹射器描述为现代蒸汽设备 |

Essex 顶面语义：固定甲板不含两座中线升降机孔；左舷舷侧升降机额外提供可移动承载面，不把甲板外的矩形区域默认算作可走。升降机下降时原位不再是飞行甲板；只能在相应台面当前高度内承载。甲板与机库只表示表面/抽象库存边界，不承诺机库内部可通行。

## 纯模型查询约定

`deck_definition() -> Dictionary` 返回防御性深复制；`deck_surface_at(local_xz: Vector2) -> Dictionary` 返回 `{supported, height_m, surface_id}`，反映当前升降机高度并拒绝甲板外/孔内无台面的点。查询一个点不能替代对整个飞机接地/翼尖包络的检查。`deck_obstacles()` 返回同一数据的障碍棱柱。`apply_equipment_state(elevator_id, {height_m}) -> bool` 只驱动独立升降轴；非有限输入拒绝、有限高度夹在行程内。不能靠甲板查询将不在甲板上的飞机吸附回甲板。

静态安装检验先使用真实尺寸 F6F / SB2C 现有纯模型，验证轮胎接触、机翼展开/已有折翼状态、边界、障碍和相互间距。它只证明装配可用。起飞/排队/着舰/返航/复飞和移动母舰上的连续航空作业均属于 OPS01，须另验收。

CV01最终布局值（2026-11-11修订）：飞行甲板y=15.85m，机库/升降机下位y=7.926m，行程7.924m。17.35/8.10为已撤回草稿，未供正式消费。原始剖面比例、精度和机库净高差异见[Essex参考卡](references/ships/essex_cv9_1944_04_15/modeling-brief.md)。本版升降机网格和孔口统一矩形简化，`corner_radius_m=0`；不使用未核实圆角对飞机放行。
