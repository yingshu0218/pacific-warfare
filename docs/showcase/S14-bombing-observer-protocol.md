# S14 轰炸组合只读观察协议 v2

2026-11-12，供S08准备正常Chrome验收。运行候选为`candidates/s14-bombing/`；尚未公共准入。此文独立于BOMB已冻结元数据，不改其交接文件。

## 注入与成本

在WASM启动前提供`window.S14X.protocol = 2`及下列方法，才启用扩展探针。未注入页面或旧协议不采样、不转换/序列化状态、不转发事件；原生始终关闭。探针只读，不提供推进、命令、瞬移、油弹或伤害写入回调。

实现为`overrides/scripts/showcase/expansion/web_probe.gd`；参考接收器`tools/s14_bombing/measure.js`。状态最多每0.25墙钟秒采一次，记录端再以0.5秒归档；暂停/倍速不改变这一观察节奏。仿真时间、执行与事件继续来自固定tick。`window.S08`可另启原有性能探针；本阶段接收器只保存其稀疏性能样本，不重复保存事件。

## 方法与重开

- `reset(generation)`：每次新世界/重开先发；清空接收端当前指令表及事件去重游标。旧归档可保留，必须带generation，不把不同局的sequence或模拟时刻合并。
- `receive(state)`：紧凑当前状态，不含`session.journal`、完整订单、完整bombing历史/预测或完整damage配置。字段含generation/tick/time_s、pause/speed/pending、ended（直接来自session.ended_reason）、exercise、models/static_models、真实UI/声音/环境时钟、相机与观察标签、效果与draw_calls/node_count。
- `orders_delta({generation,upserts,removed,total_orders,limit:48})`：仅稳定字段变化时发送，优先当前订单，再保留近期终态，最多48条。行含order_id/source/issuer/faction/受令与已分配ID/type/target/intent/status/reason、issued/changed_tick及逐机status/reason/phase。指令距离等逐tick进度不作为重复发送理由。不发送history；接收端合并Map，`latest.orders`是当前重建表，归档只存变更。
- `events(rows)`：每generation按真实sequence只发一次；包括carrier_*、bomb*、实际射击/命中/损伤/脱落/表面接触、指令下达/终态/拒绝。仅保留类型需要的紧凑data字段，不递归附带完整BattleOrder历史；每行自带generation/exercise/sequence/time_s/位置/来源与目标。

常规观战UI的完整指令/执行时间线完全保留。需要详细历史的验收通过正常“指挥态势”查看并截取，或在独立稀疏headless证据中读取；不要恢复每0.25秒传完整Session.orders/journal的方式。

## 模型、轰炸与伤损字段

`state.units[id]`含definition_id/active、真实position/rotation/velocity、fuel、舰载carrier_ops、command_assignment、紧凑aircraft_task；`bombing`仅phase/reason/abort_reason/order_id；`rack`含remaining/released、bay/crutch/brake及逐槽loaded布尔值。`damage`含真实phase、结构/推进/操纵/火灾、detached_parts和最多3个fragment的ID/位姿。不以委托released覆盖crashing/wreck。SB2C未发布预切部件，使用整机终端状态，不能据此声称单侧断翼已完成。

`state.bombs`最多96个真实重力释放弹体的id/entity/slot/position/velocity/forward/up；显示预算不影响模拟。bomb_released、bomb_source_cleared、bomb_contact、bomb_explosion可按projectile_id和sequence关联。命中、漏失、中止和损失均为合法结果，不能只以released数判断完成。

## 普通菜单元数据

`controls`提供segment/unit/speed/carrier中心；`buttons`是当前可见按钮文字到中心坐标。`popups`含visible/count/labels/metadata/selected、position/size、实际row_height与上下padding，用真实鼠标/滚动选择，不通过JS改模拟。

菜单当前顺序：原16段落；16港湾、17航母炮战、18单机甲板、19双机整波、20限制示例、21D4Y/22G4M/23B25静态；24SB2C俯冲、25D4Y俯冲、26G4M水平、27B25舰艇轰炸、28F6F截G4M、29零战截B25。以labels确认后再选，后续若有变化将更新交接，勿仅硬编码序号。

单位数按所选场景变化：旧16仍19，港湾23/单机甲板22；新轰炸/截击为较小的真实战斗编组，静态模型与作战单位分别计数。新场景没有被动防御、无敌或定时投放/损失。截击编组只由FleetPlanner分配，BombingCommander仅接轰炸目标。

最后一次完整Chrome与性能结果应绑定随后冻结的组合清单；此协议不提前承诺浏览器或长期性能通过。
