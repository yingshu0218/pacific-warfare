# 默认港湾的烟效、双指挥官与舰炮分配

2026-11-19。三个 GPT-6.2 Sol High 项目聊天分别实施烟效、岗位指挥及舰炮分配。统筹在普通 Web 中核对实战效果，并发现重开时可以点到上一局任务。修正版对干净重开和炮烟做了独立复测。 [烟效](FX02.md) · [指挥](CMD02.md) · [炮组](GUN01.md)

## 观看烟效

[9 秒实战视频](../showcase/evidence/2026-11-19-command-and-smoke/harbor-smoke.mp4)并排播放四个真实事件，各格从各自事件发生时开始。四幅画面来自同一次默认港湾战斗的固定观察机位，分别显示大和开火、衣阿华中弹、高炮空爆和炮弹落地。视频保留实际仿真时间和效果大小。另有包括近失水柱与泡沫的[五组拼帧](../showcase/evidence/2026-11-19-command-and-smoke/native-sequences.jpg)。

主炮短闪后有沿炮管方向喷出的褐灰烟，随后烟团留在世界中，沿云海风向抬升、变宽和变淡。舰体中弹时可看见短亮芯与深灰烟，地面弹着扬起土尘，近失弹落水产生水柱与泡沫。防空定时空爆也从实际弹体位置出现，几团深浅不同的黑烟可在天空里共存。外观采用游戏化参数。重复消费同一事件、暂停或重开均有专项测试覆盖。

Ego Lite 中用正常「跟随」镜头观看大和，距离约 408 米，同一轮主炮在仿真 10.58 秒出现短闪、12.73 秒可以看见成团炮烟、14.85 秒已经明显变薄。自动电影也拍到了[舰体命中后留烟](../showcase/evidence/2026-11-19-command-and-smoke/live-ship.png)和[战斗机旁的防空爆烟](../showcase/evidence/2026-11-19-command-and-smoke/live-flak.png)。[开火](../showcase/evidence/2026-11-19-command-and-smoke/yamato-firing.png) · [浓烟](../showcase/evidence/2026-11-19-command-and-smoke/yamato-drifting.png) · [消散](../showcase/evidence/2026-11-19-command-and-smoke/yamato-dispersing.png)

## 指挥与实战

日美各有舰队和航空指挥官。岗位用本方接触和可用兵力独立选择进攻、平衡、保守。进攻时可给更多编队派接敌任务。保守时增派掩护或保留预备队，暂缓新的轰炸派令。已接令的机组按任务、油弹和伤情继续做决定。「指挥态势」显示各岗位姿态、原因与命令执行记录。[Ego Lite 指挥令](../showcase/evidence/2026-11-19-command-and-smoke/flagship-order.png)

选择舰艇可以看到它各炮组的当前安排。浏览器样本的 18.45 秒，大和的主炮对衣阿华、副炮对弗莱彻，防空炮已分担多个空中接触。95 秒独立实战中，两艘战列舰均有不同炮组对不同目标的真实发射，逐炮位核对开火和库存、逐目标核对主炮齐射均一致。为给新炮组分配下的轰炸任务保留自然进场机会，两架 G4M1 的初始位置沿原航线前移 2,020 米。该局得到 24 枚炸弹的离架、接触及爆炸全链，两方战斗机均有实际狗斗射击，也有战斗机对轰炸机的截击射击。 [炮组界面](../showcase/evidence/2026-11-19-command-and-smoke/yamato-gun-groups.png) · [95 秒事件核对](../showcase/evidence/2026-11-19-command-and-smoke/harbor-95s.json)

## 启动与验收范围

```sh
cd /Users/infinity/Desktop/Dev/game-pacific
python3 tools/run_first_playable.py web
```

在 Ego Lite 打开终端打印的本机地址。默认是 [港湾实战观战](http://127.0.0.1:8765/index.html)。想看大和开火，在单位框选择「大和」并点「跟随」。点「收起信息」可给战场留出更多画面，点「指挥态势」可查看岗位与受令编队。终端按 Ctrl-C 停止预览。

第一次 Web 复核时，重开后新局的 00:00 可以点到上局最新变化为 01:05 的旧卡。修正后，首次可点的大和指令在本局 0.67 秒选中，界面显示的最近变化为本局的 0 秒。两次 Web 构建之间仅观战 HUD 的运行代码有差异，表现层、仿真、装备及场景哈希一致。[重开专项](../showcase/evidence/2026-11-19-command-and-smoke/fresh-order-regression.json)

Godot 4.7.2 Stable、Compatibility 和同版 Web 模板导出。审计覆盖 539 项运行输入、670 个 PCK 条目、9 个导出文件。Ego Lite 以普通入口运行至仿真 90 秒，覆盖暂停、恢复、倍速、重开和实际指挥界面。M5／16 GB、1280×720、开启只读探针与采图时，按 Godot 上报的帧间隔统计。1 倍速 131 个帧样本中位数 133.3 ms，p95 为 142.0 ms。4 倍速 264 个样本 p95 为 142.6 ms。这次测量的帧时间高于 33.3 ms 目标。运行时沿用 384 个表现对象的上限，可见的炮弹轨迹、空爆、炮烟与曳光共用这份预算。验收专用的浏览器空间和服务均已关闭。[构建清单](../showcase/acceptance/2026-11-19-dual-command-runtime.json) · [PCK 审计](../showcase/evidence/2026-11-19-command-and-smoke/pack-audit.json) · [Ego Lite 验收与原始测量摘要](../showcase/evidence/2026-11-19-command-and-smoke/ego-acceptance.json)
