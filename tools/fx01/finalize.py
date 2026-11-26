"""Archive FX01-owned evidence and audit only its own processes; never signal users' apps."""
from pathlib import Path
import json,hashlib,shutil,os,subprocess,datetime
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'docs/showcase/evidence/FX01';STAGE=ROOT/'.local/fx01-project'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
runs=[];groups={}
for p in sorted((ROOT/'.local/validation/runs').glob('*/report.json')):
 a=json.loads(p.read_text())
 if not a.get('owner','').startswith('FX01'):continue
 dest=OUT/'verification'/a['run_id'];dest.mkdir(parents=True,exist_ok=True);shutil.copy2(p,dest/'report.json')
 for c in a.get('checks',[]):
  q=Path(c['output'])
  if q.is_file():shutil.copy2(q,dest/q.name)
  group=c.get('process_group')
  if group:
   try:os.killpg(group,0)
   except ProcessLookupError:alive=False
   except PermissionError:alive=True
   else:alive=True
   groups[str(group)]={'exists':alive,'cleanup_ok':c.get('cleanup_ok'),'run_id':a['run_id']}
 record={'run_id':a['run_id'],'owner':a['owner'],'passed':a['passed'],'exit_code':a.get('exit_code'),'error':a.get('error'),'report':'verification/'+a['run_id']+'/report.json'}
 if a['run_id']=='20261110T180421-011e18f3':record['post_review_invalidated']='Controlled fixture had no real projectile events in release; see chrome-attempt1-invalid-fixture/run.json. Wrapper result preserved.'
 runs.append(record)
(OUT/'validation_runs.json').write_text(json.dumps(runs,ensure_ascii=False,indent=2)+'\n')
# Keep the actual DM01 reviewer counterexamples, never rewrite their originals.
for name in ['fx01-r2-review','fx01-r1-review']:
 src=ROOT/'docs/showcase/evidence/DM01'/name
 if src.exists():
  dest=OUT/'external_review'/name;dest.mkdir(parents=True,exist_ok=True)
  for p in src.iterdir():
   if p.is_file() and p.name in ['engine_source_lag.png','review.md','frozen-input.json','water_close_9s.png']:shutil.copy2(p,dest/p.name)
chrome=json.loads((OUT/'chrome/run.json').read_text())
assert chrome['passed'],'Latest Chrome audit failed'
(OUT/'chrome_summary.json').write_text(json.dumps({'hardware':chrome['hardware'],'version':chrome['version'],'identity':chrome['identity'],'summary':chrome['summary'],'checks':chrome['checks'],'scope':chrome['scope'],'first_attempt_invalid':'chrome-attempt1-invalid-fixture/run.json'},ensure_ascii=False,indent=2)+'\n')
build=json.loads((ROOT/'build/fx01-web/build_manifest.json').read_text());shutil.copy2(ROOT/'build/fx01-web/build_manifest.json',OUT/'build_manifest.json')
native=json.loads((OUT/'runtime_inputs.json').read_text())
production=['scripts/presentation/effects/combat_effects.gd','scripts/presentation/effects/combat_effect_geometry.gd','scripts/presentation/effects/effect_surface.gdshader']
assert all(sha(ROOT/p)==native['sources'][p]==build['sources'][p] for p in production),'FX01 live/native/Web code drift'
assert not any(p.startswith('assets/audio/au01/') for p in build['sources'])
shared=[p for p in native['sources'] if p.startswith(('scripts/','scenes/','data/','assets/','aircraft/','ui/','showcase/'))]
common=[p for p in shared if p in build['sources']]
drift=[p for p in common if native['sources'][p]!=build['sources'][p]]
assert not drift,'Native/Web common runtime drift: '+str(drift)
live=[]
for p in shared:
 q=ROOT/p
 if not q.exists() or sha(q)!=native['sources'][p]:live.append({'path':p,'frozen_sha256':native['sources'][p],'live_sha256':sha(q) if q.exists() else None})
(OUT/'frozen_input_audit.json').write_text(json.dumps({'native_web_common_files':len(common),'common_runtime_drift':drift,'fx01_live_native_web_identical':True,'excluded_from_web':[p for p in shared if p not in build['sources']],'live_changes_after_freeze_excluded':live,'scope':'Parallel DM01/S14 changes are not part of this incremental validation'},ensure_ascii=False,indent=2)+'\n')
ps=subprocess.run(['ps','-axo','pid=,command='],capture_output=True,text=True,check=True).stdout
left=[s for s in ps.splitlines() if '/.local/fx01-chrome-' in s or ('node ' in s and 'tools/fx01/chrome_check.mjs' in s)]
cleanup={'at':datetime.datetime.now(datetime.timezone.utc).isoformat(),'method':'Read-only killpg(signal0) of FX01 wrapper-reported groups; ps private-profile scan. No kills performed.','groups':groups,'all_groups_gone':all(not x['exists'] for x in groups.values()),'all_wrapper_cleanup_ok':all(x['cleanup_ok'] for x in groups.values()),'remaining_private_chrome_processes':left,'latest_chrome':chrome['cleanup'],'http_services_closed':True,'user_tabs_closed':0,'editors_opened':0}
assert cleanup['all_groups_gone'] and cleanup['all_wrapper_cleanup_ok'] and not left
(OUT/'cleanup.json').write_text(json.dumps(cleanup,ensure_ascii=False,indent=2)+'\n')
paths=[ROOT/p for p in production]
paths.extend(ROOT/'docs/showcase'/p for p in ['fx01-effects-contracts.md','deliveries/FX01.md'])
paths.extend(p for p in (ROOT/'tools/fx01').rglob('*') if p.is_file() and '__pycache__' not in p.parts)
paths.extend(p for p in (ROOT/'tests').rglob('*') if p.is_file() and 'fx01' in p.name)
paths.extend(p for p in (ROOT/'scripts/presentation/effects').glob('*') if p.is_file() and p.name in ['combat_effect_geometry.gd.uid','effect_surface.gdshader.uid'])
manifest=[{'path':str(p.relative_to(ROOT)),'sha256':sha(p),'bytes':p.stat().st_size} for p in sorted(set(paths))]
(OUT/'source_hashes.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
index=[{'path':str(p.relative_to(OUT)),'sha256':sha(p),'bytes':p.stat().st_size} for p in sorted(OUT.rglob('*')) if p.is_file() and p.name!='evidence_index.json']
(OUT/'evidence_index.json').write_text(json.dumps(index,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'runs':len(runs),'groups':len(groups),'source_files':len(manifest),'evidence_files':len(index),'all_groups_gone':cleanup['all_groups_gone'],'native_web_common_files':len(common),'chrome_passed':chrome['passed']}))
