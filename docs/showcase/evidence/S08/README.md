# S08 证据索引

2026-11-11 接续的全单位版本证据集中在 [`final-20261111/`](final-20261111/)，对应新的普通用户包、默认 URL、实际 Chrome 原始样本与性能对照。最终结论见[本轮交付](../../deliveries/S08.md)。新旧目录各自记录包 hash，不交叉借用通过结论。

以下为 **2026-11-10 阶段交接的历史索引**，不代表当前全单位版本。完整说明见[阶段交付](../../deliveries/S08-stage-20261110.md)。当时的机器汇总为本目录 `summary.json`；源文件与证据 SHA256 为 `source_hashes.json`、`evidence_index.json`，清理审计为 `cleanup_audit.json`。Safari 仅保留已结束的缺陷诊断，不继续测试。

| 目录／文件 | 用途及限制 |
| --- | --- |
| `clean-baseline/chrome-clean` | 合并前有效 Chrome 连续基线，75 包，首局 1×自动摄影。 |
| `chrome-audio/chrome-audio-fixed` | 本轮最后实际 Chrome 短确认，157 连续包、一次重开，实际播放输出 `audio-1.webm`，截图 `capture-001.png`。不代替长测。 |
| `chrome-audio/process_memory.ndjson` | Chrome 每个命名进程的 RSS／物理占用原始记录，保留扩展等辅助进程，不能直接冒称页面独占或总物理内存。 |
| `chrome_memory_summary.json`、`audio_validation.json` | Renderer 口径说明与实际输出文件的解码验证。 |
| `baseline-chrome` | 早期报告传输缺段，只有 4 包，不作连续性能依据。 |
| `baseline/safari-baseline` | 早期历史 Safari 基线；WASM hook 尚未捕获，不把空列表当 0 内存。 |
| `candidate-before-spatial` | 旧航空、静态合并后候选；Safari 自动内存重载失败，含实际 UI／时间线图和音频。不是最终结果。 |
| `audio-before` | 冻结原生 sample 播放路径，重现播放源／物理内存爆增。 |
| `audio-after` | 仅暂停 guard 的部分修复，仍有增长，保留失败。 |
| `audio-stream` | guard＋Web stream 混音的历史短确认；收到 Chrome-only 指令即结束。 |
| `candidate_pack_audit.json` | 原 341 条候选 PCK 审计，对应其内记载 hash；后续航空／地图集成重建后须重审。 |
| `environment_preflight.json` | 统筹先前只读硬件／应用／模板预检；实际 Chrome UAData 与 buffer 在运行环境记录中。 |

每个报告目录保留 `samples.ndjson`、`environment.ndjson`、`actions.ndjson`、可用的图片／声音及服务器退出审计。`samples` 中的 `serial` 不连续／重置会被汇总显式检测；模拟代数重开与浏览器重载分开计算。普通页面不暴露内部字段，也不需要采样回传。
