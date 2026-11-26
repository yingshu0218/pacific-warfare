# S08 2026-11-11 全单位版本证据

普通入口为 `res://showcase/all_units.tscn`，实际访问默认 `http://127.0.0.1:8765/index.html`。结论与启动说明见 [S08 交付](../../../deliveries/S08.md)。本目录所有时间为 UTC，交付日期按 Asia/Shanghai。

| 路径 | 含义 |
| --- | --- |
| `build_manifest.json`、`pack_audit.json` | 普通运行包、396 项准入源码、生成配置、固定模板与产物 hash；444 条 PCK 载荷及 remap 验证。 |
| `plain/` | 无注入的普通用户页面；`S08`/`S14` 均不存在。 |
| `baseline/`、`optimized/` | 同种子和导览规则的实际 Chrome 前后性能对照；热身8秒，1×30秒／2×10秒／4×12秒。 |
| `replay_comparison.json` | 四个固定输入的完整事件流、600 tick 状态与 RNG 对照，证实标量读取优化不改变模拟结果。 |
| `chrome/` | 最终完整真实操作、自然战斗长测、重开、2×/4×；逐秒 `samples.ndjson`、原始 rAF、世界状态/事件、实际输出音频与截图。 |
| `chrome/memory.ndjson` | 仅本轮隔离 Chrome CDP 会话返回的 PID；RSS 和物理占用分别记录，不能与 WASM 容量相加。 |
| `attempt-follow-mode/` | 失败：验证脚本曾错误要求跟随右拖脱离单位，保留实际角度与失败断言。 |
| `attempt-menu-timing/` | 失败：快点击未等可见布局刷新；最终脚本等待新 UI 快照后重新完整运行。 |
| `browser_preflight.json` | 曾等待共享渲染锁超时，无第二个渲染实例；后续成功基准独立记录。 |
| `native_launch.json`、`user_command_http.json` | 新旧原生入口与实际普通构建/服务命令。 |
| `summary.json`、`audio_validation.json`、`cleanup_audit.json` | 分布统计、实际音频解码与本轮进程归属/退出结果。 |
| `source_hashes.json`、`evidence_index.json` | 源码、工具、报告与本目录证据的 SHA256。索引不对自身做循环 hash。 |

复算：`python3 tools/s08/summarize.py`。再验收须先构建普通包，再通过共享锁运行 `python3 tools/verify.py --owner S08-review --timeout 1080 --lock-timeout 60 exec -- node tools/s08/chrome_accept.mjs --evidence=docs/showcase/evidence/S08/review-chrome`。实际 Chrome、现有本机 Playwright 运行时与隔离 profile 均由脚本管理，不需要账号或付费服务。不要覆盖本目录原始记录。

正常包保持观测默认关闭；验收端只注入只读观察器，不直接改变世界、订单或损伤。自然战斗数据与 S14/DM01 已验的受控损伤用例分开，不能用一方替代另一方。4× 画面帧率仍有明确限制，功能检查通过不等于全倍率性能达标。
