# U.S. Navy weapon module validation

## 40 mm Quad Mount Mark 2 Mod. 5

Status: first source-led, independent geometry sample. This is a model/interface review, not a historical installation claim.

### Validation scope

- Target runtime: Godot `4.7.2.stable.official.ed1daf0bf`, Compatibility renderer.
- Scene: `assets/naval/weapons/usn_bofors_40mm/mark2_mod5/usn_bofors_40mm_quad_mk2_mod5.tscn`.
- Inspection scene: `assets/naval/weapons/usn_bofors_40mm/mark2_mod5/preview/preview.tscn`.
- Correct origin/hand: deck contact at root origin, `+Y` up, `-Z` forward, `+X` starboard.
- Fixed-to-ship boundary: stand base is part of the mount. The inspection flat plate is a separate, neutral test surface; no ship platform, bulwark, support post, or interface adapter is bundled.
- Moving groups: train around local Y; four gun/cradle groups together around local X. The second control group is independently settable on each instance.
- Motion stops: -5/+90 degrees for the working-circle variant per Sketch 99008. No drive rate is asserted.
- Known reference dimensions: 40 mm bore; nominal 2.24 m bore-length derived from the 56-caliber designation; 18 × 1-inch installation bolts; 3/8-inch shield plate callout. Overall package geometry and bolt-circle radius remain estimated.

### Run commands

From the repository root:

```sh
GODOT=/Applications/Godot.app/Contents/MacOS/Godot
"$GODOT" --headless --path . --editor --import --quit
"$GODOT" --headless --path . --script res://scripts/naval/audit_usn_bofors_40mm_quad.gd
"$GODOT" --path . res://assets/naval/weapons/usn_bofors_40mm/mark2_mod5/preview/preview.tscn -- --view isometric --capture /tmp/bofors-isometric.png
```

Use `--view top`, `--view side`, `--view front`, or `--view detail`; `--elevation -5` and `--elevation 90` set the inspection angle. Captures saved under `docs/naval-weapons/screenshots/` are native Godot renders. They are not Safari/Chrome screenshots or a browser performance result.

### Results

Completed a native Godot render on the Apple M5 with Godot `4.7.2.stable.official.ed1daf0bf` / Compatibility. The isolated scene loaded without runtime errors. The audit instantiated two complete mounts and moved them to different train/elevation angles. It reported `PASS` for root contact, seat marker, four gun groups, clamped -5/+90-degree travel, and independent transforms.

Renders captured and reviewed: isometric, top, side, forward, close-up, minimum elevation, and maximum elevation. Visual iteration corrected a gap between the water-jacketed tube and muzzle extension, aligned the shield panels to the aft arc, brightened the neutral preview so geometry is readable, and removed the unsupported block-like outboard carriage feet. The carriage now uses the central rotating hub and a continuous low underframe; the exact underside construction remains estimated pending assembly drawings. At both elevation stops the gun groups remain attached to the cradle and the shield remains clear in the inspected side view. No collision solver or fit-specific obstruction audit is present.

The preview uses one temporary flat plate as a host-surface check; the mount's fixed flange rests on it at y=0. The visible plate is an inspection-only scene object and is not part of the weapon PackedScene.

### Browser sample

An isolated temporary Godot Web export of the weapon inspection scene was opened in foreground windows on the Apple M5 / 16 GB reference machine. After a 2.5-second warm-up, browser `requestAnimationFrame` cadence was sampled for 5 seconds while the single static weapon scene was visible:

| Browser | Observed cadence | Canvas backing size | Device pixel ratio |
| --- | ---: | ---: | ---: |
| Chrome 156 | 59.8 FPS | 3600 × 1926 | 2 |
| Safari 26.6.2 | 29.4 FPS | 2682 × 1920 | 2 |

This is a short foreground render-cadence sample, not a full-project performance benchmark. It contains no fleet simulation, aircraft, combat effects, or sustained camera motion; results should not be used as the battle-scene performance target. The exported test build and local server lived under `/tmp`; the temporary browser tabs were closed after sampling.

### Historical and visual limitations

The installed Mark 2 Mod. 5 assembly is only partially reconstructed from the available handbook and working-circle sheet. Base-ring diameter, exact carriage profile, shield outline, sight geometry, seat/handwheel positions, elevation linkage, and subassembly dimensions remain estimated. The axis audit and a clean visual contact plane do not establish a ship fit. No Iowa coordinates, exact production batch, local platform, or drive performance are claimed.

## Browning .30-caliber M1917A1 gun body

- Scene: `assets/naval/weapons/us_browning_30cal/m1917a1/us_browning_30cal_m1917a1.tscn`.
- Standalone Army service-pattern gun body; no tripod, pintle, ammunition chest, or ship installation is included.
- FM 23-55 describes the M1917A1 as recoil-operated, belt-fed, and water-cooled, with a 23.9-inch barrel and 450–600 rpm cyclic rate. The 1944 Standard Ordnance Items Catalog supplies the modeled 38.64-inch overall length.
- Root origin is the estimated trunnion/elevation axis. The bore is 0.05 m above that axis as an explicit geometry estimate. Receiver surface dimensions and exact trunnion positions remain estimated.
- Water jacket, receiver/feed cover, front and rear sights, buffer tube, trigger guard, and pistol grip are present. The steam-tube study is placed inside the water jacket per FM 23-55 and is not exposed as an external pipe.
- Native Godot isometric and side captures were loaded and visually reviewed: `screenshots/browning-30cal-m1917a1-isometric.png` and `screenshots/browning-30cal-m1917a1-side.png`.

## Browning .50-caliber M2 Heavy Barrel gun body

- Scene: `assets/naval/weapons/us_browning_50cal/m2hb/us_browning_50cal_m2hb.tscn`.
- Standalone M2HB gun body; no tripod, Navy Mark 17 mount, ammunition can, or ship installation is included.
- FM 23-65 gives 65.13-inch overall length, 45-inch barrel, .50 caliber, link-belt feed, recoil operation, and air cooling. The model uses the stated lengths; receiver surface shape and trunnion spacing remain visual estimates.
- Root origin is the estimated trunnion/elevation axis. The bore is 0.05 m above that axis as an explicit geometry estimate.
- Native Godot isometric and side captures were loaded and visually reviewed: `screenshots/browning-50cal-m2hb-isometric.png` and `screenshots/browning-50cal-m2hb-side.png`.

Both weapon scenes loaded in Godot `4.7.2.stable.official.ed1daf0bf` / Compatibility, and the capture processes exited after saving the images. These isolated assets have not yet been assembled to a documented mount or ship station; browser installation/performance checks therefore remain after that assembly step.
