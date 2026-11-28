# Nagato · October 1944 archive exhibit

The Godot archive gallery contains the revised static exterior. The standalone model entry remains `scenes/ships/jp_nagato/nagato_visual.tscn`. This is exhibition geometry and has not been assigned to a team or battle scene.

## Revision 2

- Rebuilt the generic uniform bridge stack as separate faceted observation terraces, with varied reaches, recessed galleries, glazed cabin bands and a visible top lattice. Reworked the single funnel as a shaped shell and recessed opening; added definition to the aft tripod and changed the stern from two simple poles to one offset crane.
- Sharpened the bow profile, added visually seated hawse relief and scuttles, clarified the aft deck step and made the foredeck and wood planking readable. Reworked the four large display housings with a crisp flat roof and closed tapered display profiles; existing decorative posing interfaces and placement remain compatible.
- Dated reference: [Kure Maritime Museum's Nagato at Brunei, 21 October 1944](https://commons.wikimedia.org/wiki/File:Japanese_Battleship_Nagato_1944.jpg). The full archival photo was compared with the low-bow Godot view for the forward bridge mass, break between the bridge and funnel, aft mast and crane, and visible foredeck silhouettes. [NHHC NH 73090](https://www.history.navy.mil/our-collections/photography/numerical-list-of-images/nhhc-series/nh-series/NH-73000/NH-73090.html) gives period context. The shot has perspective and occlusion: color, fine fittings and the far side remain illustrative, not measured reproduction. The underbody was not historically verified.
- This is an art-only revision. No new movement controls or gameplay wiring.

## Verification

- Native Godot Compatibility captures: low bow quarter, broadside, aft quarter, overhead and bridge detail. Old and new low-bow screenshots share identical camera and lighting settings.
- `scenes/ships/jp_nagato/verify.gd`: 149 checks, 0 failures, including separate enclosure motion, isolation from neighbors, reset, all eight bridge levels, distinct funnel shell and opening, and presence of deck seams and crane geometry.
- `tests/model_audit/test_archive_finish.gd`: 38 ships and 18 aircraft; no failures. `tests/model_audit/test_archive_gun_rigs.gd`: 1,367 checks; no failures.
