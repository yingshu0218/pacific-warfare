# S08 扩展包验收工具准备

2026-11-12。**仅完成独立工具准备及protocol 2离线适配，未运行 Godot、导出、HTTP、Chrome或长测，扩展包未验收。**

本目录不修改 Session、World、S14运行代码、白名单、普通启动工具、旧S08工具或 `build/first-playable`。旧19单位的性能与通过结论不用于新包。港湾阶段1×短样本P95约41.6ms、4×回收段约108.4ms仅为已有诊断。

## 最终交接后绑定

`contract.template.json` 保持 `awaiting_final_admission`，入口、菜单ID/标签和新场景数量均未猜定。**模板直接传给审计会以2退出；默认运行Chrome脚本仅显示准备状态，不加载Playwright、不创建服务。**

根另次释放实跑后，用最终文件创建独立 `contract.final.json`，至少绑定：

1. 统筹正式准入记录和SHA256、最终runtime清单和SHA256；`expanded`具体场景入口、普通页面标题、原 `all`仍保留。
2. 普通构建清单及SHA256、普通PCK SHA256、实际stage/frozen目录；四型飞机/炸弹挂点、甲板、地图/阵地JSON等必备资源的精确路径。
3. S14最终只读探针源码路径/哈希来源、实际global名称及字段。`receive-events-v1`适配见下节，可在本目录按冻结契约替换。运行侧由S14独占；此工具不自动修写其探针。
4. 四型攻击任务和两组截击的最终可见菜单标签或metadata、各用例对应的真实单位/任务状态字段及事件名、正常UI按钮和时间线字段。四型入口不等于四型都投放成功；SB2C组合场景按下述真实中止结果取证。按实际冻结值填写 `cases`，不沿用候选24项菜单的索引。
5. 本地现有Chrome与Playwright模块路径。准备时Browser插件不可用；正式实跑前重新核对工具可用性。有Browser插件时先遵循其工作流，不能因为本脚本存在就自动忽略它。没有插件时才用现有实际Chrome的Playwright运行时；不安装新依赖，不启动Safari。

`status: released_for_s08` 是最终输入契约标记，不是本聊天自行宣称已获公共准入。SHA256全部实读验证，不能仅把模板状态改掉就启动。

## 只读协议适配与有限归档

已只读核对 `candidates/s14-bombing/evidence/inputs/combination-r5/scripts/showcase/expansion/web_probe.gd` 与 `inputs-combination-r5.json` 的对应哈希。该阶段生产端要求 **`window.S14X.protocol === 2`**，工具现支持数字 `probe.protocol: 2`：

- `reset(generation)`：重置当前观察代次，清除旧单位状态、订单窗口、事件去重与计数；重复同代reset幂等，旧代reset/状态/订单/事件不能覆盖当前代。
- `orders_delta({generation,upserts,removed,total_orders,limit})`：原子应用订单新增/更新/移除，以生产端实际limit为窗口上限；最新可见缓存从 `__S08X.latest.orders`读取，`orders_meta`保留生产端报告的总数、上限与当前缓存数。removed只表示退出探针选择窗口，不表示Session删除命令；正常UI仍保留完整历史。相同增量不反复归档，非法/相互冲突/超限增量明确失败，不悄悄驱逐条目。
- `receive(state)`：接收真实紧凑状态，关联同代订单窗口；无需在每帧重复完整订单/日志。protocol版本不符或scene消息缺少reset会失败。
- `events(rows)`：用真实generation＋sequence去重；不要求连续或按到达顺序排列，以免漏掉稍晚抵达的S08指标中的独有事件。同代同sequence但kind矛盾明确失败。scene与metrics重叠只记一次；跨代sequence重新使用仍保留。事件突发一次绑定写入，NDJSON仍逐事件一行，避免正常多事件批次被误判为多个未完成写入。

独立的 `S08.ui(state)`／`S08.accept(metrics)`继续保留，旧 `receive-events-v1`亦保留离线兼容。若新代辅助UI/metrics先于scene reset抵达，旧缓存先失效，随后同代reset不抹掉已收到的新代辅助证据。rAF缓冲不随generation清除，重开造成的真实慢帧照常归档。

上述只是r5阶段协议适配，**不是最终整包准入**。模板 `probe.protocol`、global、菜单及包哈希仍未绑定，只有最终根交接确认后才填写。r5紧凑state尚无真实ended字段；根已交S14补入，工具继续要求最终 `bindings.ended`，不以空值代替。适配器禁止传入任意JavaScript表达式、模拟setter或注入战损。

- 状态：真实generation/tick/time/speed/paused/ended/sound、单位位置/实际任务状态、当前可见控件与popup几何、实际双方命令与逐成员状态。`bindings`是相对于 `state` 的字段路径。
- 事件：带真实 `generation`、`sequence`、`kind`，使用原事件序列去重，不能由镜头或工具写入命中/投弹结果。动作必须通过真实可见菜单、按钮或按键。
- 指标：真实渲染/节点/弹丸/FX/残片/活动数、实际引擎帧或模块计时（有则记录）；缺失口径保留为空，不能写0冒充测量。
- 最终探针应为轻量状态＋增量事件，保留正常UI完整历史的能力。**JS端去掉归档中的history不能抵消Godot端重复序列化的成本。** 契约暂要求 `compact-state-and-event-deltas`；若最终协议不同，先按根交接更新适配与可比性说明。

归档为逐行NDJSON：原始rAF、状态、订单状态增量、去重事件、指标、音频能量、仅CDP所属PID的内存。`run.json`保存摘要和操作结果，不嵌入全部历史。页面只留最新状态、当前订单缓存、有限事件ID和约1秒帧缓冲。单记录默认256KiB、输入包1MiB、待写队列8MiB、总NDJSON128MiB，所有上限显式配置；超限立即标记失败/不完整，禁止悄悄删掉慢帧再给通过结论。截图和8秒录音分别有限保存，不录长片。

## 参数化实际操作

`cases`中每项必须有唯一 `key`、一个功能分组、所覆盖 `features` 和 `steps`。分组名只描述验收要求，不是生产菜单ID。当前模板的cases为空。

| 动作 | 参数与验证 |
| --- | --- |
| `menu` | `menu`为最终popup字段；`label`或`metadata`二选一，在真实菜单中唯一查找。使用实际行高/边距/位置并真实滚动，几何不可达即失败。 |
| `button` | `label`为真实可见按钮文本；每次点击后等待新的UI快照。 |
| `control` | `path`为探针中的真实控件中心，例如最终确认后的时间线行位置；不直接调用其处理函数。 |
| `key` | 实际键盘输入，例如 `KeyR`；可给实测空白区域 `focus:[x,y]`。R必须观察generation真实增加。 |
| `wait` / `checkpoint` | `conditions:[{path,op,value}]`，路径从 `{state,ui,metrics,tallies}`读取；只支持eq/gte/gt/contains/truthy/falsy，不eval。checkpoint另存真实UI/状态快照。 |
| `sample` | `seconds`、可选唯一 `name`。`active:true`要求整个区间1×、未暂停/未结束、同一generation、快照不断流；最后核真实tick增长与单位位置变化。 |
| `pause_check` | 用户已启用声音且已暂停之后调用，1–10秒；核tick不变及声开状态保留，音频RMS在独立汇总中核验。 |
| `screenshot` | `name`只用小写字母/数字/下划线，实际PNG与本用例关联；需人工打开检查画面，不能只看文件存在。 |

需覆盖双方命令、选择执行明细/定位、四型实际任务进展与结果、两组战斗机拦截/受扰/中止或实际未截获结果，以及声音、暂停、慢放/2×/4×、重开和结束。投弹/命中/损失只读；不要求每局必命中或必击落。

**本次组合的结果边界**：主要新增场景为B-25／D4Y／G4M实际投放和两组实际拦截；应取证真实接近、完整离架、弹道与弹着/漏失、实际损伤及后续任务。SB2C普通移动舰目标场景已由根交接为**实际高度不足而中止、炸弹库存未扣，之后受损坠海**；该用例保留 `sb2c_bombing`分组以覆盖入口，但验证真实中止原因、保留库存及损伤/落水链，不能等待或强求`bomb_released`来制造通过。SB2C成功离架只有既有BOMB单项证据，不能挪作本组合/普通Chrome投弹成功证据。最终本包实测仍应与冻结源码和真实事件逐一对应。

低油/空载/失去目标、唯一任务写入者和SB2C旧DM等机制结论应与S14最终同版报告关联，不冒用旧夹具或靠UI标签证明机制。

自然1×至少600秒累计有效活动、至少3次真实R；用若干活动区间与重开动作组成，不把已结束的静止页面计入。旧训练/静态模型/`all`兼容与双机两波次应按根最终交接的已验范围和新增风险安排，不重复整套机制、也不将未通过项目写成通过。

## 普通页与观测页分开

1. 普通页 `plain`：先访问普通默认URL，核无游戏探针global并截未加游戏观测的普通画面；然后仅用浏览器rAF被动采样。不会创建触发Godot探针的global，不安装WASM/音频钩子。保留入口/PCK/硬件、实际buffer、DPR、原始全部rAF及所属PID内存。普通页的仿真tick/WASM容量不可见时标不可用。
2. 观测页 `observed`：启用绑定的只读协议，8秒热身后先测与普通页同默认入口/质量/名义墙钟区间的45秒，再进行实际菜单/任务/长测。每秒记录真实仿真端点、请求与实效倍率、积欠、负载和实际音频。
3. 两类结果并列。普通页和观测页不一定逐帧处于同一镜头位置，不机械相减称为纯探针成本；观测开启页也不能全部称为普通游戏开销。每次记录种子/入口/场景/相机和时间范围；缺失状态时明确不可证。

`summarize.py`按每个采样区间的真实浏览器起止时间汇总，输出**所有帧**与可见帧两种分布、p50/p95/p99/最大值/>33.3ms/>50ms比例。隐藏/失焦与无效样本另列；不筛掉截图、重开或真实慢帧以达标。性能结论与功能通过分开，目标仍为p95≤33.3ms，不沿用旧包20.3ms。WASM保留容量、JS heap、各自Chrome PID的RSS/物理占用分别记录，不能相加。

## 后续实跑顺序（本轮未执行）

1. 根正式准入并明确释放验证槽后，复核当前源/包清单。实际普通启动目标为 `python3 tools/run_first_playable.py web --scene expanded --build`。这条命令自身使用verify锁；不要包进另一个持锁verify再运行，防止嵌套锁。普通命令路径验证用有界 `--seconds`，抓默认HTML/PCK之后停止该预览，保留命令/包哈希和退出证据。
2. 填好最终契约后执行纯文件审计：

   ```sh
   PYTHONDONTWRITEBYTECODE=1 python3 tools/s08_expansion/audit_pack.py --contract FINAL_CONTRACT
   ```

3. 分别串行执行plain与observed。必须由verify直接启动Node；服务由该次runner自己创建，默认127.0.0.1:8765，不连接或关闭用户已有窗口。示例中的契约/新证据目录须替换，当前不可执行模板：

   ```sh
   python3 tools/verify.py --owner S08-expanded-plain --timeout 1250 --lock-timeout 60 exec -- node tools/s08_expansion/run_chrome.mjs --execute --contract=FINAL_CONTRACT --mode=plain --evidence=candidates/s08-expansion/evidence/NEW_PLAIN
   python3 tools/verify.py --owner S08-expanded-observed --timeout 1250 --lock-timeout 60 exec -- node tools/s08_expansion/run_chrome.mjs --execute --contract=FINAL_CONTRACT --mode=observed --evidence=candidates/s08-expansion/evidence/NEW_OBSERVED
   ```

   runner自身默认1200秒上限；最终任务/OPS时长如需调整，根提供合理预算，verify上限比内部多约50秒，最大不超过本工具3600秒限制。不得改真实完成条件或加速飞行状态来赶时间。

4. 用 `python3 tools/s08_expansion/summarize.py --run-dir NEW_RUN` 复算，打开实际截图，离线解码实际输出录音并记录来源。保留错误尝试。审计本轮wrapper报告的PID/进程组、CDP返回PID、profile和HTTP退出，再冻结工具/源/包/证据哈希。工具关闭自身context/server/profile，异常/SIGTERM/SIGINT亦走finally；包装器负责自己创建的进程组兜底。清理失败就是未完成，不能仅凭finally字段宣称全部进程已消失。

## 本轮离线检查

```sh
PYTHONDONTWRITEBYTECODE=1 python3 tools/s08_expansion/test_tools.py
node tools/s08_expansion/test_observer.mjs
node --check tools/s08_expansion/run_chrome.mjs
node --check tools/s08_expansion/observer.mjs
```

全部只用临时合成JSON/PCK、Node VM和本地文件，不启HTTP、不导入Playwright、不接触模拟。候选资料只读快照、保护文件前后哈希、实际检查输出与接续状态见 `preparation/`。测试通过仅证明工具组件，**最终适配、实际可见菜单、浏览器清理和新包性能仍待最终契约后实测**。

本次有界protocol 2接续只运行以下针对性检查，未重跑上面的旧整套检查：

```sh
node tools/s08_expansion/test_protocol2.mjs
PYTHONDONTWRITEBYTECODE=1 python3 tools/s08_expansion/test_protocol2.py
node --check tools/s08_expansion/observer.mjs
```

结果与来源快照见 `preparation/protocol2/`。模板拒绝、输入哈希、600秒/三重开、33.3ms目标、慢帧保留和原有字节预算均不放宽；当前仍待最终准入和另次实跑授权。
