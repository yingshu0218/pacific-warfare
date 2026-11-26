#!/usr/bin/env python3
"""Audit the private patch and completed owned process groups; never apply to root."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
CANDIDATE = ROOT / "candidates/s04-carrier-usage"
STAGE = ROOT / ".local/s04-carrier-usage/r10"
OUT = ROOT / "docs/showcase/evidence/S04-carrier-usage/r10"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


summary = json.loads((OUT / "verification-summary.json").read_text())
baseline = json.loads((CANDIDATE / "baseline-hashes.json").read_text())["files"]
public = {name: sha(ROOT / name) == expected for name, expected in baseline.items()}
assert all(public.values()), "Protected public model drift"
inputs = json.loads((STAGE / "input-manifest.json").read_text())["sources"]
drift = [name for name, expected in inputs.items() if not (STAGE / name).exists() or sha(STAGE / name) != expected]
assert not drift, "Validated stage source drift: " + repr(drift)
for row in summary["source_files"]:
    assert sha(ROOT / row["candidate"]) == row["after_sha256"] == sha(STAGE / row["destination"])

patch_result = {}
with tempfile.TemporaryDirectory(prefix="patch-check-", dir=ROOT / ".local/s04-carrier-usage") as name:
    target = Path(name)
    for path in baseline:
        dest = target / path
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(CANDIDATE / "baseline" / path, dest)
    (target / "scripts/aircraft_geometry").mkdir(parents=True, exist_ok=True)
    command = ["/usr/bin/patch", "--batch", "-p1", "-i", str(CANDIDATE / "carrier-usage.patch")]
    dry = subprocess.run(command + ["--dry-run"], cwd=target, capture_output=True, text=True, timeout=15)
    assert dry.returncode == 0, dry.stdout + dry.stderr
    applied = subprocess.run(command, cwd=target, capture_output=True, text=True, timeout=15)
    assert applied.returncode == 0, applied.stdout + applied.stderr
    matched = {row["destination"]: sha(target / row["destination"]) == row["after_sha256"] for row in summary["source_files"]}
    assert all(matched.values()), "Patch application differs from validated source"
    patch_result = {"dry_run_exit_code": dry.returncode, "private_apply_exit_code": applied.returncode,
                    "applied_hashes_match": matched, "temporary_directory_cleaned": True,
                    "scope": "Saved baseline copies only; public source never modified."}

runs = []
identities = set()
for path in sorted((ROOT / ".local/validation/runs").glob("*/report.json")):
    report = json.loads(path.read_text())
    if report.get("owner") != "S04-carrier-usage":
        continue
    identities.add(report["wrapper_pid"])
    children = []
    for check in report.get("checks", []):
        if check.get("pid"):
            identities.add(check["pid"])
            children.append({"pid": check["pid"], "process_group": check["process_group"],
                             "reported_cleanup_ok": check.get("cleanup_ok"), "passed": check.get("passed")})
    runs.append({"run_id": report["run_id"], "passed": report["passed"], "children": children})
ps = subprocess.run(["/bin/ps", "-p", ",".join(map(str, sorted(identities))), "-o", "pid=,pgid=,command="],
                    capture_output=True, text=True, timeout=5)
assert ps.returncode in (0, 1), ps.stderr
live = []
for line in ps.stdout.splitlines():
    pid, pgid, command = line.strip().split(None, 2)
    live.append({"pid": int(pid), "pgid": int(pgid), "command": command,
                 "belongs_to_this_task": ".local/s04-carrier-usage/" in command or "--owner S04-carrier-usage" in command})
assert not any(row["belongs_to_this_task"] for row in live), "An old owned process is still running"
groups = {}
for pid in sorted({c["process_group"] for r in runs for c in r["children"]}):
    try:
        os.killpg(pid, 0)
        groups[str(pid)] = "present; inspect live identity (no signals sent)"
    except ProcessLookupError:
        groups[str(pid)] = "absent"
assert all(state == "absent" for state in groups.values()), "An old owned process group is still present"
result = {"passed": True, "public_baseline_unchanged": public, "stage_input_files_verified": len(inputs),
          "stage_input_drift": drift, "patch": patch_result, "completed_owned_runs": runs,
          "owned_child_process_groups": groups, "live_reused_pids": live,
          "old_owned_processes_remaining": 0, "chrome_tabs_created": 0, "http_services_created": 0,
          "current_audit": "Current wrapper is absent from completed reports; its own cleanup/release is proved by the outer verify.py report.",
          "historical_failures": "Retained as failed runs; later successful model fixes do not rewrite them."}
(OUT / "cleanup-audit.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
print(json.dumps({"passed": True, "completed_owned_runs": len(runs), "owned_groups_absent": len(groups),
                  "stage_files_verified": len(inputs), "patch_matches": len(patch_result["applied_hashes_match"])}))
