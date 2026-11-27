# AIR03 · 立体接敌

在正式飞行 AI 中增加轰炸机拦截的高度层次，不靠观战镜头制造机动。战斗机根据本方已识别的轰炸机接触、自身高度和地形余量选择较高或较低的一层。高度接近时用稳定单位标识分配，避免全队每次走同一条高度带。进入时先机动，达到高度差后继续原有连续追踪和开火判定。过近或机动超时会回到普通追踪，不能一直等待；航路净空不足不选低层。目标切换、地形恢复、受损、友机避让、脱离返航继续走现有安全分支。

战斗机之间保留已有立体机动，近距交会后有余量可选偏下的分离方向，下次分离可走原有偏上分支。没有增加命中率补偿、预设命中、伤害调整、历史武器参数或镜头演出指令。

## 验证

Godot 4.7.2 Compatibility。运行：

```sh
godot --headless --script res://tests/test_bomber_approach_layers.gd
godot --headless --script res://tests/test_aircraft_spatial_tactics.gd
godot --headless --script res://tests/test_aircraft_terrain_safety.gd
godot --headless --script res://tests/test_aircraft_combat.gd
```

用正式战局入口和事件采样：原 G4M1 场景中地狱猫首次发射时低于目标约 85 米且在上升；原 B-25J 场景中零战首次发射时高于目标约 158 米且在下降。原场景各自都有实际命中。另用同一 G4M 场景的两个高度变体确认同一机型可从两侧进入，也都产生实际命中。测试高度是这几局的实际样本，不是固定命中位置，也不表示每次拦截必须有命中。

本轮不改命中与伤害基线；未覆盖 Web 性能及本地 Mac。
