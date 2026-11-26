# CV02 ImageGen v01 · simplified-historical-v0.2

2026-11-11，built-in `image_gen.imagegen`；`transparent_background=false`。参考输入顺序：S01实际右舷侧照；M01-page-2厂商模型辅助；S05识别模型；SB2C-v04仅风格。不将后三者的隐蔽面或生成内容当新史实。

输出保存在同目录 `style-candidate-v01.png`。实际提示词如下：

```text
Use case: historical-scene, stylized-concept. Asset type: visual STYLE target for a Godot simplified historical naval game, not historical evidence. Primary request: a single isolated IJN SHOKAKU as completed 23 August 1941, full ship high starboard bow-quarter view. Input 1 is the actual Shokaku dated 1941 starboard broadside, authoritative silhouette. Input 2 is a Tamiya Shokaku 1941 kit layout, useful auxiliary arrangement but not shipyard dimensions. Input 3 is US Navy class recognition model, only broad volumes; do not copy its erroneous extra weapons. Input 4 aircraft only defines clean simplified matte realtime style. Structure: 257.5m hull with raked flared bow and rounded stern, low continuous enclosed double-hangar walls, 242.2m unarmoured rectangular flight deck with small corner tapers, wooden ochre deck and grey steel ends, THREE centreline rectangular elevators. Small low stepped island well forward on STARBOARD edge, separate slender tripod foremast by island, TWO separate flattened downward-outboard starboard exhaust funnels amidships well behind island, no island funnel. Eight twin 127mm Type89 DP gun mounts total, four per side: forward pair abreast forward elevator, aft pair around 60-75% aft, on low sponsons below flight deck. Only TWO starboard AFT mounts have rounded smokeproof domed housings; other SIX open with partial front shields. Small 25mm AA platforms largely aft on port side. Preserve actual support columns at bow and stern, no giant invented outriggers. Constraints: simplified semi-realistic smooth major curves and accurate overall proportions; broad matte grey hull and restrained ochre wood colour; very few material regions; no tiny rivets, railings, ropes, portholes, planking texture, weathering, crew, aircraft, water, wake or weapons firing; no radar antenna in 1941; no catapults; no American carrier geometry or angled deck. Scene/backdrop: pale grey neutral studio, full ship not clipped, soft neutral light, ordinary realtime rendering. Deck and weapon relationships readable. No text or labels.
```

核图结论：哑光灰/木色和低表面噪声、少细件方向可用。3升降机与独立双烟囱总体语义可读；生成的甲板过于等宽、前段缺连续收窄，局部平台和舰岛/舰艏体量以及可见武器分组不能作为几何依据；木纹线亦不采纳。前甲板连续收窄在实际Godot源码/数据中按M01和原资料约束另行修正。**该图未获几何或炮位验收，未作为运行时资产。**

实际模型多角度来自同一Godot场景，不把生成图冒称游戏截图。后续没有反复重生成细部。
