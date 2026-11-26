# AU01 零费用、免账号音频代表包

2026-11-10。**17 个原创代表素材、四段 32 秒试听与可复建脚本已完成，自动检查通过。未实际审听，未接入游戏。** 费用 0、注册 0、付费／API／订阅服务 0，无外部录音或网络取材。交统筹复核后再安排 AU02，本轮结束释放名额。

## 可播放试听

均为离线素材审听编排，不是实战录音或历史装备实录。17 个代表素材都出现在四段编排中；不是等响 A/B。

| 内容 | 压缩播放 | 无损对照 |
| --- | --- | --- |
| 舰炮齐射与海面／舰体命中 | [Ogg](au01/preview/01_naval_salvo.ogg) | [WAV](au01/preview/01_naval_salvo.wav) |
| 防空火网 | [Ogg](au01/preview/02_aa_screen.ogg) | [WAV](au01/preview/02_aa_screen.wav) |
| 近距空战与动力变化 | [Ogg](au01/preview/03_dogfight.ogg) | [WAV](au01/preview/03_dogfight.wav) |
| 港湾岸炮与海陆弹着 | [Ogg](au01/preview/04_harbor_shore.ogg) | [WAV](au01/preview/04_harbor_shore.wav) |

[试听说明](au01/preview/README.md)；时间、声像、增益和动力层权重见 [timelines.json](au01/preview/timelines.json)。舰炮片中 15.2–24 秒的燃烧层也是制作编排，不表示游戏已产生该损伤。

## 素材与制作链

- 代表文件：飞机动力 low/cruise/high 3、舰艇 idle/run 2、重炮变体 2、中炮／机关炮／机枪／空爆／水／地／金属命中各 1、火／风／岸浪各 1。合计 8 个循环、9 个单次；地面命中实际为 0.9 秒，其余时长在台账中。
- [生成脚本](../../tools/audio/build_au01.py) 只用 Python 标准库和已安装 FFmpeg；各家族有独立谐波、带限噪声、颗粒、共鸣和包络结构。源与母带各 17 个 48 kHz／24-bit WAV，候选导出为 15 个 48 kHz／16-bit mono WAV 和 2 个 stereo Vorbis。
- [来源说明](../../assets/audio/au01/SOURCES.md)、[配方与种子](../../assets/audio/au01/source/recipe.json)、[生产台账与各层 SHA-256](au01-asset-manifest.json)。全部为原创通用设计音，不标 F6F／A6M／舰炮实录；不新增公开许可，不改变项目整体授权。
- AU01 整包及源／母带各有 `.gdignore`，避免其他板块顺带导入未审候选。AU02 再明确准入所选导出并设置台账中的 `[begin,end)` 循环点；现有运行代码仍使用原占位声。
- [制作计划](production-plan.md)与[计划台账](asset-manifest-plan.json)已撤销付费备选、登录来源及报价步骤，改为硬性零费用、免账号。完整 P0 36 文件仍属规划，本轮不扩量。

## 实测与复建

[独立检查](au01-checks.json)：**674 项、0 失败**。实际读取 WAV、解码 Vorbis，使用 FFmpeg oversampling 估计真峰值；共 0 个削波样本，格式、长度、直流、起音、静音尾和循环边界检查通过。这不是听感验收。

| 项目 | 实测 |
| --- | ---: |
| 17 个候选运行导出 | 4,622,869 B，约 4.41 MiB |
| 生成源／母带 | 各 13,496,428 B |
| 四段 WAV／Ogg 试听 | 24,576,176／3,656,568 B |
| 运行候选最高估计真峰值 | -5.2 dB |
| 四段压缩试听最高估计真峰值 | -2.6 dB |
| 循环导出最大边界单样本跳变 | 约 0.000952 |

同机、同一已记录工具链下，隔离复建的 **59 个音频负载和 2 个 recipe／timeline 文件逐字节一致**。没有承诺跨平台 libm／编码器版本也逐字节相同；隔离重建目录已移除。

复验入口（不是要求用户操作工具）：

```sh
python3 tools/verify.py --owner AU01-build --timeout 180 exec -- python3 tools/audio/build_au01.py
python3 tools/verify.py --owner AU01-rebuild --timeout 180 exec -- python3 tools/audio/build_au01.py --asset-root .local/audio/au01-rebuild/assets --doc-root .local/audio/au01-rebuild/docs
python3 tools/verify.py --owner AU01-check --timeout 180 exec -- python3 tools/audio/check_au01.py --compare-manifest .local/audio/au01-rebuild/docs/au01-asset-manifest.json
```

## 失败修复、限制与清理

- 首次编码因 FFmpeg 缺 libvorbis 退出；适配已装 native Vorbis、quality 6（编码器标 experimental），未安装依赖或使用服务。保留无损 WAV，并记录实际解码、压缩误差、峰值和接缝。
- 首次检查发现地面命中多余静音尾，缩至 0.9 秒后通过，未放宽阈值；[失败记录](au01/evidence/initial-check-failed.json)与[首次通过记录](au01/evidence/first-passing-check.json)均保留。
- 一次等待 S13 共享锁超时退出 2、未启动子进程；其后仍走同一锁。最后一轮在统筹收尾消息前已启动，仅补燃烧覆盖与时间线哈希，随后未扩大制作或检查。最终包装报告：[20261110T155113-d58c836d](au01/evidence/verification/20261110T155113-d58c836d/report.json)。
- **代理没有可靠直接听音能力，未实际审听。** 波形／频谱／格式／重建检查不代表音色、疲劳或混音平衡通过；有损环境变化可对照 WAV 审查。不要求用户逐文件批准。
- 没有启动 Godot、浏览器或 HTTP，没有修改运行音频系统、first_playable、S13 或其他板块。AU02 接入、真实事件／动力同步、空间声源池及 Chrome 有声长测均未完成；固定 Godot 4.7.2、仅 Chrome 规则保持。
- [清理记录](au01-cleanup.json)：8 份包装记录已归档；7 个有子进程的已记录进程组均不存在，包装清理成功。隔离重建目录已清除；`.local/audio/au01-before` 只保留原规划恢复副本。原 bank、effects、first_playable 与旧 SOURCES 四份只读基线文件起止哈希一致，未触碰用户窗口。

完整当前文件索引见 [au01-files.json](au01-files.json)，各音频负载哈希另在生产台账中。
