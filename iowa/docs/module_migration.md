# Module migration ledger

> 2026-11-10：以下为早期迭代记录。当前模型、58座游戏清单、来源限制与回归结果以 [S02交付](../../docs/showcase/deliveries/S02.md) 和 [参考包](../../docs/references/ships/iowa_bb61_1944_12_28/modeling-brief.md) 为准；旧截图与原型通过记录不代表本轮验收。

The ship is being migrated in small families so each assembly can be checked against its own host and motion interfaces. `provisional` station data stays marked as such until an exact-date source supports it.

| Module family | Current state | Host and motion structure | Remaining work |
| --- | --- | --- | --- |
| Hull | Grouped runtime module | Hull owns deck station markers and the hull geometry | Replace the generator with a reusable hull scene; refine from measured lines/offsets data if acquired |
| Superstructure | Grouped runtime modules; detail pass in progress | Bridge, Platforms, Mast (ForwardMast/AftMast), Funnel (ForwardFunnel/AfterFunnel/MidshipsGallery), and AfterTower are inspectable roots; bridge now carries a framed forward window row and side access ladders; platform hosts own their markers and provisional guardrails | Extract reusable scenes; verify elevations, window spacing, access routes, platform outlines, and rail placement against dated imagery |
| 16-inch/50 main battery | Migrated first; geometry pass in progress | Hull marker → separate barbette foundation → WeaponSeat → one shared baked three-gun turret scene; train and each gun elevation are separate pivots; side sight hoods and roof periscope covers move with the train housing | Verify dated station positions, foundation interface, and exterior fitting placement against Iowa-specific 1944 records; motion rates remain demonstration values |
| 5-inch/38 twin mounts | Migrated | Host marker → per-station foundation → `WeaponSeat` → shared twin-mount scene; train and elevation are separate pivots | Verify station heights and support diameters against dated installation drawings; refine the weapon geometry |
| 40 mm Bofors | Migrated | Host marker → per-station foundation → `WeaponSeat` → shared quad-mount scene; train and elevation are separate pivots | Verify deck clearance and support dimensions against dated installation drawings; refine the weapon geometry |
| 20 mm Oerlikon | Migrated | Host marker → per-station foundation → `WeaponSeat` → shared single-mount scene; train and elevation are separate pivots | Verify station heights and pedestal dimensions against dated installation drawings; refine the weapon geometry |
| Aircraft catapults | Migrated to one shared equipment scene | Hull station record → independent catapult root → fixed deck socket → slew bearing → train pivot | Verify dated station positions, turntable dimensions, track length, and azimuth against Iowa-specific plans |
| Aircraft crane | Migrated to one shared equipment scene; one centerline stern instance | Hull station record → crane root → fixed deck socket → train pivot → boom-elevation pivot | Verify exact station, bearing dimensions, and boom geometry against Iowa-specific plans |
| Anchors and deck fittings | Grouped procedural Equipment child | Owned by Equipment/AnchorsAndDeckFittings | Split only where independent reuse or movement is needed |

## Completed contract for the main battery

- Each of the three hull stations has a stable station ID and records its host path, local position, interface name, source status, and confidence.
- The fixed barbette is a separate `IowaMountFoundation` instance. Its base aligns with the Hull marker; its named `WeaponSeat` marks the turret interface at the top.
- All three turrets instantiate `scenes/weapons/main_16in_three_gun.tscn`. The scene keeps fixed housing under `TrainPivot/HousingAndControls` and places the three independently elevating barrel/cradle assemblies under `ElevationPivot_Gun01..03/GunsAndCradle`.
- Shared-class gunhouse and gun dimensions are recorded in `data/weapon_profiles.json`; front/side slope, barrel exterior profile, and port fittings remain explicitly marked estimates.
- Turret-roof light-AA stations are child markers of the host turret roof, so they move with turret training.
- The viewer selects each gun with `Q/E`; `W/S` elevates only the selected gun. `A/D` train the turret without changing the three elevation commands.

## Appearance pass

- The forward bridge is a faceted, stepped tower with separate bridge-wing and signal-platform hosts.
- The lower forward bridge has an estimated 11-window framed row, a brow, and paired side access ladders; see [the front detail capture](screenshots/bridge_front_detail_pass.png) and [the assembled bridge view](screenshots/bridge_upperworks_overview_final.png).
- The baked 16-inch turret scene includes side sight hoods and roof periscope covers, referenced to OP-769 as later Iowa-class shape evidence; it is not a confirmed Iowa 1944 fit. See [the turret detail capture](screenshots/main_turret_sight_details_final.png).
- The midships gallery and the forward and after funnel modules are separate nodes. Each funnel has its own tapered casing, uptake trunk, cap, and single outlet.
- The aft director tower and aft mast are separate modules.
- See [shape pass screenshots and notes](shape_pass.md). Dimensions in this appearance pass remain visual estimates; the linked 1:200 model is used for relative silhouette and arrangement only.

## Small-caliber weapons pass

- The 5-inch/38, 40 mm Bofors, and 20 mm Oerlikon each use one baked scene resource shared by all matching mounts.
- A station-specific foundation owns the fixed support and exposes a named `WeaponSeat`; the reusable weapon scene owns the train pivot, housing, and elevation pivot. Roof-mounted AA foundations are children of the turret-roof marker and follow the host turret.
- Estimated foundation interfaces are 4.0 m diameter × 0.64 m high for 5-inch, 2.1 m × 0.28 m for Bofors, and 0.76 m × 0.24 m for Oerlikon. These are provisional modeling interfaces, not measured shipyard values.
- See [weapon module pass notes and screenshots](weapon_module_pass.md).

## Stern aircraft-handling pass

- Two aft stations instantiate `scenes/equipment/aircraft_catapult_turntable.tscn`; each reads its deck position and initial azimuth from `data/december_1944.json`. The fixed deck socket, slew bearing, rotating turntable, truss bed, rails, cylinder, and shuttle are part of the reusable scene.
- One centerline stern station instantiates `scenes/equipment/aircraft_crane_lattice.tscn`, with independent train and boom-elevation pivots. The geometry includes a braced tower/headframe, double-chord boom, topping line, sheaves, hoist cable, and hook.
- NHHC 80-G-K-6118 documents the catapult, crane, and OS2U cart aboard Iowa; 80-G-421124 checks the exact-date 1944 stern layout. Dimensions, centers, and initial headings remain estimates rather than measured plan data.
- See [stern aircraft-handling module pass](shape_pass.md#stern-aircraft-handling-module-pass).

## Migration order

Next, refine the bridge, deck access routes, and main turret external fittings against dated Iowa views, then extract the hull and platform hosts into reusable scenes. Floatplanes are deferred while the deck, superstructure, and turrets remain the priority. Keep station-specific source status and confidence on each host marker. Do not add generic geometry to hide a mismatch; correct the host or the part interface and document any remaining uncertainty.
