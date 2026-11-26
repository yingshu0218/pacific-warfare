# 40 mm quad mount, Mark 2 Mod. 5 — geometry study

This is an independently instantiable Godot scene for the U.S. Navy Bofors 40 mm quad mount family. It is a **source-led geometry study**, not a shipyard reconstruction and not an assertion that this exact modification was fitted to USS Iowa on a particular date.

## Interface

- Scene root origin: the mount's deck-contact plane and the vertical training axis intersection.
- Forward: local `-Z`; `+X` is starboard; `+Y` is up.
- Unit scale: meters, 1:1; the root should stay at `(1, 1, 1)`.
- `Generated/MountFoundation/DeckContact`: local `(0, 0, 0)` is the host surface.
- `Generated/MountFoundation/WeaponSeat`: the top of the modeled fixed stand. The stand is part of the Mark 2 assembly; no ship-specific platform, coaming, or support is included.
- `Generated/TrainPivot`: independently controlled 360-degree rotation about local `+Y`.
- `Generated/TrainPivot/ElevationPivot`: independently controlled gun elevation about local `+X`; positive values raise the muzzles.
- Exported properties `train_degrees`, `elevation_degrees`, and `shielded`, plus `set_train_angle()` and `set_elevation()`, provide a small presentation API. The travel stops are set to -5 and +90 degrees from the 1942 Mark 2 Mod. 5 working-circle drawing; actual drive rates and ship-specific stop modifications are not modeled.
- The mount has 18 visible 1-inch-diameter deck bolts. Their 0.0254 m diameter is from the drawing. The bolt-circle radius used by the mesh is an estimate from the diagram, not a recovered installation dimension.

## Modeled and estimated geometry

The four water-cooled guns, receiver and feed groups, clip guides, cradle, training carriage, handwheels, operator seats, sight study, and the shield are separate named mesh nodes. The shield can be toggled off in the Inspector. The plate thickness of 0.009525 m (3/8 inch) is marked on the drawing; its panel outline and all unsourced component dimensions are proportions estimated from the drawings and photographs. The carriage keeps a continuous, low underframe and central rotating hub; isolated outboard rectangular feet from the first pass were removed because the available references do not establish them.

The 40 mm bore diameter is nominal. The nominal rifled length is calculated from the Navy gun designation's 56-caliber barrel (`0.04 × 56 = 2.24 m`); the external barrel, water jacket, receiver, mount, base-ring diameter, carriage outline, sight, and operating arrangements are simplified estimates. Dimensions are not all established by the source drawings available for this study. Individual gun train and elevation are coupled in this first assembly; the manual's detailed linkage arrangement has not been reconstructed. The 1942 drawing date is the earliest design record used for this asset, not a separately confirmed service-entry date.

`ShieldFixedToCarriage` is carried by the train axis and remains level during gun elevation. The operator floor, seats, controls, and shield are likewise attached to the rotating carriage. These motion groupings are a documented modeling choice pending a full drawing-by-drawing reconstruction; do not treat them as a substitute for the full ordnance assembly drawings.

## Provenance and license

All mesh geometry is authored procedurally for this project. No scan, photograph, texture, or third-party mesh is bundled.

1. U.S. Navy Bureau of Ordnance, **O.D. No. 4391, 40-mm Antiaircraft Quad Mount Mark 2: Description and Operation (Preliminary)**, 15 April 1942. Transcribed copy and original handbook scan: [Gene Slover's U.S. Navy Pages](https://www.eugeneleeslover.com/AMMUNITION/40MM-GUN-BOOK-OD-4391.php). Used for names and relationships of stand, base ring, training circle, carriage, elevating gear, platform, and operator seats.
2. U.S. Navy Bureau of Ordnance, **40 mm Mount Mark 2 Mod. 5 (Quadruple Mount), Working Circle**, Bureau of Ordnance Sketch No. 99008, 1942. Archival drawing scan: [NavSource PDF](https://navsource.net/archives/01/pdf/014041mm.pdf). Used for the 18 × 1-inch installation bolt note, shield thickness, and -5/+90-degree travel. The sketch marks the circular bulwark as not supplied by the Bureau of Ordnance, so none is included here.
3. U.S. Navy Bureau of Ordnance, **O.P. 820, 40 mm Antiaircraft Gun**, 1943. [Maritime.org manual index and pages](https://maritime.org/doc/bofors40mm/). Used as the period description of the Navy gun mechanisms and water-cooled installation.

The linked sources are historic technical references. Their scans remain external and are not redistributed by this project. The project's procedural geometry is newly authored; no separate image license applies.
