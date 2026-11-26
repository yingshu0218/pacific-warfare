# Fletcher 外观候选 v01

2026-11-10，内置 `image_gen`，非 CLI。输出 [style-candidate-v01.png](style-candidate-v01.png)。原图、AI 图、Godot 实拍分目录，运行时不载入本图。

输入依次为本型 `images/F01.jpg`、`images/F02.jpg`，以及全项目仅作风格参考的 `docs/references/bombers/sb2c/target/sb2c4-outer-form-candidate-v04.png`。均实际打开后才使用。

检查结果：哑光材质、大色面、减少表面机构可参考。五座单装主炮的大体顺序可辨，但桥形、艏剖过度折线化，鱼雷与小 AA 的个数/外形不能从此图验收，局部平台没有可靠历史依据。**几何未通过，不作为建模几何或历史证据。** 实际模型继续按 F01–F06 制作，未将生成偏差回写成事实。

实际提示词：

```text
Use case: historical-scene. Asset: a single modeling appearance target for our Godot naval game, not a historical document or final model screenshot. Images 1 and 2 are original photographs of USS Fletcher DD-445 on 18 July 1942; they constrain the entire silhouette and equipment arrangement. Image 3, a simplified aircraft, is STYLE ONLY: restrained smooth large shapes, matte broad color areas, ordinary realtime light, no tiny mechanical detail. Show the complete Fletcher alone from the same elevated starboard bow angle as image 1, on a neutral pale gray background, waterline display without water, no diorama or pedestal. Exactly five enclosed SINGLE-barrel 5in/38 Mk30 mounts: two forward facing bow with second elevated, third forward-facing on aft deckhouse ahead of the AA tower, fourth aft-facing on same aft deckhouse, fifth aft-facing on main deck. Keep those exact locations and level relationships from image 2. Two slim separate oval raked funnels, tall early round-front enclosed bridge with circular platform and Mk37 director above, single pole foremast. Two quintuple torpedo-tube launchers on centerline amidships in their original positions. One quadruple 1.1in mount high between gun mounts 3 and 4; six small 20mm mounts, not late-war Bofors tubs. Historical Measure12 Modified dark bluegray irregular camouflage broad blocks as photos. Preserve the slim 114.76m/12.06m ratio, flush deck with bow sheer, stern low and rounded. Simplify surface details and internals only; no dense railings, rigging webs, rivets, weathering, micro panels, extra decks, extra guns, enlarged bridge, fantasy supports, smoke or dramatic light. This is a game silhouette-first target, not a detailed museum model.
```

实际游戏小 AA 为4座而非本次目标提示词的历史6座，差异在单位定义与 brief 单独记录；没有用 AI 生成结果决定游戏实装数。
