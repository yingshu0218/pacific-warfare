# S13 雾带修正

2026-11-11。用户指出海面的雾像把岛屿与海面分割。原因是水面 shader 按视线角度单独变白，而岛屿、浅水和单位使用另一套距离雾；低视角的附近水面也被过度提亮。

已移除 ocean.gdshader 的角度雾与独立距离雾，恢复原生 Environment 雾处理。CloudSeaEnvironment 让海水、岛屿、岸线和单位共用同一条距离曲线：4km 开始、60km 完成，使用同一海天色，早于 70km 相机裁面。近岛处保留海色，远海仍可连续接入天空。没有修改地形、单位、UI、水位或模拟，也没有增加后处理或新节点。实现依据为固定引擎的[Compatibility 雾计算源码](https://github.com/godotengine/godot/blob/ed1daf0bf/drivers/gles3/shaders/scene.glsl#L1847)。

修改前的局部恢复副本在忽略目录 .local/s13-fog-before/。原 S13 冻结画面、运行包与索引保留；新 Web 包单独写入 build/s13-fog-web。

## 同镜头实拍

[前后对照](../evidence/S13/fog-fix/comparison.png)、[修改前](../evidence/S13/fog-fix/before/)、[修改后](../evidence/S13/fog-fix/after/)。已实际查看舰侧、舰队远景、港湾、高空飞机及 5800m 高空图：独立亮带消失，岛脚与海面衔接更自然，未重新露出海面边界。

[原生拍摄记录](../evidence/S13/fog-fix/after/native_capture.json)包含 48 张实际连续帧，覆盖舰侧、岸线和高空缓转，按 6 tick/帧推进，共 4.8 模拟秒。运行源码起止 hash 一致；暂停后整帧像素不变。未把这些离线连续帧当作游戏帧率。

## Chrome 与归档

本轮采用新构建包、真实 Chrome、M5/16GB、1280×720，沿用已有 Playwright 检查路径；没有启动 Safari。仅做本次修正的短测，不替代 S08 十分钟或最终规模验收。

[Chrome 原始记录](../evidence/S13/fog-fix/chrome/run.json)、[验证汇总与清理](../evidence/S13/fog-fix/verification.json)、[新源码与证据 hash](../evidence/S13/fog-fix/evidence_index.json)记录本轮实际结果。页面身份、非空画面、控制台、暂停像素、真实 4× 菜单及三次重开沿用同一检查；全部临时资源在结束时清理。本轮 16 项检查全部通过，控制台/着色器错误为零。舰侧/高空各采样 8 秒，rAF p50 均为 8.3ms，p95 分别为 13.095/10.4ms，平均约 117FPS；全部样本 visible/focused。6 份包装报告全部通过，11 个实际进程组均已退出。

归档时，并行 S10 已继续修改共享 first_playable.gd；差异单列于 verification.json，没有覆盖其改动。此次两个 S13 生产文件在原生、Chrome 包和当前工作区的 hash 一致。隔离 Web 的标题、入口和视口配置差异也明确保留；本记录不冒充 S10 合并后的最终集成成绩。

共享验证锁下的原生复验：

    python3 tools/verify.py --owner S13-fog-review --timeout 90 godot --render -- --script res://tests/cloud_sea_capture.gd -- --continuous --short-sequence --evidence-dir=res://docs/showcase/evidence/S13/fog-fix/review

海面与岛屿仍为简化表现；本次仅修正雾化衔接，未增加体积云、真实浪高或复杂反射。
