# 大和号外观风格预览 v03

日期：2026-11-10。工具：内置 Image Gen，使用 imagegen 技能；未使用 CLI／API 脚本。输出：[大和号外观预览 v03](yamato-outer-form-preview-v03.png)。

## 目标与输入

用户认可 SB2C-4 v04 的“还原外观大形、简化表面与机构”，要求按同一套标准生成一张大和号供查看。本张延用 `simplified-historical-v0.2`，只验证军舰方向的简化风格。

生成后的最新要求：舰体与上层建筑外观形状须一致，主炮、副炮的编制和位置必须完全符合；专用防空炮数量允许按游戏需要规划。因此本图保留为风格草稿，舰桥形体、主副炮编制和位置尚未验收，不能用于定稿这些几何。后续模型及目标图必须按[军舰规范](../../../../standards/ship-modeling.md)执行，不能用生成简化掩盖炮位错误。

1. [田宫 78030 整舰成品照片](../images/tamiya-78030-full-model.jpg)：全舰轮廓、体量、桥楼和主要炮塔的直观参考，已打开检视。来源为[田宫官方产品页](https://www.tamiya.com/english/products/78030/index.html)。参考套件为晚期大和，不能用其小口径炮位证明本项目 1944 年 4 月配置。
2. [SB2C-4 v04](../../../bombers/sb2c/target/sb2c4-outer-form-candidate-v04.png)：仅约束简化程度、材质和普通照明，不移植飞机形体、涂装或标识。

项目的舰别日期和装配约束仍见[1944 配置记录](../../../../configuration-1944.md)及[军舰建模规范](../../../../standards/ship-modeling.md)。这张图片未完成该配置的逐阵位转换，不能作为“1944 年 4 月复原图”使用。

## 图像检查与适用范围

- 全舰舰艏、舰艉与主桥均在画面内；灰色舰体、简洁木甲板色块与红褐下船体保持大色面。
- 保留三座大型主炮塔、单烟囱、前桥及前后副炮的主要空间层次；前副炮较早期候选更接近桥前中线的关系。
- 舰体表面、甲板、炮室省去密集刻线、细孔与小机构；不再有展示底座、铭牌与复杂布景。
- 此图仍有生成近似：舰桥分层与绝对比例、桅杆完整性、炮管遮挡及数量辨读、小型炮位配置、舰艉设施均未逐项通过。不得把删减重要装备、改变轮廓或未知连接当作用户认可的简化要求。
- 可用于讨论整体外观与表面复杂度；不能量取尺寸，也不是完整建模资料包、历史验收结果或 Godot 实机截图。未修改游戏模型，未运行引擎／浏览器测试。

前两次候选存在前副炮舷侧化、圆柱堆叠或过度删减小炮等问题，未选为参考。v03 回到原始整舰照片重新约束大形，避免只在有误的生成图上继续修饰。细节与炮位问题在真正建模阶段按原始资料校核，本张不继续扩大为精修舰模任务。

## 实际最终提示词

```text
Use case: style-transfer.
Create ONE simplified game-model reference of the Yamato battleship in IMAGE 1, using the approved simple shading and surface treatment of the aircraft in IMAGE 2.
IMAGE 1 is the geometry/composition authority: preserve the actual ship's complete silhouette, hull proportions, curves, perspective, bridge profile, funnel, turret shapes, gun positions and coherent structural connections. IMAGE 2 is STYLE ONLY. Do not include an aircraft.

The goal is faithful OUTER SHAPE with simple surface detail. Preserve all the large shapes and their spatial relationships from photo 1; remove small construction detail instead of replacing the distinctive bridge and platforms with arbitrary boxes or cylinder stacks.
Keep the exact bow-to-stern arrangement visible in the source: 2 forward triple main turrets, then the much smaller raised centerline triple secondary gun directly against the forward face of the bridge, the tall main bridge, one raked funnel, the aft superstructure, the rear centerline triple secondary turret and 1 aft triple main turret. The forward secondary turret belongs ABOVE and behind main turret 2, on the same centerline and backed by the bridge; it must NOT become a small side gun in front of the viewer. Keep the large twin-barrel AA gunhouses and small triple AA silhouettes grouped around the superstructure as in the photo. The precise small AA count is not the purpose of this style preview.

Surfaces: gray hull and superstructure, muted red-brown lower hull, flat tan deck. Smooth continuous hull, crisp sloped armor shapes, clean rounded surfaces where the source has curves. Plain diffuse color and modest ordinary realtime-style lighting, matching the aircraft's level of polish. Remove porthole rows, fine rigging, ladders, tiny rails, individual planks, engravings, weathering, mechanical internals and dense deck fittings. Simplify retained AA guns to clean recognizable barrels and connected housings. Do not erase the ship's major mounted weapons or change the bridge's stepped outer profile. Avoid harsh low-poly facets and oversized barrels.
Keep photo 1's COMPLETE ship and near-side bow-quarter view, with similar moderate perspective and generous margins. Remove the black display base, its nameplate, floor shadow, flags and deck aircraft. Plain light-gray background as in image 2, no floor or sea. No text or labels. Result should look like an attainable clean Godot game model, not a miniature product photograph and not a generic fantasy battleship.
```

