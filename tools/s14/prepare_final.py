#!/usr/bin/env python3
"""Freeze the admitted 19-unit S14 baseline; exclude ongoing CV01 and research."""
import argparse,datetime,hashlib,json,shutil
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 parser=argparse.ArgumentParser();parser.add_argument('--stage',default='.local/s14-final-runtime');parser.add_argument('--refresh',action='store_true');args=parser.parse_args()
 stage=(ROOT/args.stage).resolve();assert stage.is_relative_to(ROOT/'.local')
 if stage.exists():
  assert args.refresh,'Use fresh destination or explicit refresh'
  shutil.rmtree(stage)
 ext={'.gd','.gdshader','.tscn','.tres','.json','.otf','.uid','.png','.import','.svg'}
 def ignore(directory,names):
  return [n for n in names if (Path(directory,n).is_dir() and n in {'.godot','screenshots','evidence','backups','reference','references','docs','au01','sb2c4-archive','validation','inspection'}) or (Path(directory,n).is_file() and Path(n).suffix not in ext and n!='LICENSE.txt')]
 for name in ['scripts','scenes','data','assets','aircraft','ui','showcase']:
  shutil.copytree(ROOT/name,stage/name,ignore=ignore)
 # Old viewers reference a separate airfield project. They are not runtime entries
 # for this isolated baseline. Root originals remain untouched.
 for name in ['showcase.gd','showcase.gd.uid','showcase.tscn']:
  (stage/'showcase'/name).unlink(missing_ok=True)
 for p in (stage/'data/units').glob('*.json'):
  if p.stem not in {'us_sb2c4_1944','us_f6f5_1944','jp_a6m5a_1944','jp_yamato_1944_04','us_iowa_bb61_1944_12_28','us_fletcher_dd445_1942_07_18','jp_yukikaze_1942_06','us_5in51_mk13mod4_1945','us_40mm_m1_m2a1_1944'}:p.unlink()
 for name in ['project.godot','export_presets.cfg']:shutil.copyfile(ROOT/name,stage/name)
 project=(stage/'project.godot').read_text().replace('run/main_scene="res://scenes/main.tscn"','run/main_scene="res://showcase/all_units.tscn"')
 project=project.replace('config/name="Yamato · 1944 study"','config/name="S14 全单位 Showcase"').replace('viewport_width=1440','viewport_width=1280').replace('viewport_height=900','viewport_height=720')
 (stage/'project.godot').write_text(project)
 for name in ['tests/s14_integration.gd','tests/s14_final_capture.gd','tests/s14_web_probe.gd','tests/scenes/s14_web.tscn']:
  p=ROOT/name
  if p.exists():t=stage/name;t.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p,t)
 (stage/'docs/showcase/evidence/S14/final').mkdir(parents=True,exist_ok=True)
 files={str(p.relative_to(stage)):sha(p) for p in stage.rglob('*') if p.is_file()}
 assert not any('essex' in k.lower() or k.startswith('naval/') or '/references/' in k for k in files)
 manifest={'created_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'engine':'4.7.2.stable.official.ed1daf0bf','stage':str(stage),'baseline_units':19,'model_types':9,'excluded':['naval/essex_cv9_1944_04_15','research/reference images','future unit definitions','AU01 candidate audio','legacy standalone airfield viewer'],'sources':files}
 (stage/'freeze_manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
 out=ROOT/'docs/showcase/evidence/S14/final';out.mkdir(parents=True,exist_ok=True);(out/'frozen-input.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
 print(json.dumps({'stage':str(stage),'files':len(files),'excluded_cv01':True}))
if __name__=='__main__':main()
