# S14 轰炸／截击用户体验版

2026-11-12。已按统筹授权准入普通 `expanded` 入口并构建，最小Chrome启动11项通过。六任务整轮Chrome仍未完成，S08最终长测与性能待验；不将本次可体验交付写成最终验收。

在仓库根运行 `python3 tools/run_first_playable.py web --scene expanded`，用Chrome打开 `http://127.0.0.1:8765/index.html`。需要重建时加 `--build`。

详见 [交付与验证记录](../showcase/deliveries/S14-bombing.md)、`candidates/s14-bombing/final-manifest.json`。旧公共文件、旧普通包与被移除的轰炸模块隔离标记均有备份；本轮测试进程、Chrome、HTTP服务及临时profile已全部清理。
