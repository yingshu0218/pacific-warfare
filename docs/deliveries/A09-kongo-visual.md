# Kongō | rebuilt October 1938 static game exterior

New rebuild after the earlier local V2 source could not be located. Target is the 1930s modernization appearance, **not the 1944 naval configuration**. This source is purely a standalone visual model, without functioning systems or game-unit registration.

- I viewed [NH 80898, Kongō off Amoy, October 1938](https://www.history.navy.mil/content/history/nhhc/our-collections/photography/numerical-list-of-images/nhhc-series/nh-series/NH-80000/NH-80898.html) [scan](https://www.ibiblio.org/hyperwar/OnlineLibrary/photos/images/h80000/h80898.jpg), distant side for identity/date and coarse relative heights.
- I viewed [NH 90512, after the 1936–37 modernization](https://www.history.navy.mil/content/history/nhhc/our-collections/photography/numerical-list-of-images/nhhc-series/nh-series/NH-90000/NH-90512.html) [scan](https://www.ibiblio.org/hyperwar/OnlineLibrary/photos/images/h90000/h90512.jpg) for the broad gradual forward sheer, staggered layered bridge overhangs, separate funnel masses, triangular aft tripod and stepping down toward the stern. Neither photo establishes the exact layout visible from above or the hull below water.
- The 222 × 31 m envelope and 9.6 m study depth are modeled reference estimates, not measurements recovered from either photo; colors, unseen layout and small furnishings are game interpretations. Proven date is for the visual reference only. No historical magazine or archival photo was copied into runtime resources.

Open `res://scenes/ships/kongo_1938/kongo_viewer.tscn` to inspect. In Godot 4.7.2, `godot --headless --script tests/model_audit/test_bb57_kongo_exteriors.gd` verified 222 × 31 × 9.6 m modeled dimensions, closed hull, 8,532 triangles, and four views.
