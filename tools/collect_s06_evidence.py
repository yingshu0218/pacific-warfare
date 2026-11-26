#!/usr/bin/env python3
"""Collect S06's bounded verification logs and read-only process-group audit."""
from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/showcase/evidence/S06"
SOURCE_DIRS = ["scripts/simulation/ship_motion", "scripts/behaviors/fleet_formations", "scripts/command/commander", "data/fleet"]
SOURCE_FILES = ["docs/fleet-contracts.md", "docs/references/fleet/s06-sources.md", "docs/showcase/deliveries/S06.md",
                "tests/fixtures/fleet_fixture.gd", "tests/fixtures/fleet_test.gd", "tests/test_ship_motion.gd",
                "tests/test_fleet_formation.gd", "tests/test_commander.gd", "tests/test_fleet_replay.gd", "tests/test_fleet_combat.gd", "tests/test_fleet_mobility_blocked.gd",
                "tools/collect_s06_evidence.py", "tools/plot_s06_evidence.py", "docs/deliveries/T18.md", "docs/deliveries/T19.md", "docs/deliveries/T20.md"]


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    runs = []
    groups = []
    for source in sorted((ROOT / ".local/validation/runs").glob("*/report.json")):
        report = json.loads(source.read_text())
        if report.get("owner") != "S06":
            continue
        destination = OUT / "verification" / source.parent.name
        destination.mkdir(parents=True, exist_ok=True)
        for item in source.parent.iterdir():
            if item.suffix in {".json", ".log"}:
                shutil.copyfile(item, destination / item.name)
        runs.append({"id": source.parent.name, "passed": report["passed"], "exit_code": report["exit_code"],
                     "report": str((destination / "report.json").relative_to(ROOT)), "error": report.get("error", ""),
                     "diagnostic_error": any(c.get("diagnostic_error") for c in report["checks"])})
        for check in report["checks"]:
            pgid = check.get("process_group")
            if not pgid:
                continue
            try:
                os.killpg(pgid, 0)  # observation only; never signal an unrelated group
                exists = True
            except ProcessLookupError:
                exists = False
            except PermissionError:
                exists = None
            groups.append({"run": source.parent.name, "pgid": pgid,
                           "wrapper_cleanup_ok": check["cleanup_ok"], "exists_now": exists})
    files = {ROOT / name for name in SOURCE_FILES}
    files.update(path.with_suffix(path.suffix + ".uid") for path in tuple(files) if path.suffix == ".gd")
    for directory in SOURCE_DIRS:
        files.update(path for path in (ROOT / directory).rglob("*") if path.is_file())
    sources = [{"path": str(path.relative_to(ROOT)), "sha256": hashlib.sha256(path.read_bytes()).hexdigest(), "bytes": path.stat().st_size}
               for path in sorted(files) if path.is_file()]
    (OUT / "validation_runs.json").write_text(json.dumps(runs, ensure_ascii=False, indent=2) + "\n")
    (OUT / "files.json").write_text(json.dumps(sources, ensure_ascii=False, indent=2) + "\n")
    cleanup = {"groups": groups, "all_wrapper_cleanup_ok": all(item["wrapper_cleanup_ok"] for item in groups),
               "all_groups_absent": all(item["exists_now"] is False for item in groups),
               "browser_tabs_created": 0, "native_windows_created": 0, "http_services_created": 0,
               "notes": "All engine invocations were bounded headless/import through tools/verify.py. No user windows or foreign processes were closed."}
    (OUT / "cleanup.json").write_text(json.dumps(cleanup, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps({"runs": len(runs), "source_files": len(sources), "process_groups": len(groups),
                      "all_wrapper_cleanup_ok": cleanup["all_wrapper_cleanup_ok"], "all_groups_absent": cleanup["all_groups_absent"]}))


if __name__ == "__main__":
    main()
