# S09 原创群岛港湾参考与资产来源

2026-11-10。参考只用于地图组织与色面判断；没有复制《战舰世界》的地图轮廓、纹理、模型、天空或声音。装备保持本项目的米制尺寸，未照搬其装备/地图比例。

| 实际打开的原图 | 观察及用途 | 不采用的细节 |
| --- | --- | --- |
| [Islands 官方 Wiki 全幅](https://wows-media-wowswiki-prod.wgcdn.co/thumb/f/f5/Islands_screen.png/1100px-Islands_screen.png)；[说明页](https://wiki.worldofwarships.com/Islands) | 已在本轮通过view_image实际查看1100×619原图：岩质低岛、间隔水道、较克制的岸线白浪；用于区分近岸与中央水面和岛链轮廓 | 战斗构图、烟火安排、精细石壁/植被没有复制；不按宣传图推算历史参数 |
| [Seychelles 官方 Wiki 全幅](https://wows-media-wowswiki-prod.wgcdn.co/thumb/9/9b/Seychelles_screen.png/1100px-Seychelles_screen.png)；[说明页](https://wiki.worldofwarships.com/Seychelles) | 已通过view_image实际查看1100×619原图：山地退到镇后，建筑沿弧形海湾排布，木栈桥/近岸浅水与外海层次；用于本图港湾、小镇、山坡的空间关系 | 不复制照片级植被、度假设施、鸟群、海底、特定地标和精细反射 |
| [官方地图目录](https://wiki.worldofwarships.com/Ship%3AMaps)、[12.3更新](https://wiki.worldofwarships.com/Ship%3AUpdate_12.3) | 只作为地图尺寸/布局思路的文字背景；没有把文字页当成原图检查 | 本项目地图为24km活动范围，舰机不缩放；本文不声明与该游戏比例一致 |

本轮本地参考副本仅保存在忽略目录 `.local/s09-references/`，不是游戏资产，不进入Web包。英文071旧更新和当前新闻页未能可靠取得内容，没有声称其截图已核对。参考图的版权属于Wargaming；交付图是Godot实际运行本项目原创网格的截图。

## 原创实现

- `data/maps/island_harbor.json`：原创岸线、山峰、台地、小镇组团、道路、码头、防波堤、安装点和镜头位置；任意真实地点的复刻不在范围。
- `BattlefieldTerrain` / `TerrainQueries`：冻结的径向分环三角网格，中心必须位于多边形可见核；安装时检查这一限制，避免凹角径向重叠。所有地面高度与碰撞均查询最终三角面，而非另算解析山峰。
- 原创静态网格、顶点色材质、程序海面/岸线shader。坡面不投射短距离舰艇级联阴影，保留平滑法线、阳光/环境光和建筑/舰艇阴影；没有添加高成本地形阴影贴图。
- 房屋/仓库使用长方体墙与双坡顶，碰撞采用含屋顶的保守AABB；起重机为少量细杆装饰，不设隐藏的大盒碰撞。
- 地形/码头不能破坏。浅滩带是外观，不模拟潮汐、吃水或海底深度；航行按舰体包络和安全距离避陆。山地与建筑是实物遮挡，海面几何仍为海平面0，波纹只影响材质法线。
