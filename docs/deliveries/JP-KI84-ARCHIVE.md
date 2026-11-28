# Nakajima Ki-84-Ia Hayate · Static exterior exhibit

Game art, not a specific serial-number reconstruction. This airframe represents the 1944–45 period; the photographed airframe in the Chiran collection was built in August 1944. Suggested exhibit ID: `jp_ki84_ia`.

- Scene: `res://aircraft/jp_ki84_archive/ki84_ia.tscn`
- Geometry: `res://aircraft/jp_ki84_archive/hayate.gd`
- Forward: local −Z. The type has no turret; the exhibit does not invent one. It has static display parts, with no combat, collision or flight bindings.
- Godot rendered mesh envelope W/H/L: **11.24 / 3.432 / 9.920 m**. These are game display extents; height reflects fixed wheel stance and the visible rendered elements, not a factory datum.

## Visual reference and acceptance

| Godot view | Checked against | What to look for |
| --- | --- | --- |
| Front | [Chiran Peace Museum, Hayate exhibit](https://www.chiran-tokkou.jp/en/hayate.html) | Four dark propeller blades with warm tips, short red spinner, high shoulders of the radial cowling, scoop silhouette below its front section, broad wheel spacing |
| Side | [AWM 129710, c. 1945](https://www.awm.gov.au/collection/C237820) and [AWM AC0185](https://www.awm.gov.au/collection/AC0185) | Deep nose profile dropping into a tapering rear body; compact raised canopy; curved fin shoulder and near-upright trailing edge; short forward chin housing unlike the Ki-61's mid-belly housing |
| Plan/front three-quarter | [AWM AC0185](https://www.awm.gov.au/collection/AC0185), [Chiran museum exhibit](https://www.chiran-tokkou.jp/en/hayate.html), and exterior silhouettes in [TAIC 156A-2, March 1945](https://www.wwiiaircraftperformance.org/japan/Ki-84-156A.pdf) | Tapered low wing with clipped-round tips, sloped leading edge, compact swept tailplane and narrow rear taper |

AC0185 shows a captured aircraft in US markings: use it for body shape, not paint. Olive over warm gray, yellow leading edges, and the spinner establish a representative subdued Japanese presentation; this is not a claim that all Ki-84s wore that finish. The model is deliberately closed and nonoperational.

Test with Godot 4: `godot --headless --path . --script tests/model_audit/test_jp_ki84_archive.gd`. The audit checks four blade roots, type-specific meshes, markings, finite dimensions and absence of simulation nodes. Native Compatibility viewport captures: `.local/jp_ki84/ki84_ia_{hero,side,plan,front}.png` (local work evidence, not shipped game assets).
