# 美军扩充：六舰、两机独立外观

本轮只制作二战游戏用静态整舰、整机外观。不启用实时武器、导航、起降、损伤或对局生成。没有基于阵营平衡调整或增加任何单位。PBY-5A、LST-808 仍是场景候补。

## 如何检视

从 Godot 打开 `res://showcase/us_model_gallery/viewer.tscn`，运行当前场景。数字键 **1–8** 切换模型，**V** 循环切换前斜、后斜、俯视和侧视。名单、独立资源路径及参考构型保存在 `data/visual_catalogs/us_expansion.json`。展台没有更改项目已有的启动入口。

| 序号 | 外观目标 | 优先参考 |
| --- | --- | --- |
| 1 | 阿拉斯加（CB-1），1944 年 11 月 | [NHHC 舰史和整舰照片](https://www.history.navy.mil/content/history/nhhc/research/histories/ship-histories/danfs/a/alaska-iii.html) |
| 2 | 宾夕法尼亚（BB-38），1944-07 关岛 | [NH 67584](https://www.history.navy.mil/our-collections/photography/us-navy-ships/battleships/pennsylvania-bb-38/NH-67584.html) |
| 3 | 圣迭戈（CL-53），1944 年初 | [NHHC 1944-01-01 侧视](https://www.history.navy.mil/content/history/nhhc/research/histories/ship-histories/danfs/s/san-diego-ii.html) |
| 4 | 萨拉托加（CV-3），1942 年中 | [NHHC 19-N-29683，1942-05-14](https://www.history.navy.mil/our-collections/photography/numerical-list-of-images/nhhc-series/nh-series/19-N-29000/19-N-29683.html) |
| 5 | 塞缪尔·B·罗伯茨（DE-413），1944 年 10 月 | [NHHC 舰史与同期影像](https://www.history.navy.mil/research/histories/ship-histories/danfs/s/samuel-b-roberts-de-413-i.html) |
| 6 | 大黄蜂（CV-8），1942 年初 | [NHHC 19-N-28431，1942-02](https://www.history.navy.mil/our-collections/photography/numerical-list-of-images/nhhc-series/nh-series/19-N-28000/19-N-28431.html) |
| 7 | F4U-1A，VF-17，布干维尔，1944-02 | [NHHC 80-G-425500](https://www.history.navy.mil/our-collections/photography/numerical-list-of-images/nhhc-series/nh-series/80-G-425000/80-G-425500.html) |
| 8 | P-38J，二战西南太平洋代表涂装 | [史密森 P-38J-10 外形参考](https://airandspace.si.edu/collection-objects/lockheed-p-38j-10-lo-lightning/nasm_A19600295000) |

大黄蜂当前不摆放轰炸机；对应历史甲板陈列应使用 B-25B，不以已有 B-25J 冒充。历史照片未覆盖的局部和配色按各模型参考记录标注，不承诺复刻不可见结构。

## 验证入口

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . --script res://tests/model_audit/test_us_gallery.gd
godot --headless --path . --scene res://showcase/us_model_gallery/viewer.tscn --quit-after 8
godot --headless --path . --scene res://showcase/carrier_harbor.tscn --quit-after 8
godot --headless --path . --script res://showcase/us_model_gallery/export_exteriors.gd -- /absolute/visual-output
```

展台验证覆盖 8 个可选场景、实际可见三角网格、基础尺度、四视角画面范围和交互切换。GLB 仅为视觉核对而导出，离线渲染不是实时游戏截图。未做浏览器、实际航行和飞行、战斗、性能或航母起降验收。

逐组建模依据和限制：[阿拉斯加／圣迭戈](A04-alaska-san-diego-visual.md)、[宾夕法尼亚／罗伯茨](bb38-de413-static-exteriors.md)、[萨拉托加／大黄蜂](../us_carrier_1942_exterior.md)、[海盗／闪电](../references/aircraft/us_archive_1944/modeling-brief.md)。
