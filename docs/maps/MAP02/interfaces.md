# MAP02 数据与接入契约

2026-11-11，独立静态地图版本1。共享S09查询与旧地图未修改，当前S14仍使用旧地图。这里的阵营只建议不同驻军配置，地图不是历史战役复原。

## 文件与入口

| 文件 | 用途 |
| --- | --- |
| `data/maps/island_harbor_expanded.json` | 所有可见设施、实体代理、地形、阵地和观测点；运行时查询的唯一输入 |
| `data/map02/facility_modules.json` | 12种原创模块，每个part给出局部米制位置、尺寸、颜色、形状和solid |
| `data/map02/facility_instances.json` | 99个实例的模块、区域、米制锚点及90°整数旋转 |
| `data/map02/regions.json` | 区域边界、航道、服务点、机场和航母预留水域 |
| `scripts/map02/expanded_map_data.gd` | 私有适配；compile委托TerrainQueries，load_for_world委托BattlefieldTerrain.install |
| `scripts/map02/expanded_map_view.gd` | 私有表现扩展；继承S09地形/海岸/道路，仅增加设施形状和空阵地地坪 |
| `scenes/map02/expanded_map.tscn` / `facilities.tscn` | 静态全图检视 / 单体模块检视；没有Session、战斗或航空作业 |

坐标为米，+Y向上，-Z向北。`bounds_xz_m`为[x,z,宽,深]。`position_m`在设施组件中指底面中心，尺寸是[x宽,y高,z深]。生成器按四分之一周旋转局部坐标及x/z尺寸，实际地图中的组件已展开，不让调用方再旋转一次。模块、实例、展开地图均由 `python3 tools/map02/build_map.py` 重建，随后 `python3 tools/map02/plot_layout.py` 生成俯瞰布局。

## 支承、弹着与障碍

保持 `TerrainQueries.height_data/height_m`、`land_data/is_land`、`hit_data/segment_hit` 和 `TerrainNavigation.chart/route` 原入口。245个实体代理仍由TerrainQueries编译；高度不由MAP02自算。北东岛只在扩展副本细分原边界的共线中点并加密网格，其他岛沿用原数据。

码头、防波堤及机场硬地使用现有`kind=quay`。民港码头顶面10m、军港顶面12m，实体沉箱从-14m/-16m延伸到顶面；弹着为ground，码头/防波堤进入舰船导航障碍。机场跑道/滑行/机坪顶面8.04m，底面7.5m，嵌入8m实际陆地。水上码头`is_land=false`，`height_m(true)`返回甲面，不能用裸地高度0m来装设备。

设施实体为`map02_structure`，被既有查询视作building。方墙和立柱用可见外包盒；圆罐用外接AABB，斜屋顶/锥顶/塔帽用其有限包络盒。屋顶查询顶面因此在坡缘最多提前接触该屋顶高度（最大维修棚屋顶10m），圆罐水平外接盒角最多超出半径约3.73m。这是保守遮挡/首次命中的简化精度，不是精确曲面碰撞，不应据此开展机库内部穿越。建筑没有可进入内舱，门是深色封闭面。吊机仅对实际四腿、上架、吊臂/配重等逐件建代理，腿间空隙可通；不制造整台实心包围盒。

窗、钟面、跑道标线、吊钩/极细吊索等不承担结构的部分设`map02_collision=false`，以现有跳过碰撞的kind=crane存储，由私有renderer按`map02_shape`绘制；实体吊机本身仍有碰撞。道路和阵地标记贴地绘制，不另增可承载高度。设施是静态环境，尚无建筑生命值/毁坏动画；BOMB01等后续若要可毁坏设施，需要另行接入模拟状态。

## AA02 安装点

七处均为`support_surface=land`、`clearance_m=0`、`placement_state=reserved_empty`，没有装饰炮/隐藏战斗单位。检查对中心与整圈32点验证裸地高度、平整与全高无遮挡，并检查3m炮口高度的三条180m水平线。表中射界相对站点`yaw_rad`，最终还须与具体装备机械限位求交。允许半径是场地净空半径，不表示已批准任何具体炮型。`overhead_clearance_m=90`是预留安装柱体，无承诺空中目标的所有方位都不受远处山体遮挡。

| deployment_sites.id | [x,y,z] m | 净空半径 m | yaw rad | 方向角限位° / 仰角° | 用途 / 驻军建议 |
| --- | --- | --- | --- | --- | --- |
| map02_civil_coast_01 | [-3010,32,-3200] | 32 | -2.35 | ±70 / -5～45 | coastal_gun / US |
| map02_town_aa_01 | [-5300,18,-3880] | 26 | 0 | ±180 / -5～85 | light_aa,heavy_aa / US |
| map02_main_ridge_aa | [-5200,590,-4630] | 30 | 0 | ±180 / -5～85 | light_aa,heavy_aa / US |
| map02_naval_coast_01 | [2150,42,-5050] | 34 | π | ±75 / -5～45 | coastal_gun / JP |
| map02_naval_aa_01 | [3250,12,-5260] | 25 | π | ±180 / -5～85 | light_aa,heavy_aa / JP |
| map02_naval_ridge_aa | [2950,478,-5700] | 30 | π | ±180 / -5～85 | light_aa,heavy_aa / JP |
| map02_airfield_aa_01 | [7400,8,-2450] | 26 | 0 | ±180 / -5～85 | light_aa,heavy_aa / JP |

现有GroundDeployments.expand/validate已经用现有US 5in/51和40mm M1实际验证前三处站点及物理炮口，场景夹具不安装战斗模块；正式部署和火控仍由AA02完成。日军点仅完成地形/净空验证，新日军炮型、炮座和限位由AA02核准，未用美军炮替代。`service_anchors`中的两个水上点只有服务用途，`not_ground_deployable=true`：现有GroundDeployments只接受陆地；水上装炮需要后续公共接口支持并回归旧地图，本轮没有该阻塞需求。

## 航道与OPS01静态预留

民港三航点[-3300,0,-1400]→[-3600,0,-2350]→[-3850,0,-2790]，导航膨胀半径120m；建议船长≤130m/宽≤22m。军港[3250,0,-1900]→[3250,0,-3250]→[3250,0,-4100]，半径220m；建议船长≤280m/宽≤42m。均实测原TerrainNavigation直接可通。这里验证几何包络，不含舰船转弯动力学、水深/潮汐、排队、交通避碰或大型舰的实际靠泊。

`airfield`发布1400×58m跑道（中心[6900,8.04,-2400]；两端z=-3100/-1700）、130×1700m地面清障框、760×16m平行滑行道、两条250×16m横向连接、8个半径16m停车位、两侧半宽80m的进近参考线、7处场站障碍实例ID。跑道/滑行道及连接在宽度内各75点核验支承，停车位各16点核验；两侧进近各3条线核验首次碰撞。机库、塔、营房及油罐的实际组件在主地图内，不能只用region矩形代替障碍。停车位、进近参考不授予任何机型起降能力，OPS01须依据机体尺度和真实运动验证占用、排队、滑行、起降/复飞与整备。

`carrier_operation_areas`提供JP西/US东各7×3km海域，z=8000～11000m，各有5400m直线和5km进近参考；用350m膨胀半径核验水域边界和直线，进近无地形接触。没有甲板、母舰模型或回收/转向算法。CV01/CV02/OPS01消费自己的甲板契约并验证实际作业，S14扩展批次再正式切图。
