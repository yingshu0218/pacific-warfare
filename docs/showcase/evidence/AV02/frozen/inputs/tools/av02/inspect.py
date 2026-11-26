#!/usr/bin/env python3
"""One bounded off-screen native AV02 inspection. Uses the repository flock."""
from __future__ import annotations

import argparse
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--view", default="high_front", choices=[
        "quarter", "side", "side_flight", "front", "top_flight", "high_front",
        "high_rear", "rear", "underside_flight", "gear", "tailgear", "canopy",
        "rear_gun", "bay", "brake", "landing", "damage", "deck_forward",
        "deck_middle", "deck_aft", "deck_parking"])
    parser.add_argument("--capture", type=Path, default=Path("/tmp/av02-inspection.png"))
    args = parser.parse_args()
    capture = args.capture.expanduser().resolve()
    capture.parent.mkdir(parents=True, exist_ok=True)
    command = ["nice", "-n", "10", sys.executable, str(ROOT / "tools/verify.py"),
               "--owner", "AV02", "--timeout", "35", "--lock-timeout", "15", "godot", "--render", "--",
               "--rendering-method", "gl_compatibility", "--audio-driver", "Dummy",
               "--resolution", "1440x900", "--position", "5000,5000", "--quit-after", "600",
               "res://aircraft/d4y2/inspection.tscn", "--", "--view", args.view, "--capture", str(capture)]
    process = subprocess.Popen(command, cwd=ROOT)
    try:
        return process.wait(timeout=58)
    except (subprocess.TimeoutExpired, KeyboardInterrupt):
        # SIGTERM invokes verify.py's own Godot process-group cleanup path.
        process.terminate()
        try:
            process.wait(timeout=8)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=3)
        return 124


if __name__ == "__main__":
    raise SystemExit(main())
