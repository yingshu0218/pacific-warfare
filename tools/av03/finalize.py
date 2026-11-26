#!/usr/bin/env python3
"""Read/hash/archive already-closed AV03 evidence. Never launches an engine/browser."""
from pathlib import Path
import datetime as dt
import hashlib
import json
import os
import shutil
import struct

ROOT = Path(__file__).resolve().parents[2]
EVIDENCE = ROOT / "docs/showcase/evidence/AV03"


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return json.loads(path.read_text())


def write(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n")


def main():
    baseline = read(EVIDENCE / "baseline.json")
    interface = read(ROOT / "aircraft/g4m1/data/interfaces.json")
    if interface["failures"] or interface["checks"] != 167:
        raise SystemExit("Current contract validation is not the final 167-check run.")
    for name, expected in interface["source_hashes"].items():
        if digest(ROOT / name) != expected:
            raise SystemExit("Stale interface dependency: " + name)
    captures = []
    for png in sorted((EVIDENCE / "final").glob("*.png")):
        meta_file = Path(str(png) + ".json")
        meta = read(meta_file)
        for name, expected in meta["source_hashes"].items():
            if digest(ROOT / name) != expected:
                raise SystemExit("Stale capture source: " + png.name + " " + name)
        if struct.unpack(">II", png.read_bytes()[16:24]) != (1440, 900):
            raise SystemExit("Wrong capture size: " + png.name)
        if meta["model_scale"] != [1.0, 1.0, 1.0]:
            raise SystemExit("Model scale changed: " + png.name)
        captures.append({"file":str(png.relative_to(ROOT)), "sha256":digest(png),
                         "metadata":str(meta_file.relative_to(ROOT)), "metadata_sha256":digest(meta_file),
                         "view":meta["view"]})
    if len(captures) != 20:
        raise SystemExit("Expected 20 final native captures.")
    source_paths = []
    for directory in ["aircraft/g4m1", "tests/av03", "tools/av03"]:
        source_paths.extend(p for p in (ROOT / directory).rglob("*") if p.is_file() and p.suffix in [".gd", ".uid", ".tscn", ".py", ".json", ".md"])
    source_paths += [ROOT / "docs/showcase/deliveries/AV03.md", ROOT / "docs/deliveries/AV03.md"]
    source_hashes = {}
    for path in sorted(set(source_paths)):
        name = str(path.relative_to(ROOT))
        dest = EVIDENCE / "inputs" / name
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, dest)
        source_hashes[name] = digest(path)
    readonly_paths = set(interface["source_hashes"]) - set(source_hashes)
    readonly_paths.add("project.godot")
    readonly_hashes = {name:digest(ROOT / name) for name in sorted(readonly_paths)}
    for name, expected in readonly_hashes.items():
        path = ROOT / name
        if digest(path) != expected:
            raise SystemExit("Read-only dependency changed before freezing: " + name)
        dest = EVIDENCE / "inputs" / name
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, dest)
        if digest(dest) != expected:
            raise SystemExit("Frozen dependency copy differs: " + name)
    refs = ROOT / "docs/references/aircraft/g4m1_1942"
    reference_hashes = {str(p.relative_to(ROOT)):digest(p) for p in sorted(refs.rglob("*")) if p.is_file() and p.suffix != ".import"}
    baseline_comparison = {}
    for group in ["shared_baseline", "map02_readonly_baseline"]:
        for name, expected in baseline.get(group, {}).items():
            actual = digest(ROOT / name)
            baseline_comparison[name] = {"before":expected,"after":actual,"same":expected == actual}
    if not baseline_comparison["aircraft/sb2c4/sb2c4.gd"]["same"]:
        raise SystemExit("Frozen SB2C changed; do not package as unchanged.")
    write(EVIDENCE / "baseline-comparison.json", baseline_comparison)
    runs = []
    groups = []
    remaining = []
    unknown = []
    for report_path in sorted((ROOT / ".local/validation/runs").glob("*/report.json")):
        report = read(report_path)
        if report.get("owner") != "AV03":
            continue
        dest = EVIDENCE / "validation" / report["run_id"]
        dest.mkdir(parents=True, exist_ok=True)
        files = [report_path] + sorted(report_path.parent.glob("*.log"))
        log_hashes = {}
        for path in files:
            shutil.copy2(path, dest / path.name)
            log_hashes[str((dest / path.name).relative_to(ROOT))] = digest(path)
        checks = []
        for check in report.get("checks", []):
            checks.append({k:check.get(k) for k in ["command","returncode","timed_out","diagnostic_error","cleanup_ok","process_group","duration_s","passed"]})
            pgid = check.get("process_group")
            if pgid:
                groups.append(pgid)
                try:
                    os.killpg(pgid, 0)  # Existence probe only; no signals sent.
                except ProcessLookupError:
                    pass
                except PermissionError:
                    unknown.append(pgid)
                else:
                    remaining.append(pgid)
        runs.append({"run_id":report["run_id"],"action":report["action"],"passed":report["passed"],
                     "exit_code":report["exit_code"],"error":report.get("error"),"checks":checks,"log_hashes":log_hashes})
    if remaining or unknown:
        raise SystemExit("Owned process groups unresolved: " + repr([remaining, unknown]))
    write(EVIDENCE / "verification-index.json", runs)
    lock = read(ROOT / ".local/validation/godot-render.lock")
    cleanup = {"checked_utc":dt.datetime.now(dt.timezone.utc).isoformat(), "recorded_process_groups":groups,
               "remaining_groups":remaining,"unknown_groups":unknown,
               "all_child_cleanup_ok":all(c["cleanup_ok"] for r in runs for c in r["checks"]),
               "all_wrapper_runs_passed":all(r["passed"] for r in runs),"created_browser_tabs":0,"created_http_services":0,
               "started_editor":False,"started_ffmpeg":False,"lock_at_audit":lock,
               "own_lock_held":lock.get("owner") == "AV03" and lock.get("status") == "held",
               "scope":"AV03 recorded groups only; no signals sent to user/OPS01 processes"}
    write(EVIDENCE / "cleanup.json", cleanup)
    hashes = {str(p.relative_to(ROOT)):digest(p) for p in [EVIDENCE / "contracts.json", EVIDENCE / "comparison.md", EVIDENCE / "verification-index.json", EVIDENCE / "cleanup.json", EVIDENCE / "baseline-comparison.json"]}
    manifest = {"date_cn":"2026-11-11","generated_utc":dt.datetime.now(dt.timezone.utc).isoformat(),
                "status":"model_frozen_native_checks_complete_pending_coordinator_final_acceptance",
                "geometry_r2_accepted_by_coordinator":True,"source_hashes":source_hashes,"readonly_dependency_hashes":readonly_hashes,
                "readonly_dependencies_frozen_under_inputs":True,
                "reference_hashes":reference_hashes,"captures":captures,"other_evidence_hashes":hashes,
                "contract_checks":interface["checks"],"marker_count":len(interface["markers"]),"stats":interface["stats"],
                "wrapper_runs":len(runs),"recorded_groups":len(groups),"browser_done":False,
                "model_sha256":digest(ROOT / "aircraft/g4m1/g4m1.gd"),
                "limits":"Static pure model and MAP02 installation only; no production registration/OPS/BOMB/DM/Chrome fleet claim"}
    write(EVIDENCE / "manifest.json", manifest)
    print(json.dumps({"model_sha256":manifest["model_sha256"],"sources":len(source_hashes),"readonly_dependencies":len(readonly_hashes),
                      "reference_files":len(reference_hashes),"captures":len(captures),"wrapper_runs":len(runs),"groups":len(groups),
                      "live_groups":remaining,"shared_changes":[k for k,v in baseline_comparison.items() if not v["same"]]},ensure_ascii=False))


if __name__ == "__main__":
    main()
