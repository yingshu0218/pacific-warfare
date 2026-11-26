# Browning .30-caliber M1917A1

Standalone U.S. Army service-pattern Browning .30-caliber water-cooled machine-gun body for the M1917A1 configuration. It includes the receiver and belt-feed group, barrel and water jacket, internal steam-tube study, sights, buffer tube, and pistol grip. The M1917A1 was a military-issue weapon; this model is not labeled as a 1913 experimental type.

## Scene interface and dimensions

- Scene: `us_browning_30cal_m1917a1.tscn`
- Coordinate convention: +X starboard, +Y up, -Z forward.
- Root origin: estimated trunnion/elevation-axis center; units are meters, nominal 1:1 scale.
- The bore centerline is placed 0.05 m above that axis as an explicit geometry estimate; verify it against a detailed M1917A1 assembly drawing before a fitted installation.
- Markers: `Generated/MountInterface/ElevationAxis`, port/starboard trunnion centers, and `BoreAxisReference`.
- Standard Ordnance Items Catalog (1944) gives 38.64 in (0.98146 m) overall length and a 23.9 in (0.60706 m) barrel for the M1917A1. The model's receiver details, exact jacket profile, and trunnion spacing are estimated.
- Tripod, pintle foundation, ammunition box, fabric belt, condenser can, hoses, and ship-specific installation are excluded. The inspection scene adds only background, lights, and a camera.

## Provenance

All model geometry is newly authored with Godot primitives; no photograph or third-party mesh is bundled.

1. U.S. War Department, [FM 23-55, Browning Machine Guns, Caliber .30, M1917A1, M1919A4 and M1919A6](https://www.big-red-one.org/FM%2023-55%20M1917%20M1919%20.30%20CAL%20MACHINE%20GUN.pdf), 1945. Used for the service configuration, operation, cooling, feed, and mechanism names.
2. U.S. Ordnance Department, [Standard Ordnance Items Catalog, 1944, Volume III](https://www.90thidpg.us/Reference/Manuals/Standard%20Ordnance%20Items%20Catalog%2C%201944%2C%20Vol%203.pdf), entry “Browning Machine Gun, Cal. .30, M1917A1.” Used for the nominal overall and barrel lengths.

The manuals are linked as historical references and are not bundled. No separate image license applies to the procedural model.
