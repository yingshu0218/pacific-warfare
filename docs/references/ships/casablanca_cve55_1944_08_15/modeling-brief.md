# 卡萨布兰卡号 USS Casablanca CVE‑55
**1944‑08‑15，Astoria。** 美国护航航母，商船式舰体轮廓，但不是把这条具体船由既有商船改装。仅外观模型及检视台场景，不注册可战斗或起降单位。未实现各类武器、内舱、机械或操作；甲板升降机只作为闭合可视面及定位标记。

| 参考 | 用途 | 边界 |
| --- | --- | --- |
| [NHHC / DANFS Casablanca](https://www.history.navy.mil/content/history/nhhc/research/histories/ship-histories/danfs/c/casablanca.html) | 总长 512′3″、舰宽 65′2″、吃水 20′9″。 | 档案名称中的极宽尺寸不是可用飞行甲板宽；未由 1944 照片测吃水。|
| [1945 年美国海军航空公报](https://cgsc.contentdm.oclc.org/digital/api/collection/p4013coll8/id/4665/download) | CVE‑55 级可用甲板 474′ × 80′、两个大小不同的中线升降机。 | 用作模型尺度约束，不称舰厂三维数据或精确安装位置。|
| 1944‑08‑15 NAS Astoria 美国海军照片的 [右舷](https://www.navsource.net/archives/03/0305516.jpg) 与 [左舷](https://www.navsource.net/archives/03/0305516a.jpg) | 已直接查看高清图并分辨前置右舷小舰岛、薄飞行甲板、艏艉自由空间及左右不同的三色迷彩。 | 黑白照片只决定色块方向、比例及明暗，海平面和部分细线有透视影响；表面颜色为艺术近似。|
| 同组 [正艏](https://www.navsource.net/archives/03/0305516b.jpg) 与 [正艉](https://www.navsource.net/archives/03/0305516c.jpg) | 已直接查看高清图：外伸甲板边缘、艏突出形体、艉横梁孔洞及圆角艉。 | 未从照片推断甲板载荷、通风可用性或结构强度。|
| [NHHC 80-G-165986](https://www.history.navy.mil/our-collections/photography/numerical-list-of-images/nara-series/80-g/80-G-100000/80-G-165986.html)、[80-G-165987](https://www.history.navy.mil/our-collections/photography/numerical-list-of-images/nara-series/80-g/80-G-100000/80-G-165987.html) | Measure 32 Design 12A 舰级档案目录。 | 直接原图无法通过此环境打开，只用已核对的同日实舰照片绘制，未照摹档案图。|
| [NARA 520581 的上舰载货照片副本](https://www.navsource.net/archives/03/0305513.jpg) | 大体甲板形状的补充。 | 1945 年运输，飞机、甲板配置及栈桥位置不作为 1944 细节。 |

以 1 米为一个 Godot 单位。舰体、飞行甲板、机库、舰岛和艇具分组独立；正艏及正艉的孔洞与下缘为非操作性视觉表达。原图不进入发行资源。甲板编号、细栏杆、甲板纹理和花纹曲线用艺术近似，尚未按整舰建造图确认；舰体上层标高、升降机纵向位置近似。

独立模型检查：`godot --headless --path . --script res://tests/carrier_gallery/test_casablanca.gd`。可设置 `CARRIER_EXPORT_DIR` 指向存在的目录以保存 GLB。Godot 4.7.2 静态检查通过，非可玩舰验收。
