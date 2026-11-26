# SB2C-4 外观大形候选 v04

日期：2026-11-10。工具：内置 Image Gen，通过 imagegen 技能执行；非 CLI／API 脚本。输出：[外观大形候选 v04](sb2c4-outer-form-candidate-v04.png)。

## 本轮要求

用户澄清：主要还原造型的外观形状；座舱盖还原大形，不做 1:1 结构复制；机身表面几何应简单；不要独立发动机罩与细节；本版不需要起落架机械。此要求取代上一轮把“完全还原”解释成详细结构复刻的做法。

采用规则：保留机身、翼尾、座舱盖和武器的可辨外轮廓、比例及位置；机头并入连续机身外壳，省略罩口／罩瓣／接缝／发动机内部；舱盖用简洁曲面与少量框线；起落架以轮子和简单支杆表达。材料、照明和表面细节保持简单。

## 输入

- 输入 1：[v03 候选](sb2c4-form-preserving-candidate-v03.png)，本轮编辑对象。
- 输入 2：[原始成品模型前斜视照片](../extra_09.jpg)，再次约束外部大形，避免只对生成图连续再生成。
- 原图来源和使用范围见[sources.json](../sources.json)。历史尺寸和配置仍以原始资料为依据。

## 已看到的变化

- 机头和机身成为连续表面，移除了独立罩环、罩口、排气及多数表面附件。
- 座舱盖保留长弧形体量，以少量线条表达分段；没有密集外凸框架、内部与滑动机构。
- 起落架变为简单支杆和轮子，无液压、弹簧和复杂盖板机构。
- 去掉线缆和天线阵列，减速板在本张检视图中闭合，以便观察机翼大形。
- 保留可见翼炮、后座双联枪管与挂弹的简化外形。

用户已于 2026-11-10 认可“这一套”，并要求按同一风格生成大和号；因此此图成为 `simplified-historical-v0.2` 的外观复杂度与大形方向基准。认可范围为风格与简化取舍，不是 Godot 实际渲染或几何验收。舱盖侧形、武器安装与被遮挡的远侧部件仍应在真实模型多视图中校核；生成图的涂装标识不能自动成为配置事实。本轮没有修改模型代码或运行项目。

## 可执行的模型调整

1. 对照原始照片修正机身、机翼与舱盖的大形和比例。
2. 机头外包络与机身连续建模，去掉本版不需要的罩环、开口、排气和表面小几何。
3. 舱盖保留合适曲率、风挡倾角及底边衔接，框线少量表达。
4. 简化起落架机构、枪架机构与细小附件，保留轮子、简单支杆、武器外形及有效安装点。
5. 用统一的中性光照、纯色材质，在实际观战视距和同模型侧／前／俯视检查。

## 实际提示词

```text
Use case: precise-object-edit.
Image 1 is the current AI candidate to edit. Image 2 is the original SB2C-4 photograph, used ONLY to keep the recognizable overall external shape and proportions. Produce one revised candidate.

The user's target is faithful recognizable OUTER FORM with uncomplicated surface geometry. They explicitly do NOT want an exact miniature replica, mechanical reconstruction or detailed engine cowling. Preserve the main aircraft proportions, wing planform/thickness/tips, tail shape, and recognizable canopy outline from these images. Do not turn it into a generic toy airplane.

Make these specific simplifications to image 1:
1. FUSELAGE AND NOSE: one continuous clean smooth dark-navy skin. Preserve the short broad rounded nose envelope, but merge it completely into the fuselage. Remove the separately modeled engine cowling, its rings, bands, gaps, cowl flaps, protruding exhausts, access panels and engine interior. The face behind the propeller is a simple closed solid form with no intake cavity, concentric ring geometry, or visible engine. No panel seams, indents, sockets, vents, bumps or tiny protrusions on the fuselage. Preserve the overall shape, not the separate construction of the cowling.
2. CANOPY: retain the real canopy's long curved profile, appropriate height, windscreen slope and fit into the fuselage, represented as one or two clean smooth muted blue-gray glass-like volumes. Only two or three very thin FLAT dark color lines may suggest the principal divisions. Remove the dense raised frame cage, exact glazing subdivisions, sliding rails, hinges and visible interior. No seats or people. Do not use a faceted polygonal cap or greatly enlarge the canopy.
3. LANDING GEAR: keep recognizable deployed main wheels and tailwheel where visible, using plain black wheels and just one simple neutral-gray support strut per wheel. Remove the entire hydraulic/mechanical assemblies, pistons, springs, pipes, brackets, complex door mechanisms and tread. No yellow segmented cylinders. A simple wheel and rod are sufficient.
4. WEAPONS: retain recognizable external weapon silhouettes, count and locations: wing cannon barrels and the compact paired rear guns, plus the visible bomb as a simple correct nose/body/fins form. Remove detailed gun-ring mechanisms and interior gunner furniture. Attach each visible weapon coherently; do not add floating weapons or decorative parts.
5. WINGS: retain their airfoil-like external volume, root transition and exact overall planform. For this clean outline-inspection pose, CLOSE the dive brakes flush with the wing trailing-edge surfaces and omit their fine perforations and hinges. No raised brake panels, spoiler-like rectangular plates or exposed linkage. Keep only minimal unobtrusive control-surface boundaries. Remove antenna wires and hanging antenna arrays.

Preserve the four-blade propeller and complete aircraft framing from image 1. Keep the same front three-quarter view and deployed landing-gear state. Retain only simple existing national markings. No new decals or text.
Materials and lighting: plain restrained navy color areas, subdued glass color, simple diffuse real-time shading, no detailed textures, weathering, rivets or specular showroom finish. Plain gray background, no floor, contact shadows, dramatic lighting or photographic effects.
Output one crisp complete aircraft. This is an OUTER-SHAPE reference with simple presentation, not a mechanical assembly diagram. No text, captions, collage, border or watermark.
```
