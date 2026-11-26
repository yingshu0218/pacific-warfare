# MAP02 独立扩展地图边界

2026-11-11。在S09地图之上制作独立版本；旧地图、共享TerrainQueries/BattlefieldTerrain/TerrainNavigation、共享Session/游戏/观战UI、S14场景/导演、海水/云、武器/伤害和单位自动注册目录均冻结。本轮不注册任何新战斗单位，不放装饰炮。

新增路径：`data/maps/island_harbor_expanded.json`；`data/map02/`区域/设施模块/实例；`scripts/map02/`表现与只读检视；`scenes/map02/`独立入口；`tests/map02/`专属查询/装配；`tools/map02/`生成与有界捕获；`docs/maps/MAP02/`、`docs/references/maps/MAP02/`、`docs/showcase/evidence/MAP02/`（.gdignore）。

所有高度/海陆/首次命中/导航仍调用现有TerrainQueries与TerrainNavigation。新设施展开成现有objects支持的quay（导航/地面）或building代理字段，形状细节由MAP02渲染适配读取同一数据，不扩展公共源码。水上平台有真实顶面和实体承载，不把海面写成陆地。

现有GroundDeployments.validate只接受is_land=true、height_m(false)地面。给AA02的炮位全部安排在陆地平面；水上码头的服务挂点使用height_m(true)，暂不宣称旧GroundDeployments能在水上部署炮。以后若要水上炮位，需要明确的support_surface接入和旧地图回归，当前基线交付前不落地此公共改动。

机场本轮仅发布设施与静态跑道/滑行/停车/净空数据，OPS01负责作业；外海操作区域只验证空间净空，不虚构航母起降状态。
