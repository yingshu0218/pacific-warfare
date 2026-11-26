# CV01 · USS Essex CV-9 · 1944-04-15

状态：独立模型与甲板接口完成，待统筹实际验收；未注册、未接入S14。纯模型入口 `res://naval/essex_cv9_1944_04_15/essex.tscn`。根工程固定Godot4.7.2 Compatibility；默认入口不变。本目录整体是可排除的开发资源边界。

`modules/` 分开舰体、机库外壳、飞行甲板/升降机、舰岛/承载塔、平台及装备。`weapons/` 是本舰缺少的 Mk32 双联与 Mk24 开放单装变型；40mm复用现有合格Mk2 Mod5，20mm复用S03。没有复制或修改既有舰艇、F6F或SB2C资源；参考图不参与运行。

实例加入树完成ready后：

```gdscript
visual.apply_state({"position_m":Vector3(10,0,20),"rotation_rad":Vector3(0,.2,0),"active":true})
visual.apply_weapon_state("dp_51",{"train_rad":-.4,"elevation_rad":.3})
var sockets: Array[Dictionary] = visual.mount_sockets()
var muzzle: Transform3D = visual.muzzle_transform_global("dp_51",0)
visual.apply_equipment_state("elevator_port",{"height_m":12.0})
var deck: Dictionary = visual.deck_definition()
var surface: Dictionary = visual.deck_surface_at(Vector2(-17,-20))
```

弧度、+X右舷/+Y上/-Z艏，1:1米制，水线全长中点原点；train相对各炮位零向、正X俯仰抬炮。`gun_elevations_rad`可逐管更新。模型不推进库存/火控/航行/飞机或随机损伤；机械显示角度不代表可对任意方向开火，实战遮挡和安全射界由现有战斗系统负责。各实例状态独立，数据getter深复制，无`class_name`污染当前全局类。

`collision_proxies()`输出局部粗包围盒与部位ID，供集成方选择现有碰撞算法；不是精确舰体型线/装甲终审。甲板真实轮廓、升降机孔和活动表面是`deck_surface_at`与当前网格的共同事实；舰岛和炮区障碍见`deck_obstacles()`。返回高度可能为下降后的机库标高，调用方必须检查高度、完整飞机包络和占用，不能仅凭`supported=true`当作安全飞行甲板。见[共同契约](../../docs/carrier-deck-contracts.md)。

主炮固定4座双联+4座单装，12管5in/38；专用AA游戏5座四联40mm+12座单装20mm。历史/游戏配置分开保存在`data/assembly.json`。历史近似、原图和逐座清单见[资料卡](../../docs/references/ships/essex_cv9_1944_04_15/modeling-brief.md)。精确Mk32 Mod号和武器性能未借模型任务定稿。

静态场景`inspection/inspection.tscn`放入真实尺寸2架F6F与1架SB2C，纯验证甲板装配；F6F/SB2C当前没有本任务可消费的完整折翼状态，本任务不修改它们。折翼区是语义区域，不能据此宣称折翼/航空作业完成。展开SB2C比中线升降机宽，不认证其完整翼展包络可随台升降。

原生检视运行、测试、导出与Chrome都使用`tools/verify.py --owner CV01`，有超时/归属/清理。最终命令和证据见[交付](../../docs/showcase/deliveries/CV01.md)。
