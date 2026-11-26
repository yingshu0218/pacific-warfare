# S04 F6F 舰载使用态候选接口

2026-11-11，`f6f5_carrier_usage_v2`，最终自验镜像 r10。候选源码在 `candidates/s04-carrier-usage/`，带 `.gdignore`；未替换普通 S08 包的公共模型。准确版本见候选 `candidate-manifest.json`，不能只凭 geometry_id 认版本。统筹准入后由 OPS01 消费。

## 坐标与 CPU 几何

模型轴为 +X 右、+Y 上、−Z 前，单位为米／弧度／秒。保留 `model_root.position=(0,-2.30,0)`、10.236m 名义机长、13.056m 翼展、原机身/主翼/尾翼/机罩网格、六枪和 DM 安装轴。纯模型点加 (0,−2.30,0) 得到飞行局部点，再应用真实单位姿态。

唯一 CPU 几何定义为 `res://scripts/aircraft_geometry/f6f5_carrier_geometry.gd`（候选中同路径），继承 RefCounted，无 Node、场景树、时钟、渲染依赖或模拟写入。`definition()` 和 `configuration(gear_down,hook_down,deflection_rad,support_normal)` 返回新字典。审计静态导出见最终证据 `r10/cpu-geometry.json`；OPS 应直接 preload helper，不实例化可见模型读取 Marker。

| 轮胎 | 中心：纯模型 m | 中心：飞行局部 m | 半径 / 半宽 m | DM 宿主 |
| --- | --- | --- | --- | --- |
| 左主轮 | (−1.93,1.30,−1.27) | (−1.93,−1.00,−1.27) | .43 / .08 | wing_left |
| 右主轮 | (1.93,1.30,−1.27) | (1.93,−1.00,−1.27) | .43 / .08 | wing_right |
| 尾轮 | (0,2.00,4.52) | (0,−.30,4.52) | .15 / .0425 | tail |

support_normal 是飞机局部中的实际支承法向，例如 `unit_basis.inverse()*carrier_basis.y`。默认 UP 只表示机体水平时的底点。helper 按轮轴 X 的圆周投影和有限轮宽求支承，返回 wheel_contacts_model/flight，含 position_m、centre_m、radius_m、half_width_m、host_part_id、available。configuration 拒绝非有限/零法向及非有限偏转，返回空字典。圆形轮胎未模拟压缩；现有 20 段可见胎面与连续圆周的误差小于 6mm。

机体 UP 时飞行局部底点是 (±1.93,−1.43,−1.27)、(0,−.45,4.52)；**不能把固定底点随机体旋转充当俯仰后的真实接点**。每次用实际法向重新求圆周接点。CPU helper 不读 DM；available 由放轮/放钩决定，OPS 另按真实 DM 状态排除已脱离的 host_part_id。

`parked_transform_flight()` 从三轮圆周解出水平甲板静态姿态：仰角 .168342307rad（约 9.6453°），飞行原点距甲板 1.203077m。`parked_transform_model()` 及模型 `get_parked_transform()` 再包含一次 model-to-flight 平移，供直接摆放纯模型使用。这是静态安装基准；OPS 须解两轮到三轮的连续承载、速度和姿态，不能每帧套静态变换。r1–r4 共面轮点/长尾轮、旧 OPS pitch=0 停放/进近姿态作废；r5–r9 是中间修订，最终消费 r10 哈希。

## 使用状态与活动件

AircraftAdapter 消费真实快照的 `module_data.carrier_ops`：

```json
{"gear_down":true,"hook_down":true,"flaps_down":true,"hook_deflection_rad":0.0}
```

没有 carrier_ops 时收轮、收钩、0° 襟翼。A6M 保留原入口。本模型不发命令、不判断触舰、不移动飞机、不解索、不运行部署计时器。

纯模型方法为 set_landing_gear_deployed(bool)、set_arresting_hook_deployed(bool)、set_hook_deflection(float)->bool、set_flaps_deployed(bool)、set_flap_angle(float)->bool。角度拒绝 NaN/Inf；有限值分别限制为 0..40° 尾钩上偏、0..50° 襟翼。flaps_down 映射 35°，为本轮视觉估值；不宣称真实襟翼在各速度下恒定，吹回/气动行为归 OPS。

四片襟翼沿各片前缘后掠铰链旋转，缓存发生在 DM 宿主原点调整之后。内侧活动片改为 span .78..2.30m、弦分数 .72...99；外侧保留 span 2.30..3.35m、.69...98。原内片从 .46m 伸入机身，.62 弦分数过宽；本轮按原图修正活动面边界及旋转轴，主翼网格/大形不变。轴位与弦分数为工程近似，不复现内部连杆/滑轨。

轮组归各自翼/尾 DM 组，闭合轮盖有独立 Node3D 批处理边界，放轮时关闭；尾钩归 tail。真实断翼/解体带走相应附属部件，碎片保留脱离时状态，重置恢复清洁态。新增接触节点不带炮口 mount_id，六枪查询不变。

## 尾钩与接触

根部纯模型 (0,2.43,4.80)，真实钩鞋底中点局部 (0,−.60,.60)，鞋底边 z=.55...65m。杆端局部 (0,−.40,.60)。自由轴角 +12°，接触上偏从此减去，范围 0..40°。收起轴角 120°、外部组件隐藏且不可抓索，仅为藏入机体的简化状态，不模拟 stinger 内轨。

| 状态 | 纯模型钩端 m | 飞行局部钩端 m |
| --- | --- | --- |
| 自由放下，0° 接触偏转 | (0,1.718364,5.262142) | (0,−.581635,5.262142) |
| 收起，外部隐藏 | (0,2.210385,3.980385) | (0,−.089615,3.980385) |

三轮承载姿态中的自由钩端低于甲板 .251998m。**自由钩与甲板约束钩端须分开。** 静态 CV01 夹具用实际甲板顶+.02m 索高解出约 29.95° 上偏，飞机位置/姿态未动。这不是运行时固定补偿。OPS 依飞机、母舰变换和实际甲板/索高求 hook_deflection_rad，用返回的实际三维钩端/鞋底边扫索，替换临时 4.4m Z 偏移；只比较 Z 或 hook_down 不代表抓索。

渲染诊断 `carrier_usage_model(normal)` 返回实际轮胎/钩端纯模型坐标；`AircraftAdapter.carrier_usage_local(normal)` 返回飞行局部坐标，其 available 检查可见 DM 宿主。供 CPU/渲染一致性对照，不作为模拟依赖；查询不改输入快照、敌情或战果。

## 包络与验证边界

CPU 的 gear_up_contact_proxy 为实际桨心飞行局部 (0,.22,−4.68)、半径 1.995m 的全转动桨盘，**不是全机碰撞体**。原生图的 visible_bounds_aircraft_local 从实际可见三角面测量，含当前使用态和桨相位；单帧 AABB 不是完整转动桨盘。OPS 的未放轮碰撞仍须覆盖机腹等自身代理。

r10 实际 CV01：全桨盘净空 .237296m，35° 襟翼最小 .255595m，50° 最小 .109420m；三轮同时承载，主轮可见胎面离散误差约 4.52mm、尾轮 1.54mm。主体保持、模型、甲板和旧 DM 回归合计 235 项通过。12 张原生图分别覆盖清洁、进近、停放、受约束钩和真实弹药断翼/解体；进近/停放/接触明确标记静态几何夹具，旧 OPS 只保留来源对照，旧承载姿态作废。

参考及逐图限制见 `docs/references/aircraft/f6f5_1944/carrier-usage/modeling-brief.md`。轮/钩/襟翼为照片约束的简化工程近似，不宣称原厂尺寸认证。实际起降闭环、15fps 关键段与 S14/S08/Chrome 集成各自后续验收，本轮未运行 Chrome。
