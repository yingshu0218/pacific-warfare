#!/usr/bin/env python3
"""Verify originals; --restore optionally downloads missing public photos."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
FOLDER = ROOT / "docs/references/aircraft/f6f5_1944/carrier-usage"
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--restore", action="store_true")
args = parser.parse_args()
records = json.loads((FOLDER / "sources.json").read_text())["records"]
for row in records:
    path = FOLDER / row["file"]
    if not path.exists():
        if not args.restore or "original_url" not in row:
            raise SystemExit("Missing original or derived manual page: " + str(path))
        path.parent.mkdir(parents=True, exist_ok=True)
        with tempfile.NamedTemporaryFile(dir=path.parent, prefix="s04-photo-", delete=False) as f:
            temporary = Path(f.name)
        try:
            subprocess.run(["curl", "--fail", "--location", "--max-time", "45", "--retry", "1",
                            "--user-agent", "Mozilla/5.0 (reference research)",
                            "--output", str(temporary), row["original_url"]], check=True)
            if hashlib.sha256(temporary.read_bytes()).hexdigest() != row["sha256"]:
                raise SystemExit("Downloaded original differs: " + row["file"])
            temporary.replace(path)
        finally:
            temporary.unlink(missing_ok=True)
    if hashlib.sha256(path.read_bytes()).hexdigest() != row["sha256"]:
        raise SystemExit("Original hash mismatch: " + row["file"])
print("Verified", len(records), "retained originals; no account or paid service.")
