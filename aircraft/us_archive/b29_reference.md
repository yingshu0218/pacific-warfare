# B-29 Superfortress · Marianas 1945 exterior

`b29.tscn` is an independent art model for a representative conventional B-29 in
1945. The generic bare-metal finish and period family markings do not portray
an identified airframe. The model excludes Silverplate-specific fit-out and
uses only static nose glazing, fuselage fairings, airframe, nacelles, propellers
and alternate cosmetic gear. The optional `parked_gear` flag selects a fixed
parked pose at scene load; no game controls or collision are attached.

## Exterior references

- [USAF National Museum B-29 fact sheet](https://www.nationalmuseum.af.mil/Visit/Museum-Exhibits/Fact-Sheets/Display/Article/196252/USAFmuseum/boeing-b-29-superfortress/):
  family envelope only (99 ft length, 141 ft 3 in span, 27 ft 9 in parked
  height); the displayed Bockscar's markings or special configuration are not
  copied.
- [Doc's Friends restoration archive](https://www.b29doc.com/docs-story/):
  standard exterior reference, not a wartime Pacific identity or paint match.
- [U.S. Naval History and Heritage Command, 80-G-K-2980](https://www.history.navy.mil/our-collections/photography/numerical-list-of-images/nhhc-series/nh-series/80-G-K-02000/80-G-K-2980.html):
  period Pacific photography. The displayed game model does not reproduce
  the markings of the photographed 42-24797.

Godot 4.7.2 validation measured mesh bounds of 30.175 m long and 43.053 m wide;
parked height is 8.470 m. Both static poses instantiated without errors; a
native orthographic review covered front three-quarter, side, and plan views.

## Profile refinement

The static front cap and pilot windshield were compared with the front and
side images of restored Doc in [DVIDS photo 5526641](https://www.dvidshub.net/image/5526641/docs-wings-over-whiteman-2019),
[photo 5526690](https://www.dvidshub.net/image/5526690/b-29-display-during-whiteman-air-force-base-air-space-show-2019),
and the [Doc's Friends gallery](https://www.b29doc.com/gallery/). The revision
wraps the nose glazing around the rounded leading cap, staggers crew windows
across the same shell, and shades the circular metal skin continuously instead
of adding a hard colour band. It also distinguishes the inboard and outboard
cowling silhouettes, raises the visual nacelle rim, and softens the crown and
root of the single tail fin. The images informed exterior geometry only, not
markings, component construction or gameplay.
