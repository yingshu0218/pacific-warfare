#!/usr/bin/env python3
"""Freeze only explicit admitted/owned candidate paths, with protected baselines."""
from pathlib import Path
import argparse,datetime,hashlib,json,shutil
ROOT=Path(__file__).resolve().parents[2];CAND=ROOT/'candidates/s14-expansion'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
parser=argparse.ArgumentParser();parser.add_argument('--name',required=True);parser.add_argument('--stage',default='candidates/s14-expansion/stage');a=parser.parse_args()
stage=ROOT/a.stage;out=CAND/'evidence/inputs'/a.name
assert not out.exists(),'Immutable input name already exists'
base=json.loads((CAND/'baseline-hashes.json').read_text())
assert all(sha(ROOT/k)==v for k,v in base.items()),'Protected root runtime drift'
names=set(json.loads((CAND/'admitted-inputs.json').read_text()))
names.update(str(p.relative_to(CAND/'overrides')) for p in (CAND/'overrides').rglob('*') if p.is_file())
files={k:sha(stage/k) for k in sorted(names)}
assert not any(k.startswith(('candidates/','docs/','assets/audio/au01')) for k in files)
for k in files:
 dst=out/k;dst.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(stage/k,dst)
manifest={'created_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'stage':str(stage),'frozen_inputs':str(out),'engine':'4.7.2.stable.official.ed1daf0bf','renderer':'Compatibility','files':files,'dependencies':json.loads((CAND/'dependencies.json').read_text()),'root_baseline_sha256':sha(CAND/'baseline-hashes.json'),'root_runtime_unchanged':True,'ordinary_build_untouched':True}
(CAND/'evidence').mkdir(exist_ok=True)
text=json.dumps(manifest,ensure_ascii=False,indent=2)+'\n'
(CAND/'evidence'/f'inputs-{a.name}.json').write_text(text)
(stage/'source-manifest.json').write_text(text)
print(json.dumps({'files':len(files),'frozen':str(out),'manifest_sha256':hashlib.sha256(text.encode()).hexdigest()}))
