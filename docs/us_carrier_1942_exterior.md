# Two 1942 American carrier exteriors
These two scenes are nonfunctional static artwork. Bow −Z, upward +Y, study waterline Y=0, metres. Asset scenes lack anything beyond the exterior visual; viewer test does not require a showcase or simulation.

| Ship and appearance | Nominal hull envelope | Exterior cues |
| --- | --- | --- |
| USS Saratoga CV-3, Puget Sound, 14 May 1942 | 270.6624 m × 32.3088 m; 7.3533 m listed original draft (used as display convention, not confirmed May displacement) | tall elongated stack, refit-period pole mast, shorter stepped rounded forward bridge; stack side oval grilles; continuous lengthened timber flight deck with two fixed centreline lift outlines |
| USS Hornet CV-8, Norfolk, 28 Feb 1942 | 246.8118 m × 25.3238 m; 34.7472 m maximum flight deck width; 8.4 m study display draft | compact tripod/short stack group, tiered after catwalks, comparatively shallower and recessed hangar bays, three fixed centreline lift outlines and broad approximate light/dark tonal fields |

Reference points:
- Saratoga [official DANFS](https://www.history.navy.mil/research/histories/ship-histories/danfs/s/saratoga-v.html), [NPS exhibit/research narrative, Ch. 3](https://www.npshistory.com/series/archeology/scrc/37/chap3.htm), NHHC [19-N-29686](https://www.history.navy.mil/our-collections/photography/numerical-list-of-images/nhhc-series/nh-series/19-N-29000/19-N-29686.html) and [19-N-29679](https://www.history.navy.mil/content/history/nhhc/our-collections/photography/numerical-list-of-images/nhhc-series/nh-series/19-N-29000/19-N-29679.html); contemporary U.S. Navy image set [NavSource index, 1942 refit](https://www.navsource.net/archives/02/03a.htm#020343a) (notably photo IDs 020343d/e/g/i/j).
- Hornet [official DANFS](https://www.history.navy.mil/research/histories/ship-histories/danfs/h/hornet-vii.html), NHHC [19-N-28431](https://www.history.navy.mil/our-collections/photography/numerical-list-of-images/nhhc-series/nh-series/19-N-28000/19-N-28431.html) and [19-N-29062](https://www.history.navy.mil/our-collections/photography/numerical-list-of-images/nhhc-series/nh-series/19-N-29000/19-N-29062.html). [Library of Congress HAER description of preceding Yorktown class](https://tile.loc.gov/storage-services/master/pnp/habshaer/wa/wa0300/wa0343/data/wa0343data.pdf) corroborates the class's three lift openings. The similarly named CV-12 is not the subject.
- Plain textile/wood and shades selected from readable values, not exact historical color assertions. Locations and outlines of visible major groups were recreated from the photos. Underside sectional profiles, lift/side fittings dimensions, small obscured details and precise paint boundaries are artist reconstructions, not measured restoration. No internals, operational components or staged events.

Open `res://scenes/ships/us_carrier_1942_visual/saratoga_viewer.tscn` or `res://scenes/ships/us_carrier_1942_visual/hornet_viewer.tscn` (keys 1–4). Automated headless check loads those same viewer scenes and tests the model envelope, fixed lift count and all four camera frames:

```sh
godot --headless --path . --script tests/test_us_carrier_1942_visual.gd
```
