# 航母扩编 · 六型整舰外观候选

启动：`godot --path . res://naval/carrier_gallery/viewer.tscn`。1–6 选择舰，V 切换斜前、斜后、俯视、侧视。独立场景均可直接实例化。

| 舰 | 外观配置 | 模型长 | 本轮轮廓依据 |
| --- | --- | ---: | --- |
| 企业号 CV-6 | 1942 年 3 月 | 246.74 m | [NHHC 舰史及舰长](https://www.history.navy.mil/research/histories/ship-histories/danfs/e/enterprise-cv-6-vii.html)、[19-N-29689 当期右舷](https://www.history.navy.mil/our-collections/photography/numerical-list-of-images/nhhc-series/nh-series/19-N-29000/19-N-29689.html)、[19-N-29690 当期甲板近影](https://www.history.navy.mil/our-collections/photography/numerical-list-of-images/nhhc-series/nh-series/19-N-29000/19-N-29690.html)。[80-G-463049 1938 年高位左舷](https://www.history.navy.mil/content/history/museums/nmusn/explore/photography/ships-us/ships-usn-e/uss-enterprise-cv-6/80-g-463049.html)仅看总体舰体、甲板，不复制 1938 设备。 |
| 独立号 CVL-22 | 1943 年 7 月 | 185.93 m | [80-G-74433 正斜前高位](https://www.history.navy.mil/our-collections/photography/numerical-list-of-images/nara-series/80-g/80-g-70000/80-G-74433.html)、[80-G-74436 斜侧](https://www.history.navy.mil/content/history/nhhc/our-collections/photography/numerical-list-of-images/nara-series/80-g/80-g-70000/80-G-74436.html)、[USN 长度记录](https://www.history.navy.mil/content/history/nhhc/research/library/online-reading-room/title-list-alphabetically/w/war-damage-reports/uss-independence-cvl22-uss-denver-cl58-war-damage-report-no-52.html)。小舰岛和四根外置烟囱分别建模。 |
| 赤城号 | 1941 年单层甲板配置 | 260.67 m | [NOAA 舰长与船体](https://oceanexplorer.noaa.gov/photogrammetry/akagi/)，[NH 73058 改装后艏视](https://www.history.navy.mil/our-collections/photography/numerical-list-of-images/nhhc-series/nh-series/NH-73000/NH-73058.html)，[NNAM Akagi 1941 甲板局部](https://www.history.navy.mil/content/history/museums/nnam/explore/collections/aircraft/a/a6m2-zero0/a6m2-zero-on-board-akagi.html)。采用左舷舰岛、右舷侧排烟和改装后的单层通长甲板，不沿用早期三层结构。 |
| 瑞凤号 | 1944 年 10 月代表配置 | 205.50 m（暂用估值） | [80-G-272552 当期斜高视](https://www.history.navy.mil/content/history/museums/nmusn/explore/photography/wwii/wwii-pacific/leyte/sibuyan-sulu-seas/80-g-272552.html)、[80-G-281768 高位](https://www.history.navy.mil/our-collections/photography/numerical-list-of-images/nara-series/80-g/80-G-280000/80-G-281768-battle-of-leyte-gulf.html)、[NH 95471 档案说明](https://www.history.navy.mil/our-collections/photography/numerical-list-of-images/nhhc-series/nh-series/NH-95000/NH-95471.html)。战损照片只取可辨的未损轮廓，不复制变形。舰桥置于甲板下；甲板迷彩是视觉估绘，色值不是历史测量。 |

模型以米为单位，原点在水线舰长中点，-Z 舰艏、+X 右舷。舰体、机库、甲板、舰桥、排烟和外部设备可独立检查。舰长与图片能看清的大结构用于这一轮；肋位、楼层、舷外平台、甲板纹样和细部位置有估值，不据此宣称历史终验。舷侧局部设备尚无足够近照对位。升降机位置只为外观检视，未作为运行起降接口。未安装武器，不改游戏单位定义、航空作业、火控或战斗场景。

验证：`godot --headless --path . --script tests/carrier_gallery/test_carrier_gallery.gd`。设置 `CARRIER_EXPORT_DIR` 可把实际装配导出为四个 GLB。四种舰体、四类镜头、四个导出合计 76 项检查，模型尺寸项属于游戏网格测量，不是原舰精度校验。图库视觉可以离线渲染，不等于正式对局画面。未运行网页对局。


用户已确认加入两艘护航航母，不按阵营数量强行配平：5 卡萨布兰卡号 CVE-55（1944-08-15）和 6 大鹰号（1943-09-30）。两者独立建模，详见[卡萨布兰卡史料及验证](../references/ships/casablanca_cve55_1944_08_15/modeling-brief.md)和[大鹰史料及验证](taiyo-1943-static-exterior.md)。通过此检视入口不代表已通过舰载机作业或正式对局准入。
