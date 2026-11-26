# Iowa Measure 32 side mask

`iowa_measure32_1b_side_mask.svg` is a project-authored black-and-white mask used to place broad angular paint fields on the dated USS Iowa model. White maps to Light Gray; black maps to the provisional dark blue paint. The mask is an approximation, not a tracing or scan of a Navy plan.

## References

- [NHHC 80-G-421124](https://www.history.navy.mil/content/history/museums/nmusn/explore/photography/ships-us/ships-usn-i/uss-iowa-bb-61/80-g-421124.html) — Iowa in floating dry dock at Manus, 28 December 1944.
- [NHHC 80-G-K-15631](https://www.history.navy.mil/content/history/nhhc/our-collections/photography/us-navy-ships/battleships/iowa-bb-61/80-G-K-15631.html) — Iowa at sea with Task Force 38, December 1944.
- [NHHC 80-G-K-14182](https://www.history.navy.mil/our-collections/photography/numerical-list-of-images/nara-series/80-g-k/80-G-K-14000/80-G-K-14182.html) — June 1944 caption identifies Navy Blue 5-N and Light Gray 5-L.
- [Naval Historical Center Measure 32 index](https://www.ibiblio.org/hyperwar/OnlineLibrary/photos/sh-co-mk/camouflg/usn-wwii/3--bb3.htm) — identifies Design 1B but notes that its drawing is unavailable and gives a different probable color interpretation.

The same provisional side map is used on port and starboard because no Iowa-specific Design 1B plan is available to establish the opposite side's layout. The artwork is original and copies no source photograph or scanned drawing; no external asset license is relied on.

## S02 root / standalone portability

The original SVG text is embedded in `scripts/iowa_camouflage_mask.gd` and turned into a shared ImageTexture at runtime. This preserves the same authored mask while avoiding a `.import` sidecar shared between two resource roots. The original SVG remains the authoring source; update the embedded string alongside it. The embedded source is also available in a Web pack without relying on an external raw SVG file.
