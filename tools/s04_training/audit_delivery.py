#!/usr/bin/env python3
"""Read-only runtime/video/process audit; execute under the validation lock."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
from datetime import datetime, timezone

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "docs/showcase/evidence/S04-training"


def read(path):
    return json.loads(path.read_text())


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


freeze = read(OUT / "frozen-input.json")
mismatches = [name for name, expected in freeze["sources"].items()
              if digest(ROOT / name) != expected]
protected = read(ROOT / ".local/s04-training-before/manifest.json")["files"]
unchanged_names = ["docs/aircraft-contracts.md",
                   "scripts/simulation/aircraft_motion/aircraft_motion.gd",
                   "data/aircraft/performance.json",
                   "scripts/showcase/sb2c_showcase_tasks.gd"]
unchanged = {name: digest(ROOT / name) == protected[name] for name in unchanged_names}
dm = read(ROOT / "docs/showcase/evidence/DM01/source_hashes.json")
dm_production = {name: digest(ROOT / name) == expected
                 for name, expected in dm["production"].items()}
index = read(OUT / "native/index.json")
movies = []
for clip in index["clips"]:
    path = OUT / "native" / (clip["name"]+".mp4")
    result = subprocess.run([
        "/opt/homebrew/bin/ffprobe", "-v", "error", "-select_streams", "v:0",
        "-show_entries", "stream=codec_name,width,height,r_frame_rate,nb_frames",
        "-of", "json", str(path),
    ], capture_output=True, text=True, timeout=5, check=True)
    stream = json.loads(result.stdout)["streams"][0]
    good = (stream["codec_name"] == "h264" and stream["width"] == 1100
            and stream["height"] == 700 and stream["r_frame_rate"] == "15/1"
            and int(stream["nb_frames"]) == clip["frames"]
            and digest(path) == clip["sha256"])
    movies.append({"name": clip["name"], "stream": stream, "matches": good})

process_output = subprocess.run(["/bin/ps", "-e", "-o", "pid=,pgid="],
                                capture_output=True, text=True, timeout=5, check=True)
processes = [tuple(map(int, line.split())) for line in process_output.stdout.splitlines()]
live_pids = {pid for pid, _ in processes}
live_groups = {group for _, group in processes}
runs = []
for path in sorted((ROOT / ".local/validation/runs").glob("*/report.json")):
    report = read(path)
    if report.get("owner") != "S04-training":
        continue
    groups = [{"pgid": c["process_group"], "cleanup_ok": c["cleanup_ok"],
               "exists_now": c["process_group"] in live_groups}
              for c in report["checks"] if c.get("process_group")]
    runs.append({"run": report["run_id"], "passed": report["passed"],
                 "wrapper_pid": report["wrapper_pid"],
                 "wrapper_exists_now": report["wrapper_pid"] in live_pids,
                 "groups": groups})
clean = all(not r["wrapper_exists_now"] and all(
    g["cleanup_ok"] and not g["exists_now"] for g in r["groups"]) for r in runs)
cleanup = {
    "checked_utc": datetime.now(timezone.utc).isoformat(),
    "all_prior_training_groups_gone": clean, "runs": runs,
    "current_audit_pid": os.getpid(), "current_audit_wrapper_pid": os.getppid(),
    "current_audit_scope": "This bounded checker and its validation wrapper are active during this snapshot; their final cleanup is recorded by the wrapper report after exit. No rendering/browser/HTTP process is created by this audit.",
    "training_browser_or_http_started": False, "user_windows_closed": False,
}
(OUT / "cleanup.json").write_text(json.dumps(cleanup, indent=2)+"\n")
passed = (not mismatches and all(unchanged.values()) and all(dm_production.values())
          and all(m["matches"] for m in movies) and len(movies) == 10 and clean)
audit = {"passed": passed, "frozen_runtime_files": len(freeze["sources"]),
         "runtime_mismatches": mismatches, "protected_inputs_unchanged": unchanged,
         "DM01_production_unchanged": dm_production, "movies": movies,
         "owned_previous_runs": len(runs), "all_prior_groups_gone": clean}
(OUT / "delivery-audit.json").write_text(json.dumps(audit, indent=2)+"\n")
print(json.dumps({"passed": passed, "frozen_runtime_files": len(freeze["sources"]),
                  "movies": len(movies), "owned_previous_runs": len(runs),
                  "all_prior_groups_gone": clean}))
raise SystemExit(0 if passed else 1)
