# QJ03 岸防历史外观道具

青岬是架空地图，以下三件是独立 Godot 场景外观，不是三个宣称已考证的不同实物型号。只提取档案外形中的轮廓线索，不恢复实际构造或战时位置。炮身端部封实，全套无碰撞体、控制、转动、弹药、单位注册或战斗逻辑。混凝土、旧色、沙袋和布景平台均是虚构美术。

| 场景 | 外观身份 | 原始馆藏线索 |
| --- | --- | --- |
| `scenes/qingjia/qj03_props/open_plinth.tscn` | Piti Vickers-type Model 3（140 mm 原型）外形参考；露天布景 | [NPS Piti 岸防炮馆藏记录／美国国家档案 80-G-247835](https://www.nps.gov/media/photo/gallery-item.htm?gid=A069B7F4-1B4D-454C-8C6C-28724AFE5647&id=de65db9b-82f9-4929-82a3-c0738366e6e0)、[NPS 现存器物照片](https://www.nps.gov/wapa/planyourvisit/piti-guns-trail.htm)。用其较长的整体轮廓、块状侧壁和沉绿灰色作为美术线索。 |
| `scenes/qingjia/qj03_props/shielded_housing.tscn` | 档案所称日本六英寸级岸防炮的外形参考；虚构护盾，不声称照片实物装有此护盾 | [美国海军历史与遗产司令部档案 80-G-307884](https://www.history.navy.mil/content/history/museums/nmusn/explore/photography/wwii/wwii-pacific/mariana-islands/tinian/80-g-307884.html)。以粗重、低位轮廓作为美术线索，不据此确认细分型号。 |
| `scenes/qingjia/qj03_props/cliff_facade.tscn` | 同一六英寸级艺术原型的半遮挡表现；外墙和岩块属于青岬架空设计 | 同一 Tinian 馆藏，另参照 [NPS 关岛 15.2 cm 岸防炮档案／美国海军陆战队照片 92657](https://www.nps.gov/media/photo/gallery-item.htm?gid=86306256-72BE-418A-8C95-48EAF4248814&id=9a817500-797a-4e25-9997-49ce59cf91a8)。两地照片不等于两个独立型号。 |

运行 `godot --headless --path . --script tests/qingjia/test_coastland_exteriors.gd` 检查全部资源实例化、几何非空、同一地面原点及无非外观节点。完成三件 Godot Compatibility 原生截图，素材不含原始历史照片且没有提交渲染产物。
