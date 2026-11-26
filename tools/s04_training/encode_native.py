#!/usr/bin/env python3
"""Package genuine training captures. Run under tools/verify.py exec."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser()
parser.add_argument("--source", default=".local/s04-training-final-frames")
args = parser.parse_args()
source = ROOT / args.source
out = ROOT / "docs/showcase/evidence/S04-training/native"
out.mkdir(parents=True, exist_ok=True)
records = []
for folder in sorted(source.iterdir()):
    capture = folder / "capture.json"
    if not capture.exists():
        continue
    data = json.loads(capture.read_text())
    if data["final"]["status"] != "completed":
        raise RuntimeError(f"Incomplete actual training: {folder.name}")
    movie = out / f"{folder.name}.mp4"
    command = [
        "/opt/homebrew/bin/ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
        "-framerate", str(data["fps"]), "-i", str(folder / "frame_%04d.png"),
        "-c:v", "libx264", "-preset", "fast", "-crf", "21", "-pix_fmt",
        "yuv420p", "-movflags", "+faststart", str(movie),
    ]
    result = subprocess.run(command, capture_output=True, text=True, timeout=45)
    if result.returncode:
        raise RuntimeError(result.stderr)
    shutil.copyfile(capture, out / f"{folder.name}.json")
    samples = data["samples"]
    phase_samples = {}
    for sample in samples:
        phase = sample["unit"]["module_data"]["aircraft_training"]["phase"]
        phase_samples.setdefault(phase, []).append(sample)
    marks = {phase: values[0] if phase == "completed" else values[len(values)//2]
             for phase, values in phase_samples.items()}
    if data["maneuver"] in ("axial_roll", "split_s"):
        marks["inverted"] = min(samples, key=lambda s: abs(
            abs(s["unit"]["module_data"]["aircraft_training"]["roll_accum_rad"])-math.pi))
    if data["maneuver"] == "axial_roll":
        marks["full-roll"] = next(s for s in samples if abs(
            s["unit"]["module_data"]["aircraft_training"]["roll_accum_rad"]) >= math.tau)
    keyframes = []
    for label, sample in marks.items():
        frame = min(data["frames"]-1, max(0, round(sample["time_s"]*data["fps"])-1))
        name = f"{folder.name}-{label}.png"
        shutil.copyfile(folder / f"frame_{frame:04d}.png", out / name)
        keyframes.append({"label": label, "frame": frame, "time_s": sample["time_s"], "file": name})
    counts = {}
    for event in data["events"]:
        counts[event["kind"]] = counts.get(event["kind"], 0)+1
    terminal = phase_samples["completed"][0]
    actual = terminal["unit"]["module_data"]["aircraft_training"]
    records.append({
        "name": folder.name, "definition_id": data["definition_id"],
        "maneuver": data["maneuver"], "direction": data["direction"],
        "fps": data["fps"], "frames": data["frames"],
        "seconds": data["frames"]/data["fps"], "resolution": data["resolution"],
        "command": command, "event_counts": counts,
        "final_order_status": data["final"]["status"],
        "completed_time_s": data["final"]["changed_tick"]/60.0,
        "actual_training_at_completion": actual, "keyframes": keyframes,
        "bytes": movie.stat().st_size, "sha256": hashlib.sha256(movie.read_bytes()).hexdigest(),
    })
if len(records) != 10:
    raise RuntimeError(f"Expected two fighters × five maneuvers, found {len(records)}")
(out / "index.json").write_text(json.dumps({
    "scope": "Ten genuine BattleOrder native training sequences using production AircraftMotion. 15fps recording cadence is not a performance benchmark. Camera follows position with fixed world up; aircraft transforms are simulation output.",
    "clips": records,
}, ensure_ascii=False, indent=2)+"\n")
print(f"Encoded {len(records)} training clips, {sum(r['frames'] for r in records)} frames.")
