# 统一验证入口

S01 工具入口已建立，2026-11-10 继续补齐模拟契约及实际验证记录。所有聊天使用同一个 `tools/verify.py`，不要直接并行启动 Godot。当前 S01／S02 已获统筹授权共用互斥入口；后续执行权由统筹分配。锁竞争自测需统筹安排独占时段，避免影响其他聊天检查。

```sh
python3 tools/verify.py --owner S01 version
python3 tools/verify.py --owner S01 --timeout 90 import
python3 tools/verify.py --owner S02 --timeout 60 test res://tests/test_weapon_motion.gd
python3 tools/verify.py --owner S02 --project iowa test res://tests/test_mount_assembly.gd
```

macOS 优先使用可执行的 `/Applications/Godot.app/Contents/MacOS/Godot`；Linux 从 `PATH` 查找 `godot` 或 `godot4`。多版本并存或可执行文件未加入 `PATH` 时，使用 `--godot /path/to/godot`，放在子命令前。路径发现不会放宽下方的版本检查。

Linux 云沙箱的用户目录不可写时，在同一个终端会话显式指定可写的 XDG 目录（不改 HOME；导出模板仍需另行按固定版本准备）：

```sh
GODOT_USER_DIR="$(mktemp -d)"
export XDG_CONFIG_HOME="$GODOT_USER_DIR/config"
export XDG_DATA_HOME="$GODOT_USER_DIR/data"
export XDG_CACHE_HOME="$GODOT_USER_DIR/cache"
mkdir -p "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_CACHE_HOME"
python3 tools/verify.py --owner cloud-baseline --timeout 180 import
python3 tools/verify.py --owner cloud-baseline --timeout 120 test res://tests/qingjia/test_observer_menu.gd
```

每个 Godot 操作先检查完整版本字符串 `4.7.2.stable.official.ed1daf0bf`。默认 headless；包装器的 `import` 使用 headless editor 模式导入，不创建编辑器窗口。固定 Compatibility 的工程配置保持不动。

锁位于 `.local/validation/godot-render.lock`，使用内核 `flock`；PID、所有者、调用身份、获取与释放时间可核验。沙箱禁止 `ps` 时保留 PID、调用参数、启动时间与随机 token，内核锁仍有效。锁文件保留，但进程退出后内核自动解锁，不按文件存在或 PID 文本阻塞。禁止删除锁文件或换路径绕过互斥。等待默认 15 秒，`--lock-timeout` 可调整；等待超时退出 2，不启动子进程。

日志和 JSON 报告在 `.local/validation/runs/<run_id>/`，命令返回报告绝对路径。每个子进程独立 session/process group；成功、异常、超时均在 finally 回收本次进程组。非零退出、`SCRIPT ERROR:`／`ERROR:`／`USER ERROR:`／`FATAL ERROR:`、超时、清理失败均返回非零。只清理自身创建的组，禁止全局 `killall`。

Codex 受限沙箱内导入可能因 macOS 系统证书或 Godot 编辑器设置写入产生 ERROR，即使引擎退出 0 也应判失败。本轮按同一包装命令使用 `exec_command` 的 `sandbox_permissions=require_escalated` 复验成功；不改 HOME、不屏蔽诊断。普通本地终端执行上述命令无需这些工具参数。新报告包含 wrapper_pid、获取锁时的 PID／身份／token 和各子进程组。

未来 Web 导出或原生截图可复用相同入口（仅获准实机验证后运行）：

```sh
python3 tools/verify.py --owner S08 --timeout 120 godot -- --export-release Web .local/web/index.html
python3 tools/verify.py --owner S02 --timeout 30 godot --render -- res://path/to/capture_scene.tscn -- --capture /tmp/capture.png
python3 tools/verify.py --owner S08 --timeout 60 exec -- python3 tools/owned_browser_check.py
```

`godot --render` 是显式开窗选项；调用场景必须截图后自行退出。`exec` 可包装后续验证脚本，但浏览器标签等外部会话仍由该脚本建立专属会话并在 finally 关闭；进程组清理不能代替标签归属管理。HTTP 服务、浏览器驱动不要脱离本次组或启动无归属的后台进程。

包装器故障分支检查：`python3 tests/test_verification_wrapper.py`。该测试自己竞争同一锁，不能再套在 `verify.py exec` 内；测试顺序运行，不与其他验证并行。

恢复点：`.local/snapshots/S01-before-20261110/project.tar.gz`，逐文件 SHA-256 在同目录 `manifest.json`。归档已逐文件回读核验，保留两个相对软链接；排除缓存、导出、备份自身与凭据。恢复时先解压到独立临时目录核对，按需恢复文件；不要直接覆盖并行聊天的新工作。

S01 最短机制复验（只跑该板块及独立既有武器，不依赖正在迁移的旧大和测试）：

```sh
python3 tools/verify.py --owner review-S01 --timeout 60 test res://tests/test_simulation_definitions.gd res://tests/test_simulation_clock.gd res://tests/test_simulation_commands.gd res://scripts/naval/audit_usn_bofors_40mm_quad.gd
```

最终通过报告：`.local/validation/runs/20261109T181704-3e76641d/report.json`。目录时间用 UTC（本地为 2026-11-10），不要把前一日的 UTC 文件名误认成旧测试。各故障分支和恢复核验详见 `docs/showcase/deliveries/S01.md`。
