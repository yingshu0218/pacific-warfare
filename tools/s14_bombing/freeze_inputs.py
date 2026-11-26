#!/usr/bin/env python3
from pathlib import Path
import argparse,datetime,hashlib,json,shutil
ROOT=Path(__file__).resolve().parents[2];CAND=ROOT/'candidates/s14-bombing'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
p=argparse.ArgumentParser();p.add_argument('--name',required=True);a=p.parse_args()
stage=CAND/'stage';out=CAND/'evidence/inputs'/a.name;assert not out.exists()
assert all(sha(ROOT/k)==v for k,v in json.loads((CAND/'baseline-hashes.json').read_text()).items())
names=set(json.loads((CAND/'admitted-inputs.json').read_text()))
names.update(str(p.relative_to(CAND/'overrides'))for p in (CAND/'overrides').rglob('*')if p.is_file())
files={k:sha(stage/k)for k in sorted(names)}
for name in files:
 dst=out/name;dst.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(stage/name,dst)
d={'created_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'stage':str(stage),'frozen_inputs':str(out),'engine':'4.7.2.stable.official.ed1daf0bf','renderer':'Compatibility','files':files,'dependencies':json.loads((CAND/'dependencies.json').read_text()),'root_runtime_unchanged':True,'ordinary_build_untouched':True}
value=json.dumps(d,ensure_ascii=False,indent=2)+'\n';(CAND/'evidence'/('inputs-'+a.name+'.json')).write_text(value);(stage/'source-manifest.json').write_text(value)
print(json.dumps({'inputs':len(files),'manifest_sha256':hashlib.sha256(value.encode()).hexdigest()}))
