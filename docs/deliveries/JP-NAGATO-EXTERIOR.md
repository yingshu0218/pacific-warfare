# Nagato · 1944 archive exhibit

Playable-world neutral Godot exterior asset. Open `scenes/ships/jp_nagato/nagato_visual.tscn`; this is not yet cataloged, assigned to a team, or embedded in a battle scene.

## Visual verification

- Primary: [Kure Maritime Museum photo of Nagato at Brunei, 21 October 1944](https://commons.wikimedia.org/wiki/File:Japanese_Battleship_Nagato_1944.jpg). Compared a matching low bow quarter: steep bow sheer, stacked forward pagoda, one oval funnel, lighter aft tripod and signal yards, paired fore/aft terraces, boat grouping and open handling deck aft.
- Context: [NHHC NH 73090, Brunei October 1944](https://www.history.navy.mil/our-collections/photography/numerical-list-of-images/nhhc-series/nh-series/NH-73000/NH-73090.html), with Nagato on the right, supports the broad profile and asymmetry of the superstructures. [NHHC 80-G-343773, Yokosuka 1945](https://www.history.navy.mil/content/history/museums/nmusn/explore/photography/wwii/wwii-pacific/bombardment-japan/aerial-naval-gunfire-japanese-home-islands/80-g-343773.html) supplies an overhead check of the hull and long end decks, not a template for the 1944 fit.
- Hull underside, materials, minor fittings and flank displays are artistic choices where these photographs do not support precise tracing. This is a silhouette-first art exhibit rather than an exact equipment inventory or scale construction plan.

## Engine checks

Visual inspection of native Godot Compatibility captures: three-quarter, low bow quarter, side, deck, stern quarter, and a separate articulation pose. All four centerline and six smaller depicted display mounts are individually posed through the shared archive rig. The art has no aiming control, firing, ballistic, damage or other combat integration. Broadside shadowed openings are inert hull surface relief, not additional operable meshes.

Run `godot --headless --path . --script scenes/ships/jp_nagato/verify.gd` for mount count, exterior mesh presence, per-mount display traverse and pitch, isolated neighbor transforms, stationary hull, and neutral reset. Current result: 143 checks, 0 failures.
