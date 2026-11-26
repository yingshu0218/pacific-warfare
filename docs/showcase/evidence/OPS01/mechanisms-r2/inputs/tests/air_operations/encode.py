#!/usr/bin/env python3
"""Encode only an observed bounded OPS capture; invoke through tools/verify.py."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("capture", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    metadata = json.loads((args.capture / "capture.json").read_text())
    if not metadata["complete"]:
        raise ValueError("Cannot publish an incomplete capture as completed")
    frames = sorted(args.capture.glob("frame_*.png"))
    expected = [args.capture / f"frame_{n:05d}.png" for n in range(metadata["frames"])]
    if frames != expected:
        raise ValueError("Frame sequence is incomplete or contains stale frames")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run([
        "/opt/homebrew/bin/ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
        "-framerate", str(metadata["fps"]), "-i", str(args.capture / "frame_%05d.png"),
        "-c:v", "libx264", "-preset", "fast", "-crf", "21", "-pix_fmt", "yuv420p",
        "-movflags", "+faststart", str(args.output),
    ], check=True, timeout=80)
    report = {
        "source": str(args.capture), "fps": metadata["fps"],
        "frames": metadata["frames"], "segment": metadata.get("segment", "overview"),
        "recording_duration_s": metadata["frames"] / metadata["fps"],
        "input_sha256": {str(x.name): hashlib.sha256(x.read_bytes()).hexdigest() for x in frames},
        "output": str(args.output), "output_sha256": hashlib.sha256(args.output.read_bytes()).hexdigest(),
        "scope": "Native recording cadence; no interpolated frames, no Chrome performance claim",
    }
    args.output.with_suffix(".encoding.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({k: v for k, v in report.items() if k != "input_sha256"}))


if __name__ == "__main__":
    main()
