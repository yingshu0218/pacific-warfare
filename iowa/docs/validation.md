# Validation record — USS Iowa BB-61, 28 December 1944

> 2026-11-10：以下为早期迭代记录。当前模型、58座游戏清单、来源限制与回归结果以 [S02交付](../../docs/showcase/deliveries/S02.md) 和 [参考包](../../docs/references/ships/iowa_bb61_1944_12_28/modeling-brief.md) 为准；旧截图与原型通过记录不代表本轮验收。

Status: modular assembly prototype. The main and all three small-caliber weapon families use reusable weapon scenes and station-specific foundations. The aft aircraft-handling fit uses two reusable catapult instances and one centerline crane instance. The current appearance pass prioritizes the deck, bridge superstructure, and main turrets; floatplanes are deferred.

## Engine and structure

- Target engine: Godot `4.7.2.stable.official.ed1daf0bf`, Compatibility renderer.
- Source scene: `scenes/iowa_bb61.tscn`; inspection scene: `scenes/iowa_viewer.tscn`.
- Runtime hierarchy: `ShipRoot/{Hull,Superstructure/{Bridge,Platforms,Mast,Funnel,AfterTower},MountFoundations,Equipment}`.
- Main battery assembly: each hull station has a `Marker3D`; an independent barbette foundation aligns to that deck marker; its `WeaponSeat` hosts an instance of the same `scenes/weapons/main_16in_three_gun.tscn` resource. The turret has one train pivot and three per-gun elevation pivots.
- Small-caliber assembly: each 5-inch, Bofors, and Oerlikon station has its own foundation and `WeaponSeat`, with one shared scene per family. Roof-mounted light AA remains parented to the moving host turret.
- Aircraft-handling assembly: two stations instantiate `scenes/equipment/aircraft_catapult_turntable.tscn`, each with a fixed deck socket, turntable, and independent train pivot. One centerline station instantiates `scenes/equipment/aircraft_crane_lattice.tscn` with separate train and boom-elevation pivots. Station centers, headings, and mechanisms remain low-confidence estimates.
- Station markers store station ID, host module, local position, compatible interface, source status, and confidence. The current numeric positions and interface dimensions are low-confidence visual estimates.
- The 6 November 2026 weapon-scene bake regenerated the shared 16-inch scene with side sight hoods and roof periscope covers. Native viewer captures were made with the Compatibility renderer; capture mode pauses the simulation to keep screenshots stable. The final editor import scan completed after the scene bake and updated screenshots. Automated tests were not run.

Run the structure check from the repository root:

```sh
"$GODOT" --headless --path iowa --script res://tests/test_mount_assembly.gd
```

## Native visual review

Captures in [screenshots](screenshots/) were generated from Godot 4.7.2 on Apple M5 using the Compatibility renderer. This pass visually checked the [forward bridge window row and brow](screenshots/bridge_front_detail_pass.png), the [assembled bridge and forward turret](screenshots/bridge_upperworks_overview_final.png), and the [main turret sight hoods and periscope covers](screenshots/main_turret_sight_details_final.png). Earlier captures show the [main turret geometry](screenshots/main_turret_geometry_pass.png), [turret overview](screenshots/main_turret_overview_pass.png), [interpolated hull side](screenshots/hull_spline_side_pass.png), [interpolated hull overview](screenshots/hull_spline_overview_pass.png), [5-inch twin mount](screenshots/secondary_5in_geometry_pass.png), [crane module](screenshots/aircraft_crane_module_pass.png), [catapult module](screenshots/catapult_module_pass.png), [stern aircraft-handling overview](screenshots/stern_aircraft_handling_overview.png), and [Measure 32 full-ship view](screenshots/measure32_camo_overview.png). Review covered turret proportions and ports, all three main barrels, new turret optical fittings, the 5-inch twin ports and painted shell, hull sheer, bridge-wing hosts and guardrails, window placement, side access ladders, small-gun distribution, aft bearing contact, catapult trusses and rails, crane lattice and rig attachment points, camouflage coverage, deck-blue treatment, propellers, and rudders. The mount shader uses a neutral-heading transform so the pattern stays attached during train motion. Small-caliber mount paint and other mobile fittings remain incomplete.

The viewer supports `overview`, `top`, `side`, `bridge`, `bridge_front`, `turret`, `secondary`, `bow`, `stern`, `aircraft`, `catapult`, and `crane`; the `secondary`, `aircraft`, `catapult`, and `crane` views are also available with keys `6`–`9`.

The HUD now reports the current frame-rate and draw-call monitors and identifies the selected gun in a multi-gun turret. The capture command takes only a couple of startup frames, so its displayed FPS is not a stable performance sample.

## Browser and device record

The following browser review was recorded before the small-caliber scene refactor. Reviewed 5 November 2026 on a MacBook Pro with Apple M5 and 16 GB RAM. The Web export was served locally at `http://127.0.0.1:8767/index.html` and opened full-window (desktop capture: 3584 × 2048 px). FPS values below are short, settled HUD observations during visual review, not a sustained benchmark. The web export has not been rechecked after the weapon-module, turret/hull geometry, or aircraft-handling module passes.

| Browser | Version | Observed FPS | Draw calls | Visual and interaction result |
| --- | --- | ---: | ---: | --- |
| Safari | 26.6.2 (21624.5.1.11.3) | 46–56 | 1713 | Ship and HUD rendered; `Q/E` selected gun 2/3 and `W` changed that gun's elevation. |
| Chrome | 156.0.8078.80 (arm64) | 47–60 | 1713 | Ship and HUD rendered; `Q/E` selected gun 2/3 and `W` changed that gun's elevation. |

Both browsers showed the three-gun main turrets and the 84-mount count without a blank canvas or framework error overlay. The browser console was not available through the native-app inspection interface, so console output was not captured. Browser acceptance covers rendering and the selected-gun control loop; it is not a sustained performance certification.

## Known limits

- Weapon coordinates, platform heights, barbette dimensions, and most absolute superstructure heights remain provisional estimates; no dated 1944 installation plan or hull offsets drawing has been measured into the data.
- 19 quad Bofors and 52 single Oerlikons remain a provisional working fit, not an exact-date inventory claim.
- The 5-inch Mark 28 Mod 2 envelope, barrel exterior profile, gun spacing, and port details remain visual estimates; the documented 4.826 m value is bore length.
- Small-caliber geometry is now shared by mount family, but station locations, support interfaces, and dated fit still need stronger records.
- Hull and superstructure are grouped into runtime modules but are still generated by `iowa_ship.gd`, not authored as reusable external scenes. Aircraft catapults and the centerline recovery crane use shared external scenes.
- The scene does not implement ammunition, firing, recoil, damage, collision-aware firing arcs, or equipment operation. Motion limits and rates are demonstration values.
- Camouflage remains partial: the hull, stationary superstructure, main turrets, and 5-inch housings use the approximate mask; barrels and 40 mm/20 mm mounts remain unpainted. Guardrails cover selected upper platforms; long deck-edge rails, netting, deck planking, boats, internal spaces, and many fittings remain out of scope. Floatplane modeling is deliberately deferred while deck, superstructure, and turret work continues.
- Bridge window spacing, access-ladder dimensions, and 1944 placement of the turret sight hoods and periscope covers remain visual estimates; no Iowa-specific December 1944 fitting plan has been checked.
