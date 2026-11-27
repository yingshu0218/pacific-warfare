# 云端模型复核 · 第一轮（2026-11-26）

基线：GitHub `bf7b424`，Godot `4.7.2.stable.official.ed1daf0bf`。此轮核正式场景装配，不以已渲好的历史截图代替。可重复入口：

```sh
python3 tools/verify.py --owner model-audit --timeout 120 test res://tests/model_audit/test_bomber_flight_pose.gd res://tests/map02/test_map02_terrain.gd
python3 tools/verify.py --owner model-audit --timeout 180 godot -- --script res://tests/model_audit/measure_models.gd -- /absolute/output glb res://scenes/map02/facilities.tscn res://scenes/map02/expanded_map.tscn
```

## 已实测与修正

- 逐一实例化全 14 个全单位清单模型（6 舰、6 机、2 项地面布景）。以模型根坐标测可见三角网格；舰体和附属结构分别测。对舰体另记录 Godot 本地 `Y=0` 截面；仅在原作者注明该截面是设计水线时用它核历史水线值。高度、舷外最大宽、船体最大宽、水线宽、停放高度、飞行轮廓均非同一口径。
- D4Y2、G4M1、B-25J 的独立飞行入口在拿到首个世界状态前会沿用地面检视的放轮姿态。现在在装配完成时呈现初始收轮飞行外观；原地面检视场景照常放轮，后续战场状态仍完全由模拟驱动。三机前后翼展和机长未改变。未碰物理、碰撞定义、历史参数或武器/任务规则。
- Godot 实际装配导出仅包含参与本次量测的可见网格；由另一渲染器做同方向视图。因此图只供轮廓及装配复核，不用来确认 Godot 着色器、实时表现、精确材质或尺度相同。
- 港湾 12 类设施检视和扩展地图实例化通过；99 处设施的落地与模块边界等由 MAP02 回归覆盖（1015 次断言、0 失败），不是 99 处独立历史建筑认证。独立沃莱艾机场、衣阿华子项目导入及短启动通过，不等于对其版本所有细节作历史重验。
- 首轮尺寸/装配与场景回归：战列舰、驱逐舰、舰体、飞机、地面布景、AV02/03/04/05、正式全单位场景；新三机收轮测试与 MAP02 测试通过。云端修订后的港湾 Web 包重新导出成功；当前 Chromium 可执行文件缺失、另取测试浏览器失败，未取得浏览器运行画面或帧率。

## 口径差异，未据此整体缩放

- 大和量得舰体长 263.00 m、最宽 38.90 m，与[呉市海事历史科学馆](https://yamato-museum.com/yamato-data/)的两项尺度一致。
- 衣阿华舰体最大宽 33.00 m、长 270.40 m，接近[美国海军舰史](https://www.history.navy.mil/content/history/nhhc/research/histories/ship-histories/danfs/i/iowa-iii.html)给出的 32.97 m、270.43 m。整个装备展开包围盒测得 38.66 m，极值在两舷模型附属件，不是舰体宽。
- 弗莱彻舰体长 114.76 m、最大宽 12.07 m，接近[美国海军舰史](https://www.history.navy.mil/research/histories/ship-histories/danfs/f/fletcher.html)的 114.68 m、12.09 m；该量级差异不作为改比例理由。
- 埃塞克斯：实际设计水线宽 28.3464 m 与[美国海军舰史](https://www.history.navy.mil/content/history/nhhc/research/histories/ship-histories/danfs/e/essex-iv.html)的 93 英尺相同。整个模型宽约 44.88 m，非舰体宽。翔鹤设计水线宽/长测得 26.00 / 249.99 m，和仓库[参考任务卡](../references/ships/shokaku_1941_08_23/modeling-brief.md)采用的 26.00 / 250.00 m 数值一致；这条是仓库资料口径交叉核对，不作为外部独立史料复审。
- SB2C-4 的 11.110 m 飞行轮廓包含桨毂等端部，原[准入交付](SB2C-admission.md)已注明名义机长 11.049 m 与可见包围盒不等；先不改。
- 尚未严证：埃塞克斯从龙骨到最高装备的量测与数据高度是否采用同一端点；个别飞机停放高度不能拿收轮飞行高直接验；地面组件数据可能含基座/姿态使用包络。区分“数据口径待核”与“确定错形”。此轮未逐项复审历史照片/图纸，未覆盖所有未准入样件、复刻部件与试验场景，不宣称项目级历史外观全验收。
