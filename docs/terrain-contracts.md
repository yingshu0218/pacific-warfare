# S09 统一地形契约 v1

2026-11-10。接口已实现并自验收；统筹机制/原生复核通过，最终交付索引待核对。米、秒、+Y上、-Z北。原创地图 `res://data/maps/island_harbor.json`，24×24 km边界，主要测试区域约12×12 km。空地图全部海平面0。

## 给 S04 的只读入口

`TerrainQueries.height_m(world: SimulationWorld, point: Vector3, include_buildings: bool = false) -> float` 返回同一三角网格的精确插值高度；include_buildings=true包括港口建筑/码头顶面。海域返回sea_level_m。

`TerrainQueries.segment_hit(world: SimulationWorld, a: Vector3, b: Vector3, include_sea: bool = true) -> Dictionary` 返回实际线段首先接触的表面，未命中返回空字典；非空包含 `fraction:float (0..1)`、`position_m:Vector3`、`normal:Vector3`、`surface:String (sea/ground/building)`、`target_id:String`。include_sea=false用于视线/遮挡；已在地面以下的起点返回fraction=0，防止穿山。

`TerrainQueries.is_land(world, point) -> bool` 只表示地形大陆/岛屿；建筑/码头可在海上，需要segment_hit或height_m(...,true)。S04不要自己复制多边形/高度算法；正常飞行安全查height_m(...,true)，运动扫掠查segment_hit，仍将真实接触交unit_surface_contact。无地形安装也可调用，默认海面；reset后仍有效。

`BattlefieldTerrain.install(world, path)` 在configure后、AircraftSuite/CombatSuite/FleetSuite前调用，读取/编译一次场次冻结数据，注册priority=10模块；reset重挂同一纯数据到 `world.shared_state.terrain`，不重建网格。正常用户入口由session唯一安装。渲染/相机消费同一份数据；不包含Node/Callable/Object，不使用战斗随机流。不得修改shared_state.terrain。

## 最终布局

北=-Z。主岛西北（中心[-5100,-4750]），有海湾/低岸城镇与640m山脊；东北高岛链，南侧碎岛。中央约x±4000、z±2200连续开阔海，四舰旧出生点±4000,0与八机初态保留；新地图航线/退出区由场景覆盖。港湾位于主岛东南面，水道从中央海域通入。最终坐标与[同源布局图/部署表](maps/island_harbor.md)已发布。

## S10 阵地

最终高地安装点为[-5200,590,-4630]，使台地接近自然山坡，避免早期390m深切。四处稳定id、半径与射界见地图说明。

数据 `deployment_sites` 每点含id、label、position_m（承载表面）、yaw_rad、radius_m、roles、suggested_faction、train_limits_deg、elevation_limits_deg、clearance_m。至少港湾入口岸炮、港区低地防空、山脊高地防空。点位经同源高度/平整度与前向火线检查；全部为空阵地，不计参战单位。S10从场景ground_deployments选择site_id/definition_id/faction_id，不需改地图生成代码。


## 编译与表现限制

径向网格使用一条有序岸线及位于其可见核的中心，安装检查每条边相对中心的绕向，防止三角形重叠。高度与线段命中只用编译三角面，峰函数仅用于一次生成；分区索引320m，视线采用二维格子DDA筛选。38个建筑/码头代理也有独立分区。source里建筑基础/墙根的最终高度由同源三角面四角采样得出，渲染与代理共用。

舰艇可视图和小地图由同一岸线派生。所有查询不改变战斗随机数、库存、命令或模拟时钟。相机/画质/地图显隐只改变表现，重开复挂同一已编译数据。
