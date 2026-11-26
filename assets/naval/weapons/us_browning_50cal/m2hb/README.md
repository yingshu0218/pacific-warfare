# Browning .50-caliber M2 Heavy Barrel (M2HB)

Standalone M2HB gun body, made as a reusable equipment module. It includes the heavy air-cooled barrel, receiver and feed cover, sights, charging handle, trunnion interface detail, and rear spade grips. The tripod, pintle, naval ring mount, ammunition box, belt, and ship-specific foundation are excluded. In particular, this asset does not assert an Iowa-class or other ship fit.

## Scene interface and dimensions

- Scene: `us_browning_50cal_m2hb.tscn`
- Coordinate convention: +X starboard, +Y up, -Z forward.
- Root origin: estimated elevation/trunnion axis center; units are meters, nominal 1:1 scale.
- The bore centerline is placed 0.05 m above that axis as a geometry estimate; verify it against the selected M2HB receiver/mount drawing before installation.
- Markers: `Generated/MountInterface/ElevationAxis`, port/starboard trunnion centers, and `BoreAxisReference`.
- Nominal overall length: 65.13 in (1.6543 m); nominal barrel length: 45 in (1.143 m), per FM 23-65. External surface proportions, trunnion details, and local component dimensions are visual estimates.
- The inspection scene adds only background, lights, and a camera.

## Provenance

All model geometry is newly authored with Godot primitives; no photograph or third-party mesh is bundled.

1. U.S. War Department, [FM 23-65, Browning Machine Gun, Caliber .50 HB, M2](https://wiki.w9cr.net/images/0/02/FM_23-65_Browning_Machine_Gun_Caliber_.50_HB%2C_M2.pdf), table 1-1. Source for the 65.13-inch overall length, 45-inch barrel, .50 caliber, belt feed, recoil operation, and air cooling.
2. U.S. Army, [M2/M2A1 .50 Caliber Machine Gun portfolio](https://cpeground.army.mil/Equipment/Equipment-Portfolio/PM-SL-Portfolio/M2-M2A1-50-Caliber-Machine-Gun/), official summary of the M2's ground/vehicle roles and separation from the M2A1 quick-change-barrel update.

The manual is linked as a historical source and is not included in this asset folder. No separate image license applies to the procedural model.
