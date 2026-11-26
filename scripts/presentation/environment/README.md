# S13 白昼云海组件

CloudSeaEnvironment 只管理表现；FirstPlayableGame 装配一次、传入绝对模拟时间，并在正常相机更新后传入观察位置。advance 对相同时间不重复写材质；暂停冻结，倍率沿用模拟钟，重开复用节点/材质并归零。没有 TIME、模拟随机数、天气或水位写入。

天空是方向固定的远景曲面穹顶，水平平移有视差，垂直视差平缓限制以避开高空的薄片交线。它不是实际 6200m 高度的可穿越云体，不提供云碰撞、云影、气象或 AI 遮挡。疏云和微弱的短薄云随 (0.84,0.54) 风向以表现参数 12m/s 移动；日光方向从同一 DirectionalLight3D 的实际变换取得。颜色环境光、禁用环境反射和简化 cubemap 分支降低依赖；不能据此断言引擎完全不刷新辐射图。

海面仍为严格 y=0 的两三角形平面，覆盖整个正常相机范围；没有波高位移或逐浪浮力。原创坡度纹理按风向分三种尺度、速度和距离权重采样，mipmap 与屏幕导数共同退掉高频；低强度解析日光/菲涅耳反光代替复杂反射。海水、岛屿、岸线和单位统一使用 Environment 深度距离雾：4km 开始、60km 达到同一海天色，位于相机 70km 裁面之前。2026-11-11 已移除只让水面按视角变白的雾，避免岛脚出现独立亮带。海面使用简化自照明着色，不接收舰艇实时投影、屏幕反射或物理天空倒影。地图浅水/岸线、舰艇尾迹和弹着水花仍使用原资源和统一水位。

两张 512×512 PNG 均由本项目代码原创烘焙，无照片、生成式图片、购买或下载素材：

| 文件 | 生成方式 |
| --- | --- |
| cloud_noise.png | Godot FastNoiseLite，seed 130707，平滑 simplex，frequency .006，FBM 5 层、gain .45、lacunarity 2，seamless skirt .20 |
| wave_slopes.png | seed 130708，frequency .028，FBM 3 层；同源无缝高度图的周期中央差分，RG 编码有符号坡度、B 存高度 |

PNG 以数据纹理采样，线性 mipmap，禁止 sRGB 转换和法线重编码；颜色 uniform 使用 source_color。生成脚本可经共享锁重复执行：

    python3 tools/verify.py --owner S13-regenerate --timeout 60 godot -- --script res://scripts/presentation/environment/generate_cloud_noise.gd
    python3 tools/verify.py --owner S13-import --timeout 90 import

当前运行证据、Chrome 成本与限制见 docs/showcase/deliveries/S13.md。API 核对依据为 [Godot Sky shader 官方文档](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/sky_shader.html) 和 [Environment 官方文档](https://docs.godotengine.org/en/stable/classes/class_environment.html)，实际引擎固定为 4.7.2.stable.official.ed1daf0bf。
