# 旧金山号 CA-38 / 火奴鲁鲁号 CL-48：1942 年静态外观

两艘是独立 Godot 展示模型，不注册战局、不增加碰撞、可操作部件、武器接口或动画。使用项目共享船舶哑光风格；水下形体及不能由照片直接读出的尺寸、细节与灰蓝配色均为美术近似，不作为建造图或特定日期涂料的档案还原。

| 游戏模型 | 外观取样时间 | 场景 |
| --- | --- | --- |
| 新奥尔良级旧金山号 CA-38 | 1942 年末外轮廓，完整无战损的代表构型 | `res://scenes/ships/us_fleet_cruisers/san_francisco_visual.tscn` |
| 布鲁克林级火奴鲁鲁号 CL-48 | 1942 年 10 月 24–26 日，马雷岛海军船厂与附近海域 | `res://scenes/ships/us_fleet_cruisers/honolulu_visual.tscn` |

## 逐舰比对

### CA-38 旧金山号

- 侧面：[约在 1942 年南太平洋的照片与 1942-12-11 马雷岛海军照 7723-42](https://www.navsource.net/archives/04/038/04038.htm#0403853)；前斜面：[1942-12-04，NH 95449](https://www.history.navy.mil/our-collections/photography/numerical-list-of-images/nhhc-series/nh-series/NH-95000/NH-95449.html)。以返航照片辨认船体和上层建筑关系，不复刻照片中的战损、登舰设施或人员，也不混用 1943 年维修后改型。
- 对照后修正：前后烟囱略向前收拢且封盖压暗；补入二者之间较矮的抬高轮廓，后观察平台加宽；压低并拉近两根细桅的高度。用直边层叠舰桥、前二后一组低壳形、靠中后的工作架、较低的后甲板与船艏陡升辨识。雨檐、敞台、舷侧线不完全按照片复原。
- [美国海军官方舰史](https://www.history.navy.mil/research/histories/ship-histories/danfs/s/san-francisco-ii.html)为外轮廓长度与最大宽度基准。Godot 合并可视包围盒为 **179.27 m 长 × 19.12 m 宽**，不以桅高作历史尺寸验证。

### CL-48 火奴鲁鲁号

- 侧面：[1942-10-26，19-N-36362](https://www.history.navy.mil/our-collections/photography/numerical-list-of-images/nara-series/19-n/19-n-30000/19-N-36362.html)；前后斜面与局部甲板：[1942-10-24/26 马雷岛照片 6599-42、6602-42 及国家档案馆两张船厂外观](https://www.navsource.net/archives/04/048/04048.htm#0404841)。不将 1943 年临时舰艏与 1944 年迷彩混入。
- 对照后修正：后烟囱与后桅前移，恢复后桥和两组后壳形之间的空间；保留靠中部回向的第三个前壳形、后端宽松的工作甲板、前桥圆廊与前后两枚错位吊臂。分开前后烟囱外径与顶高，增加前桅小格栅及桅架轮廓。照片无法确认的微小舾装简化。
- [美国海军官方舰史](https://www.history.navy.mil/research/histories/ship-histories/danfs/h/honolulu-ii.html)为外轮廓长度与最大宽度基准。Godot 合并可视包围盒为 **185.42 m 长 × 18.82 m 宽**。

## 验收

Godot 4.7.2 原生 Compatibility 渲染各生成侧视、艏向斜视、艉向斜视和俯视图。已检查尺寸范围、共享哑光材质、各自外轮廓和独立无碰撞。两个场景均可单独加载。档案照片保留在出处，不嵌入模型资源。
