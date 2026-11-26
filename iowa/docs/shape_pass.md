# USS Iowa shape pass

> 2026-11-10：以下为早期迭代记录。当前模型、58座游戏清单、来源限制与回归结果以 [S02交付](../../docs/showcase/deliveries/S02.md) 和 [参考包](../../docs/references/ships/iowa_bb61_1944_12_28/modeling-brief.md) 为准；旧截图与原型通过记录不代表本轮验收。

The appearance pass uses the [Trumpeter 1:200 USS Iowa model gallery](https://modellmarine.de/index.php/modelle/497-wolfgang-wurm/5759-schlachtschiff-uss-iowa-1200-trumpeter-von-wolfgang-wurm) for whole-ship oblique and side views, plus the [official NHHC December 1944 full-ship photograph 80-G-K-15631](https://www.history.navy.mil/content/history/nhhc/our-collections/photography/us-navy-ships/battleships/iowa-bb-61/80-G-K-15631.html). The model gallery is a visual aid for silhouette and relative placement, not a dimensional plan. Reference images remain external; none were copied into the project.

## Changes

- Replaced the uniform stack of bridge boxes with a stepped tower made from tapered, faceted volumes and distinct gallery decks.
- Kept bridge wings, battery sponsons, the signal platform, both masts, the aft tower, and the midships gallery in independently inspectable modules.
- Replaced the single shared funnel block with separate forward and after funnel modules. Each has its own uptake trunk, tapered casing, crown, and one outlet.
- Preserved weapon station IDs and transforms; this pass changes their supporting geometry only where the existing platform modules already provide a host.
- Added a shared, batched guardrail builder to the bridge wings, signal platforms, forward battery sponsons, and aft director wings. It uses stanchions with two rails and remains attached to each platform host; post spacing and rail heights are visual estimates.

## Forward bridge and main turret detail pass

The forward bridge lower tower now carries eleven separate framed windows across its forward face, with dark glazing and a shallow brow. The window row follows the modeled forward slope; two exterior ladders connect the bridge-side access levels. Window count, spacing, ladder dimensions, and station heights are visual estimates checked against the October 1944 Iowa photograph and the 28 December 1944 dry-dock view, not shipyard measurements.

The shared 16-inch turret scene now includes two side sight hoods on each side, with optical slots and sliding shutter plates, plus two covered periscope openings on the roof. Their forms follow the later Iowa-class description in OP-769 for USS New Jersey; their exact position on Iowa in December 1944 remains unverified. The scene bake keeps these fittings inside the reusable turret housing so they follow the train pivot with the gunhouse.

Floatplanes remain deferred. Current modeling priority is the weather deck, bridge and other superstructure, and turret geometry.

- [Forward bridge window and access detail](screenshots/bridge_front_detail_pass.png)
- [Bridge and forward turret overview](screenshots/bridge_upperworks_overview_final.png)
- [16-inch turret sight and periscope details](screenshots/main_turret_sight_details_final.png)

## Main turret and hull geometry pass

The 16-inch turret profile now lives in `data/weapon_profiles.json`. OP-769 gives the Iowa-class gunhouse as 39.95 ft wide × 50.62 ft long, with 10 ft from shelf plate to roof; the model converts those values to 12.177 × 15.429 × 3.048 m. The same manual places the outer bore axes 122 in from centerline, the trunnion axis 132 in forward of turret center, and gun overall length at 816 in. OP-769 is a 1968 New Jersey reactivation manual, so these values are shared-class references, not proof of Iowa's exact 1944 exterior fit.

The shell is tapered at the sides and front, with the front wall built around three individual ports. Narrow frames and dark buckler rings replace the previous oversized collars. Each barrel remains on its own elevation pivot and is length-derived from the source dimension. External taper sections, port diameters, and the gun-axis height above the modeled shelf plate remain estimates in the profile data.

The hull still uses the existing 19 hand-entered control sections, but samples each section interval at four subdivisions using bounded cubic interpolation. This keeps the 270.4 m length and 33.0 m maximum beam while softening the bow, sheer, and stern transitions. The section values are not from an offsets plan.

- [Main turret close-up](screenshots/main_turret_geometry_pass.png)
- [Whole-ship turret pass](screenshots/main_turret_overview_pass.png)
- [Hull side profile](screenshots/hull_spline_side_pass.png)
- [Hull three-quarter view](screenshots/hull_spline_overview_pass.png)

## Measure 32 Design 1B paint pass

The 28 December 1944 NARA/NHHC photograph 80-G-421124 shows Iowa high and dry in ABSD-2 with her Measure 32 Design 1B pattern still visible; the NHHC's December at-sea photograph 80-G-K-15631 also identifies the distinctive camouflage. The June 1944 NHHC caption calls out Navy Blue (5-N) and Light Gray (5-L), while the Naval Historical Center camouflage index suggests Dull Black (BK), Light Gray (5-L), and Deck Blue (20-B) as probable colors. Because the Iowa-specific Design 1B drawing has not been located, these are recorded as competing color interpretations rather than settled facts. The hull and stationary superstructure use an authored SVG side mask with hard-edged navy and light-gray blocks; upward-facing surfaces use provisional Deck Blue and the underwater hull uses estimated antifouling red. The main 16-inch and secondary 5-inch housings also sample this mask through a per-mount transform anchored to each turret's neutral heading, keeping the paint attached as the train axis moves. Barrels and smaller AA mounts remain unpainted. The mask is an original visual estimate, not a recovered plan.

- [Measure 32 Design 1B full-ship view](screenshots/measure32_camo_overview.png)
- [Measure 32 Design 1B side view](screenshots/measure32_camo_side.png)

## 5-inch twin mount pass

The shared 5-inch scene represents the Iowa-class Mark 28 Mod 2 enclosed twin mount. Its shell now tapers across the side and front plates; the front face is split around two individual gun ports with narrow frames and dark bucklers. Both barrels remain attached to the shared elevation pivot, matching the twin mount's linked elevation. The 4.826 m bore length is derived from 5-inch × 38 caliber and stored separately from the estimated barrel outside shape. Shield dimensions, plate inclinations, port clearances, and gun spacing remain estimates in `data/weapon_profiles.json`.

- [5-inch twin mount on the assembled ship](screenshots/secondary_5in_geometry_pass.png)
- The viewer exposes this camera as `secondary` or key `6`, so the shared mount can be inspected alongside the surrounding host structure.

## Stern aircraft-handling module pass

The stern fit is now one centerline recovery crane between two separate rotating catapults. This corrects the earlier two-crane assumption: [NHHC 80-G-K-6118](https://www.history.navy.mil/our-collections/photography/numerical-list-of-images/nhhc-series/nh-series/80-G-K-06000/80-G-K-6118.html) is an Iowa photograph whose caption identifies the catapult, stern crane, and OS2U aircraft cart; [80-G-421124](https://www.history.navy.mil/content/history/museums/nmusn/explore/photography/ships-us/ships-usn-i/uss-iowa-bb-61/80-g-421124.html) checks the ship's exact-date, 28 December 1944 arrangement. A [1944 Iowa launch photograph](https://commons.wikimedia.org/wiki/File:USS_Iowa_(BB-61)_Planes.jpg) shows the port catapult preparing to launch in the same direction as the starboard catapult; a veteran-association account describes rotating the port catapult to match that launch heading. This capture shows both tracks parallel in a neutral presentation pose. The [USS Missouri aircraft-hoisting photo](https://www.history.navy.mil/our-collections/photography/us-navy-ships/battleships/missouri-bb-63/80-G-K-4561.html) remains a sister-ship reference for the crane's rig, not its dimensions.

Each catapult now instantiates `scenes/equipment/aircraft_catapult_turntable.tscn`, with its own deck socket, slew bearing, `TrainPivot`, twin launch rails, rigid trussed bed, center launch cylinder, and carriage. The catapult truss carries its own loads from the rotating table; it no longer uses repeated posts that pretend to land on the narrowing stern hull. The single `scenes/equipment/aircraft_crane_lattice.tscn` keeps independent train and boom-elevation pivots, a braced tower and headframe, double-chord boom, sheaves, topping line, cable, and hook.

Current estimated centers are x = ±7.2 m, z = 108 m for the catapult bearings and x = 0 m, z = 114 m for the crane socket. Catapult track length is reduced to about 18.3 m (60 ft) as a scale estimate; widths, headings, and station coordinates remain low-confidence visual estimates in `data/equipment_profiles.json` and `data/december_1944.json`. The photos establish equipment presence and operating arrangement, not an engineering plan.

- [Single crane and twin catapults on the aft deck](screenshots/stern_aircraft_handling_overview.png)
- [Catapult turntable and truss close-up](screenshots/catapult_module_pass.png)
- [Crane and catapult relationship close view](screenshots/aircraft_crane_module_pass.png)
- The viewer exposes the stern overview as `aircraft` or key `7`, catapult close-up as key `8`, and crane close-up as key `9`.

## Native captures

`side.png` is the pre-pass side capture. The new side capture uses the same `side` camera preset. Overview and bridge captures show the new three-quarter and module views.

- [Before, side view](screenshots/side.png)
- [After, side view](screenshots/shape_pass_side.png)
- [After, three-quarter overview](screenshots/shape_pass_overview.png)
- [After, bridge view](screenshots/shape_pass_bridge.png)

Captured with Godot 4.7.2 Compatibility on the Apple M5 using the native viewer. The capture scene saves each image and exits automatically.

## Still rough

These are procedural low-poly volumes, not a scanned or engineering-grade reconstruction. The 19 hull control sections remain estimates and the hull cross-section is still coarse. Platform outlines, stack spacing and heights, window placement, mast bracing, catapult machinery, and many dated fittings need closer shape matching. Limited platform guardrails have been added, but long deck-edge rails, netting, and many small fittings remain absent. Catapult and crane scenes are now reusable but their machinery details and operating motion remain incomplete. Small-caliber weapon modules remain at the migration state listed in [module migration](module_migration.md).
