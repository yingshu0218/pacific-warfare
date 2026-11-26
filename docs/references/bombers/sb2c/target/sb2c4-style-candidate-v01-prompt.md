# SB2C-4 风格候选 v01 生成记录

日期：2026-11-10。工具：内置 Image Gen，通过 imagegen 技能执行；非 CLI／API 脚本。

输出：[风格候选图](sb2c4-style-candidate-v01.png)。状态：可讨论简化程度与材质；几何尚未通过，不作为尺寸、多角度一致性或最终模型验收依据。

输入 1：[`extra_09.jpg`](../extra_09.jpg)，主体、姿态、相机与结构参考。
输入 2：[`extra_10.jpg`](../extra_10.jpg)，同一成品模型的后侧结构辅助。两图原始来源与使用范围见[来源记录](../sources.json)。

## 实际图像检查

已看到：整体翼尾轮廓仍可辨；四叶螺旋桨；主要材质与表面细节明显收敛；没有复杂场景干扰。可用于讨论简化层级、宽阔色面、玻璃与金属的处理。

待核／不采纳：座舱的高度与截面较原图有变化；机翼增加了可见标识，不能直接作为历史涂装；减速板呈现为简化上翻板，分裂式机构关系不足；后座枪架支承仍需实际资料核对。此图不通过主体几何和机构定稿，不据其修改真实尺寸或增补武器。

下一步使用真实资料和已有模型确定大形，再从同一 Godot 场景导出侧／前／俯视。需要新目标图时继续携带原始照片、固定结构表和全局风格规则，避免只拿这张生成图反复生成。

## 实际提示词

```text
Use case: style-transfer.
Asset type: a single candidate art-direction image for a simplified historical 3D Godot spectator game, not a technical drawing.
Input image 1 is the PRIMARY geometry, identity, pose, and camera reference: the existing SB2C-4 scale-model photograph viewed from the front and above. Input image 2 is SUPPORTING identity and rear-shape evidence of the SAME aircraft, not a second subject.
Primary request: Reinterpret the aircraft from image 1 as an achievable, clean, simplified real-time 3D game asset. Keep its recognizable Curtiss SB2C-4 proportions and silhouette. Use restrained semi-realistic forms: enough smooth curvature for the cowling and fuselage, clean economical wing and tail forms, no exaggerated toy proportions, no intentionally coarse triangular facets.
Invariant geometry: preserve the same front-high three-quarter camera and landing stance as image 1; one aircraft only; preserve the wide fully unfolded wings, large tall single vertical tail, horizontal tail, long framed two-seat canopy and open rear gunner area, compact round cowling, FOUR propeller blades, two main landing wheels and one tailwheel. Preserve the position and shape of the open split dive-brake panels shown in the references, but represent their faces as plain solid panels with no fine perforations. Do not add or remove major wing, tail, weapon, canopy or landing-gear structures. Keep the aircraft fully visible with a comfortable margin, including both wingtips, propeller tips and tail.
Allowed simplification: remove tiny rivets, fine panel seams, chipped paint, dirt, weathering, fine aerial wires, miniature mechanical fittings, cockpit people and complex cockpit interiors. Keep only simple dark glazing, essential canopy framing, simple gear struts, a minimal rear gun assembly, essential attachment relationships and readable national markings. No detailed wheel tread, no microscopic hinges, no photoreal surface texture.
Materials: matte muted dark naval blue painted surfaces, slightly lighter blue broad surfaces for readability, dark charcoal rubber and gun metal, muted desaturated glass, restrained dark red inner dive-brake faces. Large calm color areas, limited material palette, broad simple highlights.
Scene: plain warm light-gray studio background and ground, neutral broad daylight from upper left, soft simple contact shadow. Clear contours and readable construction. No cinematic haze, no ocean, no explosion, no dramatic rim light, no depth of field, no motion blur.
Composition: one complete aircraft at essentially the same pose and perspective as input image 1, landscape image. No panels, comparison collage, diagrams, dimensional annotations, captions, watermark, or invented logos.
This is a visual style candidate. Do not beautify it by increasing fine detail; prioritize consistent simplification and preservation of historical identity.
```
