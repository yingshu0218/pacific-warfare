# Japanese naval small-caliber weapon study

## Historical check

- **Type 96 25 mm twin mount:** a genuine naval mount. The U.S. Naval Technical Mission to Japan describes the twin as designed for naval service and reports shipboard single, twin and triple installations. Its 1944 installation table lists Yamato and Musashi with Type 96 triple and single mounts, but no twin mounts. This study therefore does not add a twin mount to the 1944 Yamato loadout.
- **Army Type 92 heavy machine gun:** the island-airfield model is the 7.7 mm Hotchkiss-pattern, air-cooled Army gun. The naval report's 7.7 mm shipboard weapons are the Vickers and Lewis types; it says the small number of imported Vickers guns were installed aboard ships. Its Vickers mount is named “Japanese 92, Model F” and is a height-adjustable tripod. That “92” identifies the mount in the report, not the Army Type 92 Hotchkiss gun.
- **Navy Vickers model:** the study uses a water-cooled, belt-fed Vickers-type gun on a separate Model F tripod. It represents an earlier shipboard weapon family and is not asserted as part of Yamato's 1944 fit.

## Reusable model structure

The weapons and their supports are separate PackedScenes. `type96_25mm_single.tscn` is the reusable gun; `type96_twin_25mm.tscn` assembles two gun scenes at an estimated twin spacing. The cradle, trunnions and sights live with the twin mount in `type96_ship_twin_mount.tscn`. The Vickers gun (`navy_vickers_77mm.tscn`) is separate from its Model F tripod (`japanese_92_model_f_tripod.tscn`). Weapon scene roots are explicitly named `..._Weapon`; mount roots are separate `...Mount` scenes. Each weapon origin is at its attachment axis and each mount exposes a `WeaponSocket`. The study scene attaches the independent weapon scene to that socket for fit viewing; moving either PackedScene does not move or merge the other. This is a scale and interface study, not a recovered ship location.

The 25 mm and 7.7 mm bores use their nominal 1:1 diameters. The Vickers cooling jacket is visibly larger than its bore; it is a water jacket, not a representation of its caliber. The O-47 report gives the Type 96 twin's four hydro-spring recoil cylinders as 16.938 in long and 2.625 in outside diameter, and the paired rear equilibrators as 19.50 in long and 2.56 in outside diameter. Those dimensions now drive the corresponding geometry. The model does not expose coils on the equilibrators because the source gives an envelope but does not document exposed coil geometry.

For the Type 96, the reported 59.125 in barrel, 36 cooling fins, finned-section envelope, and breech-to-muzzle fin diameters now drive the model. Fin spacing distributes the reported fin count over the five finned-section lengths in the report. For the Vickers, the reported 28.4 in barrel assembly and 11 in mechanism length drive the model. The water-jacket length and diameter, receiver profile, and tripod foot spread remain proportional estimates. The tripod is shown at the reported maximum 30 in height; the 78.8 in working-circle dimension is retained as a reported parameter, not treated as its foot spread. Mount and carriage shapes remain procedural proportions, not dimensioned production drawings.

Reference parameters are kept in `data/naval_weapon_profiles.json` and `data/naval_mount_profiles.json`; the scenes under `scenes/weapons/` and `scenes/mounts/` remain independently instantiable. Attach a weapon scene to a compatible mount's `WeaponSocket`, or create a separate ship-side adapter, without making the weapon asset depend on a ship scene.

## Primary sources

1. [U.S. Naval Technical Mission to Japan, O-47(N)-2, *Japanese Naval Guns and Mounts, Article 2: AA Machine Guns and Mounts* (1946)](https://www.fischer-tropsch.org/primary_documents/gvt_reports/USNAVY/USNTMJ%20Reports/USNTMJ-200F-0524-0618%20Report%20O-47%20N-2.pdf) — shipboard Vickers/Lewis use, Model F mount, Type 96 twin mount, and installation tables.
2. [U.S. Navy Bureau of Ordnance and Office of Naval Intelligence, *A Statistical Summary of Japanese Naval Matériel* (ORD-ONI 9, revised 1944)](https://www.ibiblio.org/hyperwar/USN/ref/ORD-ONI-9/index.html) — distinguishes the 7.7 mm Model 92 Hotchkiss-type machine gun from the separate Lewis-type Model 92 entry; describes the 25 mm Type 96 as the principal Navy medium AA gun.
3. [U.S. War Department, TM-E 30-480 (1944), *Japanese Machine Guns*](https://www.lonesentry.com/manuals/handbook-japanese-military/japanese-machine-guns.html) — Army Type 92 heavy-machine-gun form and ammunition-strip feed.

## Browser validation

- Godot 4.7.2 Compatibility import and Web export completed successfully. The Web scene loaded in Safari and Chrome; `M` switched between the Yamato scene and the neutral-deck weapon study in both.
- On the local Apple M5 / 16 GiB system, Chrome showed about 54 FPS in the full-ship view and 57 FPS in the weapon-study view at roughly 3072 × 1728. These are single-session observations, not a performance guarantee.
- Safari rendering and the `M` switch were visually confirmed, but a stable FPS reading was not obtained there. No Safari FPS value is reported.
- The close-up reference image is `docs/naval-weapon-study.png`.
