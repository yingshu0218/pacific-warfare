#!/usr/bin/env python3
"""Snapshot OPS and apply only the four accepted S04 inputs inside a private stage."""
from pathlib import Path
import argparse
import hashlib
import json
import shutil

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "candidates/s04-carrier-usage/candidate-manifest.json"
EXPECTED = "379681d3aa81909d08a1e7c28a323ca7bac03054a390e2efb83d558ec8c9a3f3"
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--name", required=True)
args = parser.parse_args()
if hashlib.sha256(MANIFEST.read_bytes()).hexdigest() != EXPECTED:
    raise SystemExit("Accepted S04 manifest drift")
manifest = json.loads(MANIFEST.read_text())
stage = ROOT / ".local/ops01-model" / args.name
if stage.exists():
    raise SystemExit("Use a new immutable stage name")
extensions = {".gd", ".gdshader", ".tscn", ".tres", ".json", ".uid", ".py"}
runtime = json.loads((ROOT/"tools/showcase_runtime.json").read_text())
inputs = set(runtime["files"])
for folder in ["scripts/air_operations","tests/air_operations","naval/essex_cv9_1944_04_15"]:
    for path in (ROOT/folder).rglob("*"):
        if path.is_file() and (path.suffix in extensions or path.name == ".gdignore"):
            inputs.add(str(path.relative_to(ROOT)))
for name in ["aircraft_fixture","combat_fixture","combat_test","aircraft_damage_fixture"]:
    inputs.add("tests/fixtures/"+name+".gd")
inputs.add("project.godot")
for name in sorted(inputs):
    source = ROOT/name
    target = stage/name
    target.parent.mkdir(parents=True,exist_ok=True)
    shutil.copy2(source,target)
# Preserve ancestor ignore boundaries wherever an explicitly admitted subtree has
# one. No recursive copy of active AV/AU work is performed.
for name in sorted(inputs):
    for ancestor in (ROOT/name).parents:
        if ancestor == ROOT: break
        marker = ancestor/".gdignore"
        if marker.is_file():
            target = stage/marker.relative_to(ROOT)
            target.parent.mkdir(parents=True,exist_ok=True); shutil.copy2(marker,target)
for row in manifest["destinations"]:
    source = ROOT / row["candidate"]
    if hashlib.sha256(source.read_bytes()).hexdigest() != row["after_sha256"]:
        raise SystemExit("Candidate drift: "+str(source))
    target = stage / row["destination"]
    target.parent.mkdir(parents=True,exist_ok=True)
    shutil.copy2(source,target)
out = stage/"docs/showcase/evidence/OPS01"
out.mkdir(parents=True)
(out/".gdignore").touch()
files = {str(p.relative_to(stage)):hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(stage.rglob("*")) if p.is_file()}
record = {"scope":"tools/showcase_runtime.json admitted files + CV01 + OPS + four explicit fixtures + four S04 replacements; no AV02/G4M/AU01 recursion","runtime_whitelist_sha256":hashlib.sha256((ROOT/"tools/showcase_runtime.json").read_bytes()).hexdigest(),"stage":str(stage),"S04_manifest_sha256":EXPECTED,"S04_destinations":manifest["destinations"],"inputs":files}
(stage/"input-manifest.json").write_text(json.dumps(record,indent=2)+"\n")
delivery = ROOT/"docs/showcase/evidence/OPS01/model-resume"/args.name
delivery.mkdir(parents=True,exist_ok=True)
(delivery/"input-manifest.json").write_text(json.dumps(record,indent=2)+"\n")
print(json.dumps({"stage":str(stage),"input_count":len(files),"candidate_files":4}))
