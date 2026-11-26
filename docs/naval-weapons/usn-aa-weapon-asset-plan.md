# U.S. Navy antiaircraft weapon asset study

Research date: 2026-11-05. This inventory separates an equipment family from a proven fit on any particular ship. Installation photographs, dated ship lists, and installation drawings must establish ship, date, mount mark/modification, shield, and position before an asset is selected for an assembly.

## Build order

| Priority | Asset / mount candidate | Status | Evidence and next decision |
| --- | --- | --- | --- |
| 1 | 40 mm Bofors, four-gun naval Mount Mark 2 Mod. 5 | First independent model made in `assets/naval/weapons/usn_bofors_40mm/mark2_mod5/`. It is a Mark 2 family technical sample; not identified as the exact Iowa fit. | 1942 O.D. 4391 and Mark 2 Mod. 5 Working Circle, Sketch 99008. Render and interface audit are recorded in `docs/naval-weapons/validation.md`. A more detailed assembly drawing set is still needed to verify base dimensions and control linkage. |
| 2 | Browning .30-caliber M1917A1 | Independent military service-pattern gun-body module created at `assets/naval/weapons/us_browning_30cal/m1917a1/`. The tripod and ship foundation are excluded; no Navy shipboard fit is claimed. | FM 23-55 and the 1944 Standard Ordnance Items Catalog document the service configuration and nominal dimensions. The barrel jacket, steam tube, and feed are represented; receiver details and trunnion spacing remain estimates. |
| 3 | Browning .50-caliber M2 Heavy Barrel | Independent M2HB gun-body module created at `assets/naval/weapons/us_browning_50cal/m2hb/`. No ground tripod, naval mount, or ship fit is included. | FM 23-65 supplies nominal overall and barrel lengths and operation/cooling/feed data. Receiver details and trunnion spacing remain estimated. This is separate from O.P. 951's PT-boat Mark 17 twin mount. |
| 4 | 20 mm Oerlikon, single naval pedestal | Planned. Build one complete gun and a source-confirmed mount mark first; treat shields and sight variants as separate assets only where evidence warrants them. | O.P. 911 (March 1943) identifies U.S. Navy gun mechanisms Mark 2/4 and barrel, magazine, sight, and shoulder-rest components. Its preface points to O.P. 909 for mounts Mark 2, 4, 5, 6, 10, and 10 Mod. 1. Confirm an exact dated ship fit before choosing an installation variant. |
| 5 | .50 caliber Browning, twin naval mount | Planned as a dated, explicitly scoped reference sample. O.P. 951's Mount Mark 17 Mod. 1 is a twin aircraft-gun mount documented for PT-boat installation; do not present it as an Iowa or generic battleship fit. | U.S. Navy O.P. 951 (March 1943) covers the Mark 17 Mods. 1/2 and separates its mount, cradles, ammo boxes, link/cartridge chutes, and boat-builder depression stop. Determine whether another Navy shipboard mark is needed for a specific future ship before extending this family. |
| 6 | 5 inch/38 Mark 12 guns, twin Mount Mark 28 Mod. 2 (Iowa class) | Planned next for a source-complete reusable asset. Existing Iowa procedural geometry is owned by the parallel Iowa task; this plan does not edit it. | The dated Iowa record at `iowa/docs/historical_basis.md` supports the class/type but marks exact 1944 local geometry provisional. Consult O.P. 805, 5-inch Twin Gun Mount Mark 28/32/38, plus dated BB-61 ordnance list and engineering drawings. Model the deep base-ring, upper-handling-room interface as a separate foundation/install assembly; never package an Iowa deck or barbette into the reusable mount. |

## Historical fit boundaries

- Iowa's existing December 1944 prototype lists 19 quad 40 mm assemblies and 52 single 20 mm assemblies, but it does not verify an exact-date install plan, per-gun mark/modification, shield pattern, or individual coordinates. This asset plan does not turn those counts into confirmed fittings.
- The .50 caliber Mount Mark 17 Mod. 1 remains a separate planned asset. Its manual documents a PT-boat ring mount; the M2HB body created here does not include that or any other gun mount. The .30-caliber M1917A1 asset is the Army service gun body; an installation requires a separately sourced mount and fit.
- The 5-inch/38 Mark 28 Mod. 2 is an Iowa-class requirement and has no separately assigned reusable-asset task in this repository. The shared Iowa task is building the ship scene; this plan schedules the modular armament asset without modifying its files.
- No mount variant is created by scaling another. Open/shielded arrangements, single/twin/quad assemblies, pedestal/base-ring foundations, ammunition feed, sighting equipment, and movement groups require their own documentary support.

## Primary technical references

1. U.S. Navy Bureau of Ordnance, [O.D. No. 4391, 40-mm Antiaircraft Quad Mount Mark 2, 15 April 1942](https://www.eugeneleeslover.com/AMMUNITION/40MM-GUN-BOOK-OD-4391.php).
2. U.S. Navy Bureau of Ordnance, [40 mm Mount Mark 2 Mod. 5 (Quadruple Mount), Working Circle, Sketch No. 99008, 1942](https://navsource.net/archives/01/pdf/014041mm.pdf).
3. U.S. Navy Bureau of Ordnance, [O.P. 820, 40 mm Antiaircraft Gun, 1943](https://maritime.org/doc/bofors40mm/).
4. U.S. Navy Bureau of Ordnance, [O.P. 911, 20 mm A.A. Gun, 20 mm machine-gun mechanisms Marks 2 and 4, March 1943](https://maritime.org/doc/gun20mm/).
5. U.S. Navy Bureau of Ordnance, [O.P. 951, 0.50-inch Machine Gun Mounts Mark 17 Mods. 1 and 2, March 1943](https://maritime.org/doc/pt/fifty/index.php).
6. NARA's [Bureau of Ordnance Data finding aid](https://www.maritime.org/doc/nara/ordnancedata.php) lists O.P. 909 (20 mm Mounts, 1943), O.P. 805 (5 inch/38 twin mount marks), and O.P. 951. These manual references guide research; they do not prove ship installation.
7. U.S. War Department, [FM 23-55, Browning Machine Guns, Caliber .30](https://www.big-red-one.org/FM%2023-55%20M1917%20M1919%20.30%20CAL%20MACHINE%20GUN.pdf), 1945.
8. U.S. Ordnance Department, [Standard Ordnance Items Catalog, 1944, Volume III](https://www.90thidpg.us/Reference/Manuals/Standard%20Ordnance%20Items%20Catalog%2C%201944%2C%20Vol%203.pdf), M1917A1 entry.

Historical scans remain linked as sources and are not included in the asset library. Mesh files and scripts are project-authored.
