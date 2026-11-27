# South Dakota BB-57 | rebuilt static game exterior

The earlier local V2 could not be found in this workspace. This is a new exterior, not a byte-for-byte restoration or a claim of prior approval. No scripts or connections for functioning systems, no roster/scenario edits.

## Exterior reference

- [U.S. Navy DANFS BB-57](https://www.history.navy.mil/research/histories/ship-histories/danfs/s/south-dakota-ii-bb57-1943-44.html) anchors the post-refit trials on 21 August 1944. [DANFS ship profile](https://www.history.navy.mil/research/histories/ship-histories/danfs/s/south-dakota-ii-bb57-1941-42.html) lists 680 ft × 108 ft 2 in; those convert to a 207.264 × 32.969 m game maximum hull envelope.
- I inspected the U.S. Navy Yard [21 August port quarter NARA 19-LCM BS 70906](https://commons.wikimedia.org/wiki/File:USS_South_Dakota_in_Puget_Sound_NARA_BS_70906.jpg), [cropped port angle](https://www.navsource.net/archives/01/015745.jpg) and [raised stern](https://www.navsource.net/archives/01/015744.jpg). The two port angles are the same exposure, not separate evidence. I also inspected Navy 2862-44 [starboard broadside](https://www.navsource.net/archives/01/057/015700o.jpg): **the printed caption says 24 August** despite the NavSource row calling it the 21st; it is supporting same-ship evidence three days later, not the same shot.
- Photo-backed exterior choices: compact forward bridge galleries, a single broad funnel amidships, closely grouped deck housings, fuller stern with distinct fitted deck shape and the characteristic curved forward sheer. This is not a measured reconstruction. Colors are neutral game study values; no claim that monochrome photos substantiate the paint hues. The 8.690 m study depth and complete submerged shell are visual estimates, not converted from a particular drydock photo or an operational figure. Raw archive images were not shipped as textures.

## Check

`res://scenes/ships/south_dakota_bb57/bb57_viewer.tscn` is independent viewer (keys 1–4). Godot 4.7.2 `godot --headless --script tests/model_audit/test_bb57_kongo_exteriors.gd` measured 207.264 × 32.969 × 8.690 m (length, beam, study depth), 9,008 faces, closed hull, and four angles. Existing general game integration was not exercised or modified by this isolated asset check.
