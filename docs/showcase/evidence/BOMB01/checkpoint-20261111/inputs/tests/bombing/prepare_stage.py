#!/usr/bin/env python3
"""Build from immutable explicit baseline, own files and named replacements only."""
from pathlib import Path
import argparse, hashlib, json, shutil
ROOT=Path(__file__).resolve().parents[2]
C=ROOT/'candidates/bomb01'
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
a=argparse.ArgumentParser();a.add_argument('name');args=a.parse_args()
stage=ROOT/'.local/bomb01'/args.name
if stage.exists(): raise SystemExit('Use a new stage name')
baseline=json.loads((C/'baseline-manifest.json').read_text())['inputs']
for name,h in baseline.items():
 src=C/'baseline'/name
 if sha(src)!=h: raise SystemExit('Frozen baseline drift: '+name)
 dest=stage/name;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(src,dest)
for name,h in json.loads((C/'ops-inputs.json').read_text())['inputs'].items():
 src=C/'ops_frozen'/name
 if sha(src)!=h: raise SystemExit('Frozen OPS drift: '+name)
 dest=stage/name;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(src,dest)
replacements=[]
for name in json.loads((C/'destinations.json').read_text()):
 src=C/'overrides'/name;dest=stage/name
 dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(src,dest)
 replacements.append({'destination':name,'candidate':str(src.relative_to(ROOT)),'before_sha256':baseline[name],'after_sha256':sha(src)})
for folder in ['scripts/bombing','tests/bombing']:
 for src in sorted((ROOT/folder).rglob('*')):
  if src.suffix not in ['.gd','.tscn','.py']: continue
  dest=stage/src.relative_to(ROOT);dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(src,dest)
for src in (C/'private_data').glob('*.json'):
 dest=stage/'tests/bombing/data'/src.name;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(src,dest)
# AircraftPerformance existing loader stays unchanged; private stage override only.
shutil.copy2(C/'private_data/performance.json',stage/'data/aircraft/performance.json')
(stage/'project.godot').write_text((stage/'project.godot').read_text().replace('run/main_scene=', ';bomb01_ordinary_main_disabled='))
# Only named model sources are admitted, so ancestor ignores are unnecessary here.
for src in stage.rglob('.gdignore'): src.unlink()
out=ROOT/'docs/showcase/evidence/BOMB01'/args.name;out.mkdir(parents=True,exist_ok=True);(out/'.gdignore').touch()
record={'stage':str(stage),'baseline_manifest_sha256':sha(C/'baseline-manifest.json'),'replacements':replacements,'inputs':{str(p.relative_to(stage)):sha(p) for p in sorted(stage.rglob('*')) if p.is_file()},'private_data_registration':'Only tests/bombing/data; performance explicitly applied inside this private stage; no ordinary loader changes'}
(out/'input-manifest.json').write_text(json.dumps(record,indent=2)+'\n')
print(json.dumps({'stage':str(stage),'input_count':len(record['inputs'])}))
