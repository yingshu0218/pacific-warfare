#!/usr/bin/env python3
"""Create a runtime candidate snapshot; never replace admitted model sources."""
from pathlib import Path
import argparse
import datetime
import hashlib
import json
import shutil

ROOT = Path(__file__).resolve().parents[2]
CANDIDATE = ROOT / "candidates/s04-carrier-usage"
parser = argparse.ArgumentParser()
parser.add_argument("--name", default="r1")
args = parser.parse_args()
stage = ROOT / ".local/s04-carrier-usage" / args.name
if stage.exists():
    raise SystemExit("Use a new stage name; validation snapshots are immutable.")
baseline = json.loads((CANDIDATE / "baseline-hashes.json").read_text())
for name, expected in baseline["files"].items():
    if hashlib.sha256((ROOT / name).read_bytes()).hexdigest() != expected:
        raise SystemExit("Public model drift before candidate preparation: "+name)
extensions = {".gd", ".gdshader", ".tscn", ".tres", ".json", ".otf", ".uid",
              ".png", ".import", ".wav", ".ogg", ".svg", ".glb", ".webp"}
def ignore(directory, names):
    return [name for name in names if
            (Path(directory, name).is_dir() and name in {
                ".godot", "screenshots", "evidence", "backups", "reference",
                "references", "docs", "air_operations"}) or
            (Path(directory, name).is_file() and Path(name).suffix not in extensions
             and name != "LICENSE.txt")]
for folder in ["scripts", "scenes", "data", "assets", "aircraft", "ui", "showcase",
               "naval/essex_cv9_1944_04_15"]:
    shutil.copytree(ROOT / folder, stage / folder, ignore=ignore)
shutil.copyfile(ROOT / "project.godot", stage / "project.godot")
for name in baseline["files"]:
    shutil.copyfile(CANDIDATE / name, stage / name)
for source in (CANDIDATE / "scripts/aircraft_geometry").glob("*.gd"):
    target = stage / source.relative_to(CANDIDATE)
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source, target)
shutil.copytree(ROOT / "tests/s04_carrier_usage", stage / "tests/s04_carrier_usage", ignore=ignore)
shutil.copyfile(CANDIDATE / "baseline/aircraft/models/f6f5.gd", stage / "tests/s04_carrier_usage/baseline_f6f5.gd")
for name in ["combat_test", "combat_fixture", "aircraft_fixture", "aircraft_damage_fixture"]:
    target = stage / "tests/fixtures" / (name+".gd")
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(ROOT / "tests/fixtures" / (name+".gd"), target)
for name in ["tests/test_aircraft_damage_models.gd", "tests/test_aircraft_damage.gd"]:
    target = stage / name
    shutil.copyfile(ROOT / name, target)
    text = target.read_text().replace("res://docs/showcase/evidence/DM01/",
                                     "res://docs/showcase/evidence/S04-carrier-usage/regressions/")
    target.write_text(text)
(stage / "docs/showcase/evidence/S04-carrier-usage/regressions").mkdir(parents=True, exist_ok=True)
manifest = {"created_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
            "stage": str(stage), "scope": "Candidate model/adapter only; OPS logic excluded.",
            "sources": {str(p.relative_to(stage)): hashlib.sha256(p.read_bytes()).hexdigest()
                        for p in sorted(stage.rglob("*")) if p.is_file()}}
(stage / "input-manifest.json").write_text(json.dumps(manifest, indent=2)+"\n")
out = ROOT / "docs/showcase/evidence/S04-carrier-usage" / args.name
out.mkdir(parents=True, exist_ok=True)
(out / "input-manifest.json").write_text(json.dumps(manifest, indent=2)+"\n")
print("Prepared isolated candidate", stage, "files", len(manifest["sources"]))
