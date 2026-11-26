#!/usr/bin/env python3
"""Explicit admitted input assembly; never mutates the delivered S08 runtime."""
from pathlib import Path
import argparse, hashlib, json, shutil
ROOT = Path(__file__).resolve().parents[2]
CAND = ROOT / 'candidates/s14-expansion'
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p): return json.loads(p.read_text())
def main():
 p=argparse.ArgumentParser();p.add_argument('--stage',default='candidates/s14-expansion/stage');p.add_argument('--sync',action='store_true');p.add_argument('--admit-av04',action='store_true');a=p.parse_args()
 stage=ROOT/a.stage; assert stage.is_relative_to(CAND) or stage.is_relative_to(ROOT/'.local')
 CAND.mkdir(parents=True,exist_ok=True);(CAND/'.gdignore').touch()
 if a.admit_av04:
  manifest=ROOT/'docs/showcase/evidence/AV04/manifest.json'
  assert sha(manifest)=='d14d6bb2842d753d5f16e656ccf494090b8f424c4370fc81262e3e1073ddb660'
  admitted=read(CAND/'admitted-inputs.json');deps=read(CAND/'dependencies.json')
  for name,h in read(manifest)['source_hashes'].items():
   if not name.startswith('aircraft/b25j/') or '/inspection' in name or name.endswith('.md') or name.endswith(('proposal.json','readonly_dependencies.json')):continue
   assert sha(ROOT/name)==h
   dst=stage/name;dst.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(ROOT/name,dst)
   admitted[name]={'origin':'AV04 accepted final','source':name,'sha256':h}
  deps['AV04']={'manifest':str(manifest.relative_to(ROOT)),'sha256':sha(manifest)}
  (CAND/'admitted-inputs.json').write_text(json.dumps(admitted,indent=2)+'\n');(CAND/'dependencies.json').write_text(json.dumps(deps,indent=2)+'\n')
  print(json.dumps({'AV04_runtime_admitted':True,'root_runtime_unchanged':True}));return
 if a.sync:
  assert stage.exists()
  for src in (CAND/'overrides').rglob('*'):
   if src.is_file():dst=stage/src.relative_to(CAND/'overrides');dst.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(src,dst)
  return
 assert not stage.exists(),'Use a fresh stage or --sync only for owned overrides'
 runtime=read(ROOT/'tools/showcase_runtime.json');inputs={k:('S08 admitted whitelist',ROOT/k,sha(ROOT/k)) for k in runtime['files']}
 for k in ['project.godot','export_presets.cfg']:inputs[k]=('S08 settings',ROOT/k,sha(ROOT/k))
 dependencies={}
 def add_manifest(label,rel,expected,field,select):
  path=ROOT/rel
  if expected:assert sha(path)==expected,(label,'manifest drift')
  d=read(path);dependencies[label]={'manifest':rel,'sha256':sha(path)}
  for name,value in d[field].items():
   if not select(name):continue
   h=value['sha256'] if isinstance(value,dict) else value
   src=ROOT/name;assert sha(src)==h,(label,name,'source drift')
   inputs[name]=(label,src,h)
 add_manifest('CV01','docs/showcase/evidence/CV01/manifest.json',None,'runtime_source_sha256',lambda k:k.startswith('naval/') and '/inspection/'not in k)
 add_manifest('CV02','docs/showcase/evidence/CV02/delivery_manifest.json',None,'source_sha256',lambda k:k.startswith('naval/shokaku_') and '/inspection/'not in k and not k.endswith('.md'))
 mp=ROOT/'docs/showcase/evidence/MAP02/source_hashes.json';dependencies['MAP02']={'manifest':str(mp.relative_to(ROOT)),'sha256':sha(mp)}
 for k,h in read(mp).items():
  if k.startswith(('data/maps/','data/map02/')) or k in ['scripts/map02/expanded_map_data.gd','scripts/map02/expanded_map_view.gd']:
   assert sha(ROOT/k)==h;inputs[k]=('MAP02',ROOT/k,h)
 add_manifest('AV02','docs/showcase/evidence/AV02/manifest.json','51065720996d2897cdce35bc6bed5d060c065d41553902365c03b90df9ec34d2','source_files',lambda k:k.startswith('aircraft/d4y2/') and '/inspection'not in k and not k.endswith('.md'))
 add_manifest('AV03','docs/showcase/evidence/AV03/manifest.json','45713779a008c115999964bc936bdea4101401a330929a64ef5cb7206ff5543c','source_hashes',lambda k:k.startswith('aircraft/g4m1/') and '/inspection'not in k and not k.endswith('.md'))
 if (ROOT/'docs/showcase/evidence/AV04/manifest.json').exists():
  add_manifest('AV04','docs/showcase/evidence/AV04/manifest.json','d14d6bb2842d753d5f16e656ccf494090b8f424c4370fc81262e3e1073ddb660','source_hashes',lambda k:k.startswith('aircraft/b25j/') and '/inspection'not in k and not k.endswith(('.md','proposal.json','readonly_dependencies.json')))
 ops=ROOT/'docs/showcase/evidence/OPS01/model-resume/r11'
 assert sha(ops/'input-manifest.json')=='5adf29bb535e63e9d4f5698bb7a7a0ee9ad7ebb886478dda2171f4d581052607'
 assert sha(ops/'audit.json')=='27e4b89cd1b7a0e2ae40e2f98b94b93521a08dc9d71d5a786a4810c81b4dde84'
 dependencies['OPS01']={'manifest':str((ops/'input-manifest.json').relative_to(ROOT)),'sha256':sha(ops/'input-manifest.json')}
 for k,h in read(ops/'input-manifest.json')['inputs'].items():
  if k.startswith('scripts/air_operations/'):
   src=ops/'inputs'/k;assert sha(src)==h;inputs[k]=('OPS01 r11 frozen',src,h)
 s04=ROOT/'candidates/s04-carrier-usage/candidate-manifest.json';assert sha(s04)=='379681d3aa81909d08a1e7c28a323ca7bac03054a390e2efb83d558ec8c9a3f3'
 dependencies['S04 r10']={'manifest':str(s04.relative_to(ROOT)),'sha256':sha(s04)}
 for row in read(s04)['destinations']:
  src=ROOT/row['candidate'];assert sha(src)==row['after_sha256'];inputs[row['destination']]=('S04 r10 frozen',src,row['after_sha256'])
 for k,(origin,src,h) in sorted(inputs.items()):
  dst=stage/k;dst.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(src,dst)
 # Explicit resource roots only; research/tests/candidates never scanned into PCK.
 assert not any(k.startswith(('candidates/','docs/','tests/','assets/audio/au01/')) for k in inputs)
 baseline={k:sha(ROOT/k) for k in runtime['files']+['project.godot','export_presets.cfg','tools/showcase_runtime.json']}
 (CAND/'baseline-hashes.json').write_text(json.dumps(baseline,indent=2)+'\n')
 (CAND/'dependencies.json').write_text(json.dumps(dependencies,indent=2)+'\n')
 (CAND/'admitted-inputs.json').write_text(json.dumps({k:{'origin':o,'source':str(s.relative_to(ROOT)),'sha256':h} for k,(o,s,h) in inputs.items()},indent=2)+'\n')
 (stage/'project.godot').write_text((stage/'project.godot').read_text().replace('run/main_scene="res://scenes/main.tscn"','run/main_scene="res://showcase/carrier_harbor.tscn"').replace('viewport_width=1440','viewport_width=1280').replace('viewport_height=900','viewport_height=720'))
 for src in (CAND/'overrides').rglob('*'):
  if src.is_file():dst=stage/src.relative_to(CAND/'overrides');dst.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(src,dst)
 print(json.dumps({'stage':str(stage),'admitted_inputs':len(inputs),'dependencies':list(dependencies),'public_runtime_untouched':True}))
if __name__=='__main__':main()
