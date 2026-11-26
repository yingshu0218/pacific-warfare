#!/usr/bin/env python3
"""Freeze reviewable OPS sources and audit only validation-owned process groups."""
import argparse
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[2]
EVIDENCE = ROOT / "docs/showcase/evidence/OPS01"


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--label", required=True)
    args = parser.parse_args()
    target = EVIDENCE / args.label
    target.mkdir(parents=True, exist_ok=True)
    extensions = {".gd", ".tscn", ".tres", ".gdshader", ".json", ".py", ".uid"}
    files = set()
    for directory in ["scripts", "data", "aircraft", "assets/naval/weapons/usn_bofors_40mm", "naval/essex_cv9_1944_04_15", "scenes/ships/destroyer_modules", "tests/air_operations", "tests/fixtures"]:
        for path in (ROOT / directory).rglob("*"):
            if path.is_file() and path.suffix in extensions:
                files.add(path)
    files.update(ROOT / x for x in ["project.godot", "tools/verify.py"])
    sources = {}
    for path in sorted(files):
        relative = path.relative_to(ROOT)
        before = digest(path)
        copy = target / "inputs" / relative
        copy.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, copy)
        if digest(copy) != before or digest(path) != before:
            raise RuntimeError("Source changed while freezing: " + str(relative))
        sources[str(relative)] = before
    baseline = json.loads((ROOT / "docs/air_operations/OPS01/baseline-hashes.json").read_text())
    baseline_deltas = {p: {"baseline": old, "current": digest(ROOT / p)} for p, old in baseline.items() if digest(ROOT / p) != old}
    runs = []
    groups = set()
    for path in sorted((ROOT / ".local/validation/runs").glob("*/report.json")):
        report = json.loads(path.read_text())
        if report.get("owner") != "OPS01":
            continue
        runs.append({"report": str(path.relative_to(ROOT)), "passed": report["passed"], "action": report["action"],
                     "error": report.get("error"), "checks": [{k: c.get(k) for k in ["pid", "process_group", "passed", "cleanup_ok", "timed_out", "diagnostic_error"]} for c in report["checks"]]})
        for check in report["checks"]:
            if check.get("process_group"):
                groups.add(check["process_group"])
    live = []
    for group in sorted(groups):
        try:
            os.killpg(group, 0)  # Read-only existence probe, never cleanup by name.
        except ProcessLookupError:
            continue
        live.append(group)
    evidence = {str(p.relative_to(ROOT)): digest(p) for p in EVIDENCE.rglob("*") if p.is_file() and target not in p.parents and p.suffix in {".png", ".json", ".mp4"}}
    result = {"created_utc": dt.datetime.now(dt.timezone.utc).isoformat(), "scope": args.label,
              "source_count": len(sources), "sources": sources, "evidence": evidence,
              "shared_baseline_deltas": baseline_deltas,
              "shared_delta_note": "OPS did not edit shared sources; concurrent S08 changes are recorded rather than claimed unchanged.",
              "validation_runs": runs, "registered_process_groups": sorted(groups), "live_registered_groups": live,
              "cleanup_passed": not live, "browser_started_by_OPS01": False}
    (target / "audit.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps({k: result[k] for k in ["scope", "source_count", "cleanup_passed", "live_registered_groups"]}))
    if live:
        raise RuntimeError("A validation-owned process group remains live")


if __name__ == "__main__":
    main()
