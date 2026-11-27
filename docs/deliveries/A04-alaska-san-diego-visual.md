# 阿拉斯加号 CB-1 与圣迭戈号 CL-53 · 历史外观展示

两个独立、非操作的 Godot 游戏外观，均以米为单位，X 横向、Y 向上、Z 舰长，舰首为 -Z，Y=0 为模型设计水线。舰形、上层建筑及装饰均为闭合外观或外部静态网格，不提供内部结构、操作或战斗接口。

## 阿拉斯加号（1944 年 11 月）

- 同舰、改装后的 [NH 57212（1944-11-13）](https://www.history.navy.mil/content/history/nhhc/our-collections/photography/numerical-list-of-images/nhhc-series/nh-series/NH-57000/NH-57212.html) 与 [NH 57213（1944-11-12）](https://www.history.navy.mil/our-collections/photography/numerical-list-of-images/nhhc-series/nh-series/NH-57000/NH-57213.html) 的斜视及舷侧原照均已实际检视。取长艏、阶梯式高前舰桥、单宽烟囱、舰中作业空间和较低后甲板作辨识线索。没有把照片中的浮体或背景当作舰体。
- [NARA 80-G-165989 左舷](https://www.history.navy.mil/content/history/nhhc/our-collections/photography/numerical-list-of-images/nara-series/80-g/80-G-100000/80-G-165989.html) 与 [80-G-165990 右舷／甲板](https://www.history.navy.mil/content/history/nhhc/our-collections/photography/numerical-list-of-images/nara-series/80-g/80-G-100000/80-G-165990.html) 两份 Design 1D 原图均已查阅。独立描绘两舷分块，非镜像。只还原可辨识的船侧大色块；色值、上层建筑与甲板局部不是历史实测。
- [1945 年美国海军《Ships' Data》页 42–43](https://shipscribe.com/pubs/SDB1945v1.pdf) 的 CB-1 船体尺寸作为外廓约束：808 ft 6 in / 91 ft 1 in。设计水线下 **9.700 m** 是这个资产的工作值，不是同日载荷实测，亦不同于档案内最大航行吃水。

## 圣迭戈号（1944-01-01）

- 同日 [19-N-60146 舷侧](https://www.history.navy.mil/our-collections/photography/numerical-list-of-images/nara-series/19-n/19-N-60000/19-N-60146.html) 与 [NH 97826 舰尾斜视](https://www.history.navy.mil/our-collections/photography/numerical-list-of-images/nhhc-series/nh-series/NH-97000/NH-97826.html) 原图均已实际检视。两根细烟囱、分离双桅、前后叠层、平低尾部、外悬平台及船侧小号 53 以两张同日照片为锚点。远侧和水下细节保留估形，没有照抄另一型巡洋舰的艇尾设施或后期形态。
- [《Ships' Data》页 60–61](https://shipscribe.com/pubs/SDB1945v1.pdf) CL-53 外廓 541 ft 6 in / 53 ft 2 in。20 ft 10 in 的资料口径转为 **6.350 m** 工作水线，不能解释成照片当日确切载荷。灰蓝色是展示工作色。

## 复验

- 入口：`res://scenes/ships/alaska_cb1_1944/alaska_viewer.tscn`、`res://scenes/ships/san_diego_cl53_1944/san_diego_viewer.tscn`，按 1–4 选择斜视、舷侧、俯视与无水面全外形。
- Godot 4.7.2 两个独立入口无窗口烟测成功。用 `godot --headless --path . --script tests/model_audit/test_alaska_sandiego_exhibits.gd` 复现实际几何审计；追加 `-- /tmp` 生成两个实际渲染 GLB。船体尺寸分别为 **246.431 × 27.762 m** 与 **165.049 × 16.205 m**，外观网格 12,776 / 14,108 三角面。主船体未发现开边或非流形边；四镜头检查所有网格顶点投影。
- 本轮图从 Godot 导出网格，用 Blender 离线渲染；不称为在线试玩截图。独立入口已验，未在本补丁中修改正式单位注册、Web 构建清单、既有场景或玩法。
