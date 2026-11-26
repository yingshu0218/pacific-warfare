#!/usr/bin/env python3
"""Freeze owned S14 inputs and index actual reports/evidence without rerunning simulations."""
import datetime, hashlib, json, os, shutil, subprocess
from collections import Counter
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'docs/showcase/evidence/S14'
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def put(name,obj):(OUT/name).write_text(json.dumps(obj,ensure_ascii=False,indent=2)+'\n')
owned=list((ROOT/'scripts/showcase').glob('*.gd'))+[ROOT/p for p in ['scripts/game/first_playable_session.gd','data/aircraft/performance.json','ui/observer_text.gd','showcase/all_units.tscn','scenes/units/aircraft/sb2c4_flight.tscn','data/units/us_sb2c4_1944.json','data/combat/s14_sb2c.json']]+list((ROOT/'data/scenarios').glob('s14_*.json'))
helpers=list((ROOT/'tools/s14').glob('*.py'))+[ROOT/p for p in ['tests/all_units_capture.gd','tests/all_units_gallery_probe.gd','tests/test_all_units_showcase.gd']]
archive=ROOT/'.local/s14-phase-owned'
for p in owned+helpers:
 target=archive/p.relative_to(ROOT);target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p,target)
put('source_hashes.json',{'production':{str(p.relative_to(ROOT)):digest(p) for p in owned},'tools':{str(p.relative_to(ROOT)):digest(p) for p in helpers}})
runs=[];groups=[]
for p in (ROOT/'.local/validation/runs').glob('*/report.json'):
 r=json.loads(p.read_text())
 if not r.get('owner','').startswith('S14'):continue
 run_dir=OUT/'validation'/r['run_id'];run_dir.mkdir(parents=True,exist_ok=True)
 shutil.copy2(p,run_dir/'report.json')
 for c in r.get('checks',[]):
  log=Path(c['output'])
  if log.exists():shutil.copy2(log,run_dir/log.name)
  pg=c.get('process_group')
  if pg:
   try:os.killpg(pg,0);status='present'
   except ProcessLookupError:status='absent'
   except PermissionError:status='permission_denied'
   groups.append({'pgid':pg,'owner':r['owner'],'status':status,'wrapper_cleanup_ok':c.get('cleanup_ok')})
 runs.append({'owner':r['owner'],'run_id':r['run_id'],'passed':r['passed'],'report':str((run_dir/'report.json').relative_to(ROOT)),'error':r.get('error','')})
runs.sort(key=lambda r:r['run_id']);put('validation_runs.json',runs)
put('cleanup.json',{'created_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'groups':groups,'all_absent':all(x['status']=='absent' for x in groups),'all_wrapper_clean':all(x['wrapper_cleanup_ok'] for x in groups),'chrome_started':False,'http_started':False,'user_windows_closed':False})
air=json.loads((OUT/'native/air_capture.json').read_text())
metrics={}
for mode in ['pair','four','maneuver','escort']:
 rows=[r for r in air['frames'] if r['mode']==mode];phases=Counter();bank=0;pitch=0;minspeed=1e9
 for r in rows:
  for id,u in r['units'].items():
   if not u['active']:continue
   f=u['flight'];minspeed=min(minspeed,f['speed_mps']);bank=max(bank,abs(f['bank_rad']));pitch=max(pitch,abs(f['path_pitch_rad']))
   phases[id+':'+u['task'].get('aircraft',{}).get('maneuver_phase','')]+=1
 metrics[mode]={'frames':len(rows),'duration_s':24,'min_active_speed_mps':minspeed,'max_active_bank_deg':bank*180/3.141592653589793,'max_active_path_pitch_deg':pitch*180/3.141592653589793,'sampled_phases':dict(phases),'guide_group_sizes':dict(Counter(len(r['guide'].get('ids',[])) for r in rows))}
put('air_phase_metrics.json',metrics)
# Keep each capture's original, immutable input hashes; explicitly list the later local gallery fix.
mismatch={}
for key,sha in air['sources_before'].items():
 p=ROOT/key.removeprefix('res://')
 if not p.exists() or digest(p)!=sha:mismatch[key]={'captured':sha,'current':digest(p) if p.exists() else None}
put('capture_provenance.json',{'air_inputs_unchanged_during_capture':air['unchanged_inputs'],'air_input_files':len(air['sources_before']),'current_differences':mismatch,'expected_difference':'Only gallery plinth +8cm after isolated coplanar-face correction; no simulation/aircraft/camera change. Original gallery source in .local/s14-air-input.','capture_harness':digest(ROOT/'tests/all_units_capture.gd')})
try:
 from PIL import Image, ImageDraw
 for mode in metrics:
  sheet=Image.new('RGB',(1280,408),(17,30,36));draw=ImageDraw.Draw(sheet)
  for n,index in enumerate([0,30,60,90,120,150,180,239]):
   image=Image.open(OUT/'native'/mode/f'frame_{index:04}.png').convert('RGB');image.thumbnail((320,180))
   x=(n%4)*320;y=(n//4)*204;sheet.paste(image,(x,y));draw.text((x+6,y+183),f'{mode}  {index/10+0.1:.1f}s',fill='white')
  sheet.save(OUT/(mode+'_contact.png'))
except ImportError:pass
files={str(p.relative_to(OUT)):digest(p) for p in OUT.rglob('*') if p.is_file() and p.name not in ['evidence_hashes.json','phase_freeze.json'] and p.suffix!='.import'}
put('evidence_hashes.json',files)
put('phase_freeze.json',{'status':'phase_frozen_waiting_s04_and_sb2c_admission_not_final_acceptance','created_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'engine':'4.7.2.stable.official.ed1daf0bf','renderer':'Compatibility','entry':'res://showcase/all_units.tscn','simulation_units':19,'types':9,'gallery_entries':5,'production_files':len(owned),'source_manifest_sha256':digest(OUT/'source_hashes.json'),'evidence_manifest_sha256':digest(OUT/'evidence_hashes.json'),'owned_recovery':str(archive),'air_capture_frames':len(air['frames']),'air_inputs_stable':air['unchanged_inputs'],'post_air_production_differences':list(mismatch),'chrome_started':False,'http_started':False,'subagents_started':False,'pending':['Original S04 training BattleOrder registration + real 360 roll and two fighter variants','Original SB2C model admission/current-code recheck','S14 integrate final training commands and repeatable full four/escort/damage demonstration','One bounded Chrome basic load/selection after dependencies','S08 startup/final pack/10min/3 restart'],'cleanup':'cleanup.json'})
print(json.dumps({'production_files':len(owned),'runs':len(runs),'groups':len(groups),'all_absent':all(x['status']=='absent' for x in groups),'air_frames':len(air['frames']),'post_air_diff':list(mismatch)},ensure_ascii=False))
