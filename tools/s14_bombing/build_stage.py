#!/usr/bin/env python3
"""Rebuild/sync only admitted S14 R8, BOMB r18 and owned combined overrides."""
from pathlib import Path
import argparse, hashlib, json, shutil
ROOT=Path(__file__).resolve().parents[2]; CAND=ROOT/'candidates/s14-bombing'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
p=argparse.ArgumentParser();p.add_argument('--stage',default='candidates/s14-bombing/stage');p.add_argument('--sync',action='store_true');a=p.parse_args()
stage=ROOT/a.stage
if not a.sync:
 assert not stage.exists()
 for name,record in json.loads((CAND/'admitted-inputs.json').read_text()).items():
  src=ROOT/record['source'];assert sha(src)==record['sha256'];dst=stage/name;dst.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(src,dst)
for src in (CAND/'overrides').rglob('*'):
 if src.is_file():
  dst=stage/src.relative_to(CAND/'overrides');dst.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(src,dst)
print(json.dumps({'stage':str(stage),'sync':a.sync,'public_runtime_unchanged':True}))
