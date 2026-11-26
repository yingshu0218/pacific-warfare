#!/usr/bin/env python3
"""Hash/freeze AV02-owned sources and collect already completed verification logs.

No Godot, browser, server, encoder, or other heavy process is launched here.
Existing failed reports are retained; this script never relabels them as passes.
"""
from __future__ import annotations

import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[2]
EVIDENCE = ROOT / "docs/showcase/evidence/AV02"


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def relative(path: Path) -> str:
    return str(path.relative_to(ROOT))


def write(path: Path, data: object) -> None:
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")


def main() -> int:
    now = dt.datetime.now(dt.timezone.utc).isoformat()
    log_root = EVIDENCE / "verification"
    log_root.mkdir(exist_ok=True)
    runs = []
    groups = []
    for report_path in sorted((ROOT / ".local/validation/runs").glob("*/report.json")):
        report = json.loads(report_path.read_text())
        if report.get("owner") != "AV02":
            continue
        destination = log_root / report["run_id"]
        destination.mkdir(exist_ok=True)
        shutil.copy2(report_path, destination / "report.json")
        for log in sorted(report_path.parent.glob("*.log")):
            shutil.copy2(log, destination / log.name)
        runs.append({"run_id": report["run_id"], "passed": report["passed"],
                     "exit_code": report["exit_code"], "action": report["action"],
                     "report": relative(destination / "report.json"),
                     "commands": [check["command"] for check in report.get("checks", [])]})
        for check in report.get("checks", []):
            pgid = check.get("process_group")
            if not pgid:
                continue
            state = "exited"
            try:
                os.killpg(int(pgid), 0)  # Read-only existence probe; never sends a signal.
                state = "exists_ownership_not_reasserted"
            except ProcessLookupError:
                pass
            except PermissionError:
                state = "permission_unknown"
            groups.append({"run_id": report["run_id"], "pgid": pgid,
                           "wrapper_cleanup_ok": check.get("cleanup_ok", False), "current_state": state})
    write(EVIDENCE / "verification-index.json", {"owner": "AV02", "generated_utc": now,
          "run_count": len(runs), "failed_run_count": sum(not row["passed"] for row in runs), "runs": runs})
    baseline = json.loads((EVIDENCE / "baseline.json").read_text())
    shared_check = {path: {"before": expected, "current": sha(ROOT / path),
                          "unchanged": sha(ROOT / path) == expected}
                    for path, expected in baseline["existing_inputs"].items()}
    cleanup = {"generated_utc": now, "owner": "AV02", "process_groups": groups,
               "all_av02_groups_exited": all(row["current_state"] == "exited" for row in groups),
               "all_wrapper_cleanup_ok": all(row["wrapper_cleanup_ok"] for row in groups),
               "shared_inputs": shared_check, "shared_inputs_unchanged": all(row["unchanged"] for row in shared_check.values()),
               "browser_http_ffmpeg": "none launched by AV02", "user_windows_touched": False}
    lock = ROOT / ".local/validation/godot-render.lock"
    if lock.exists():
        cleanup["lock_metadata_at_packaging"] = json.loads(lock.read_text())
    write(EVIDENCE / "cleanup.json", cleanup)
    sources = []
    for base in ["aircraft/d4y2", "tests/av02", "tools/av02"]:
        sources.extend(p for p in (ROOT / base).rglob("*") if p.is_file() and p.suffix in {".gd", ".tscn", ".json", ".py", ".md"})
    sources.extend([ROOT / "docs/references/aircraft/d4y2_1944/modeling-brief.md",
                    ROOT / "docs/references/aircraft/d4y2_1944/sources.json",
                    ROOT / "docs/showcase/deliveries/AV02.md"])
    dependencies = [ROOT / p for p in ["tools/verify.py", "project.godot", "docs/carrier-deck-contracts.md",
                                      "scripts/naval/destroyers/mesh_tools.gd"]]
    dependencies.extend(p for p in (ROOT / "naval/shokaku_1941_08_23").rglob("*")
                        if p.is_file() and p.suffix in {".gd", ".tscn", ".json"})
    frozen = EVIDENCE / "frozen"
    frozen.mkdir(exist_ok=True)
    (frozen / ".gdignore").touch()
    source_hashes = {}
    for source in sorted(set(sources + dependencies)):
        target = frozen / "inputs" / source.relative_to(ROOT)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)
        source_hashes[relative(source)] = {"sha256": sha(source), "snapshot": relative(target), "bytes": source.stat().st_size}
    references = {relative(p): sha(p) for p in (ROOT / "docs/references/aircraft/d4y2_1944").rglob("*")
                  if p.is_file() and p.suffix not in {".import"} and ".godot" not in p.parts}
    for p in [ROOT / "docs/references/ships/shokaku_1941_08_23/original/P02.pdf",
              ROOT / "docs/references/bombers/sb2c/target/sb2c4-outer-form-candidate-v04.png"]:
        references[relative(p)] = sha(p)
    evidence = {relative(p): sha(p) for p in EVIDENCE.rglob("*") if p.is_file()
                and frozen not in p.parents and p.name != "manifest.json" and p.suffix != ".import"}
    write(EVIDENCE / "manifest.json", {"owner": "AV02", "generated_utc": now, "source_files": source_hashes,
          "reference_files": references, "evidence_files": evidence, "final_image_directory": "docs/showcase/evidence/AV02/final",
          "historical_images": "native-r1/r2/r3/r4 and deck-r2 sidecars keep their original source hashes; final has four superseding clean-skin views",
          "status": "See docs/showcase/deliveries/AV02.md for current root acceptance; do not rewrite historical reports"})
    good = cleanup["all_av02_groups_exited"] and cleanup["all_wrapper_cleanup_ok"] and cleanup["shared_inputs_unchanged"]
    print(json.dumps({"passed": good, "sources": len(source_hashes), "references": len(references),
                      "evidence": len(evidence), "runs": len(runs), "groups": len(groups), "manifest": relative(EVIDENCE / "manifest.json")}))
    return 0 if good else 1


if __name__ == "__main__":
    raise SystemExit(main())
