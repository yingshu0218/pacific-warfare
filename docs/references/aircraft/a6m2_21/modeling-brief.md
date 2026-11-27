# A6M2 二一型 · Early Model 21 visual study

- Standalone Godot viewer: `res://aircraft/a6m2_21/viewer.tscn`. Keys 1–3 change camera, G folds or extends landing gear, F previews the short flash. This fits the project as a visual study only, not a registered flight/combat unit. The flash button has no targeting, projectile, or damage behavior.
- New, dimensioned appearance mesh in model coordinates (12.000 × 9.060 × 3.510 m envelope). Mainplane has an outer fold seam and rounded tips. Early paint is a light grey-green visual interpretation, not a measured restoration colour match; no invented serial or documented airframe identity.
- Exterior references: [Australian War Memorial A6M2 Model 21, REL/08378](https://www.awm.gov.au/collection/REL:08378), [wartime A6M2 photography, AWM C80349](https://www.awm.gov.au/collection/C80349), and [Pearl Harbor Aviation Museum Model 21 collection display](https://www.pearlharboraviationmuseum.org/visit/experiences/our-collection/). The preserved aircraft establish type and shape; restoration details and screen paint are not attributed to a specific operational airframe. [Smithsonian A6M5 Model 52](https://airandspace.si.edu/collection-objects/mitsubishi-a6m5-reisen-zero-fighter-model-52-zeke/nasm_A19600335000) is a later variant for contrast only.
- The existing A6M5a scene and shared aircraft builder remain unchanged.
- `godot --headless --path . --script tests/model_audit/test_a6m2_21_visual.gd` checks cameras, mesh envelope, propeller, markings and flash lifecycle. Two optional absolute paths after `--` export the A6M2 and existing A6M5a meshes for a same-scale comparison.

## Shared battlefield visual smoke

`CombatEffects` consumes existing fired events. Per-shot cloud size, opacity and lifetime increase with displayed caliber; large puffs get extra layers, and all puffs expand, drift in world space and fade separately from the flash. Light smoke has a sub-limit within the existing bounded effect pool. No simulation, weapon definitions, targets or damage logic change. `tests/test_muzzle_smoke_linger.gd` checks effect appearance state, timing, pooling and the effects toggle.
