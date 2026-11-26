# FX01 / DM01 效果消费接口

2026-11-11。FX01 制作中，当前仅 FX01 修改 CombatEffects；DM01 先按本契约发布模拟读模型，集成须待 FX01 冻结。全部坐标米、时间秒，表现不写模拟、不使用 world.rng。

## 既有入口

`advance(simulation_delta_s)` → `consume(events, generation)` → `apply_snapshot({units})` 保持现有调用次序，不修改 first_playable。事件按 generation + sequence 去重。按 BattleEvent.time_s 计算新效果与曳光年龄，批量消费中的旧发射/终止保持顺序。暂停 advance(0) 不移动、不淡出；倍速仅使用实际模拟时间。

revision3：advance 只推进既有瞬态效果；持续烟火在 apply_snapshot 使用本帧姿态生成，不能在 advance 读取上一帧锚点。kind=fire 的持续部位火焰由 entity_id＋局部锚点跟随本帧机体，生命周期内也不留在旧世界位置；烟片继续留在实际历史轨迹。每帧4tick、96.2m/s、46帧含转向的检查中，82个仍在寿命内的火焰锚点样本与新烟源均为0米位姿误差。现有调用方无需新增参数或改变顺序。

revision3 patch2：云/雾/火焰的UV边缘严格淡到零；水雾另按片元实际世界高度在y=0海面前淡出，避免大面片被不透明海面从遮罩内部截出一条水平硬边。保留海面本身的深度遮挡和统一水位，不修改云海/地图 shader。烟、尘、火焰使用更窄的同类水位淡出带，触海事件仍负责主机体烟源终止。

- `surface_impact` 且 data.surface=sea：实际 position_m 为水柱基部，沿 y=0 升起、回落，薄雾与泡沫在同一有限网格池中。
- `airburst`：机械 time_fuze 生成较大的深灰烟团；reason=tracer_self_destruct 仅显示小闪光与小烟团。FX01 不推断目标，不改8.5秒M1自毁时间或任何伤害半径。
- `fired`：仅 data.tracer=true 抽样弹丸显示短尾，使用 position_m、velocity_mps、gravity_mps2 与 event.time_s。hit/airburst/surface_impact/projectile_expired 立即停止该 projectile_id 的曳光。发射者退出不删除已经在飞的弹迹。
- `unit_impact`：仅消费 S05/DM01 由真实表面接触归一化的事件；data.surface=sea 时按 size_m 生成有上限的大范围落水，ground/building 生尘。不会在 crashing 开始时提前播落水，不自行宣布损失。海面接触后停止该主机体的新空中烟火，旧烟按寿命消散；离场与 generation clear 同样清理发射状态。

## 持续部位烟火（可选读模型）

默认保持 `module_data.damage.fire` 与型号既有 fire/smoke_anchor_m。为 DM01 预留 `module_data.damage.effect_emitters: Array[Dictionary]`；字段存在时完全替代默认的 fire/crashing 发烟，空数组表示不发烟，防止双重浓烟。每单位最多消费前4个条目，所有条目仍受同一实际网格池上限约束。

```gdscript
damage["effect_emitters"] = [{
    "id": "engine_smoke",        # 本单位内稳定ID，供审计
    "part_id": "engine",         # 只作来源标记，不在表现重新判伤
    "kind": "smoke",             # smoke / fire
    "anchor_m": Vector3(0,.6,-2.5), # 单位局部坐标，也接受3元素数字数组
    "intensity": .8,              # 0..1，必须来自真实部位/火情状态
    "size_m": 2.,                # 视觉直径，表现限制0.2..8米
    "enabled": true
}]
```

锚点由复制快照的 position_m/rotation_rad 变换；烟片留在产生时的世界位置并随固定视觉风漂移，不能贴屏幕或跟着飞机整体平移。左右翼脱离件由 DM01 独立表现管理；FX01 不追踪 Node/碎片引用，不伪造部位损伤事件。发动机失效如需持续烟必须由 DM01 显式给上述读模型，单纯降低动力不自动生成爆炸。

移动烟源按实际锚点位移触发发烟，静止烟源最长0.3秒补发一次；每次最多16个距离/时间插值样本，烟片沿真实轨迹方向有限重叠，避免150m/s飞机形成45米间隔或让最近一段烟落后于机体。所有样本均计入同一个144槽默认实际网格池；饱和时新烟可回收最老的同类烟，水柱/空爆仍优先。暂停不补点；离场、触海后不再消费该主机体烟源，generation clear 清空轨迹历史。

原有音频接口、Web STREAM 与宿主的幂等 stream_paused 路径保留；ground 不分配发动机循环，propulsion_factor<=0.001 的失效发动机停止循环，即使飞机仍 active、继续滑翔。健康舰机保持原声音行为。本任务不接 AU01 候选音源。实际网格分配/显示、材质数、丢弃/抢占统计由 statistics() 提供，显示满池不影响弹药或伤害。
