# SB2C-4 完整外形与简化表现候选 v03

日期：2026-11-10。工具：内置 Image Gen；使用 imagegen 技能，非 CLI／API 脚本。输出：[候选图 v03](sb2c4-form-preserving-candidate-v03.png)。

用户最新要求：飞机机身、机翼、座舱盖、武器完全还原。将准确的外部形体、配置与连接列为建模硬要求，简化范围收敛到材质、光照和表面微细节。现有 Godot 模型的几何不再作为准确性的上限；中间那张过度简化座舱和武器的候选不采用。

## 输入角色

1. [extra_09.jpg](../extra_09.jpg)：完整前斜视成品照片，约束整体外形、比例和构图。
2. [extra_10.jpg](../extra_10.jpg)：同一模型后斜视，补充翼尾、座舱和后座开口。
3. [extra_11.jpg](../extra_11.jpg)：后座双联武器、枪环、枪架和连接局部；本轮实际打开检查。成品模型照仍需真实资料交叉核对。
4. [现有 Godot 检视截图](../../../../../aircraft/sb2c4/screenshots/round3/sb2c4-round3-detail-front-port.png)：仅用于基本材质和光照级别。该截图早于最后一轮模型代码修改，不作为最新模型验收或正确外形依据。

原始照片的作者和用途限制见[sources.json](../sources.json)。这四种输入角色不能互换。

## 图像检查与适用范围

本轮已目视检查生成结果。相较被否决的过度简化候选，此图保留了更完整的座舱框架、机头与翼根体量、后座开口和武器安装的可见层次；以简单背景和较干净的表面处理表达目标。可以讨论“准确外形＋简单表现”的方向。

此图仍不是通过几何验收的工程基准：座舱高度、框架与滑动状态需对照原图；分裂减速板的上下关系和局部连接未得到多角度证明；翼炮露出长度、远侧部件以及后座枪架不能只凭这一张图验收。翼面标识、线缆与小孔不因生成结果存在就成为新增制作要求。不得按生成图直接量尺寸，也不得把它称为 Godot 运行截图或完全还原成果。

## 对应建模修改清单

- 机身：按可信尺寸和多角度资料校正截面、机头、翼根过渡、后机身收束；闭合接缝。
- 机翼：校正翼展／翼弦关系、平面轮廓、厚度、上反角、翼尖与控制面，正确安装上下减速板；不能退化为通用平板或三角翼。
- 座舱盖：按所选子型还原风挡倾角、曲面、框架、分段和开启关系；玻璃材质简单处理，座舱盖不替换成通用实心盖块。
- 武器：按配置逐项核对型号、数量、外部形状、炮口／枪管、挂架和安装点；补齐连接，不以无依据的杆柱掩盖问题。

对照原始图和实际模型完成以上项目后，再记录几何验收。生成候选本身不修改模型任务的未通过状态。本轮没有改动 Godot 模型。

## 实际提示词

```text
Use case: style-transfer.
Asset type: accurate-airframe, simple-rendering SB2C-4 visual target for a Godot historical game.
INPUT ROLES:
Image 1 (complete front three-quarter scale-model photo) is the PRIMARY edit target for silhouette, proportions, aircraft identity, camera and pose.
Image 2 (complete rear three-quarter photo) corroborates wings, tail, canopy and rear gunner opening.
Image 3 (close view of the rear gunner mount) constrains the twin rear gun bodies, barrels, cradle, ring and their connections; do not copy its photographic detail density.
Image 4 (existing Godot screenshot) is ONLY a reference for modest lighting and material treatment. Its aircraft geometry is inaccurate and MUST NOT be copied.

The user's priority is faithful external reconstruction of the fuselage, wings, canopy and weapons. Change ONLY the material/lighting treatment and microscopic surface decoration of image 1. Preserve its actual airframe geometry rather than redesigning or simplifying it. One complete SB2C-4, matching image 1's front three-quarter view, nose toward lower left. Keep both wing tips and the entire tail in frame.

Mandatory geometry preservation:
- Copy the distinctive fuselage volumes, cross-section transitions, cowling, nose length, wing-root fairing and tail taper in image 1. No stretched cylinder fuselage, caricature proportions, exaggerated smooth bulges, or faceted replacement shapes.
- Preserve the real unfolded wing planform, thickness, taper, curved tips, dihedral, root blend, and trailing-edge/control-surface boundaries. Keep the horizontal and large single vertical tail shapes. Preserve the upper/lower split dive-brake arrangement and actual attachments in the source; do not replace these with large rectangular spoilers standing on top of the wings. Tiny brake perforations may be omitted under the project's established surface-detail simplification, but retain the panel outlines, split arrangement and attachment locations.
- Preserve the windscreen slopes, canopy curved section, framing layout and opened/sliding canopy state from image 1. Preserve the separate rear gunner opening. Do not replace the canopy with a generic opaque polygonal cap. Glazing may be a uniform subdued blue-gray, slightly translucent or dark, with only simple highlights; no complex cockpit interior or pilot figure.
- Preserve all external weapons: two wing cannon installations and their correct exposed muzzle/barrel shapes and positions; twin rear flexible gun bodies and barrels with the cradle and curved ring mount shown by image 3, physically connected inside the rear cockpit. Keep the source's external bomb mounts and recognizable bomb nose/body/fins if visible. Do not omit weapons, substitute generic unconnected rods, float a gun above the canopy, add extra guns, or invent support posts.
- Preserve FOUR propeller blades with the real blade outlines, main landing-gear placement, two main wheels and tailwheel. Respect natural occlusion; don't move hidden components just to expose them.

Simple rendering: uniform restrained dark navy painted surfaces, dark subdued glazing, dull gunmetal weapons, plain black tires, limited muted colors, basic diffuse shading with small restrained highlights. Clean surfaces with no weathering, rivets, fine panel-line texture, microscopic holes, fabric texture, or photographic material noise. Do not add visible interiors, wiring or hydraulic details. Aircraft silhouette, canopy frame geometry and weapon external shapes must remain faithful despite surface simplification.
Background: flat light-gray inspection background, basic ambient and directional lighting, no floor shadow, studio contact-shadow treatment, ambient-occlusion halos, global-illumination look, dramatic lighting, reflections, depth of field or cinematic effects. Crisp readable image, simple game-viewport appearance.
Output: one complete aircraft, no labels, grid, text, annotations, multi-view collage, watermark or framing. Do not use previous AI candidates as shape references.
```
