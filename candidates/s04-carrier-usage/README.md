# S04 F6F carrier usage candidate

r10 is the final private, natively reviewed candidate. The public model sources remain unchanged; `.gdignore` keeps this directory out of the ordinary Godot project. Use `candidate-manifest.json` for exact source hashes and admission status.

`carrier-usage.patch` changes only the three saved baseline paths and adds `scripts/aircraft_geometry/f6f5_carrier_geometry.gd`. Its dry-run and real application were checked in disposable baseline copies; no patch was applied to the public checkout. `baseline/` and `baseline-hashes.json` retain the three admitted source versions because this checkout has no Git recovery point.

The isolated validated runtime is `.local/s04-carrier-usage/r10`; complete frozen input hashes are recorded there and in `docs/showcase/evidence/S04-carrier-usage/r10/input-manifest.json`. Rebuilding uses `python3 tools/s04_carrier_usage/prepare_stage.py --name NEW_UNIQUE_NAME`, which checks the public baseline first and never overwrites a stage.

Read `docs/air_operations/S04-carrier-usage-contract.md` before OPS consumption. The CPU geometry helper is authoritative; it has no Node/render dependency. Earlier coplanar wheel points, long hook geometry and OPS pitch=0 parked/approach snapshots are obsolete. The three-circle parked transform is a static fixture, not a runtime landing integrator.

Full delivery and limitations: `docs/showcase/deliveries/S04-carrier-usage.md`. No Chrome test, OPS implementation, folding-wing mechanism or public source admission is included here.
