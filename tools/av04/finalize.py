#!/usr/bin/env python3
"""Freeze closed AV04 evidence. No rendering, engine, browser, encoding or signals."""
from pathlib import Path
import datetime as dt,hashlib,json,os,shutil,struct
ROOT=Path(__file__).resolve().parents[2]
E=ROOT/'docs/showcase/evidence/AV04'
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):return json.loads(p.read_text())
def write(p,v):p.write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n')
def freeze(name):
 p=ROOT/name;out=E/'inputs'/name;out.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p,out)
 if digest(p)!=digest(out):raise SystemExit('bad frozen copy '+name)
 return digest(p)
def main():
 contract=read(ROOT/'aircraft/b25j/data/interfaces.json')
 if contract['failures'] or contract['checks']!=235:raise SystemExit('AV04 final235check run required')
 for n,h in contract['source_hashes'].items():
  if digest(ROOT/n)!=h:raise SystemExit('stale contract source '+n)
 captures=[]
 for p in sorted((E/'final').glob('*.png')):
  meta_path=Path(str(p)+'.json');meta=read(meta_path)
  for n,h in meta['source_hashes'].items():
   if digest(ROOT/n)!=h:raise SystemExit('stale capture '+p.name+' / '+n)
  if struct.unpack('>II',p.read_bytes()[16:24])!=(1440,900):raise SystemExit('wrong image resolution '+p.name)
  if any(abs(v-1.0)>0.00001 for v in meta['model_scale']):raise SystemExit('model scaled '+p.name)
  captures.append({'file':str(p.relative_to(ROOT)),'sha256':digest(p),'metadata':str(meta_path.relative_to(ROOT)),'metadata_sha256':digest(meta_path),'view':meta['view'],'source_hash_entries':len(meta['source_hashes'])})
 if len(captures)!=23:raise SystemExit('23 final views required')
 own=[]
 for dirname in ['aircraft/b25j','tests/av04','tools/av04']:
  own += [str(p.relative_to(ROOT)) for p in (ROOT/dirname).rglob('*') if p.is_file() and (p.suffix in ['.gd','.tscn','.uid','.json','.md','.py'] or p.name=='.gdignore')]
 own += ['docs/showcase/deliveries/AV04.md','docs/deliveries/AV04.md']
 own_hashes={n:freeze(n) for n in sorted(set(own))}
 readonly=read(ROOT/'aircraft/b25j/data/readonly_dependencies.json')['paths']
 readonly_hashes={n:freeze(n) for n in readonly}
 ref=ROOT/'docs/references/aircraft/b25j_1944_07'
 references={str(p.relative_to(ROOT)):digest(p) for p in sorted(ref.rglob('*')) if p.is_file() and p.suffix!='.import'}
 baseline=read(E/'baseline.json')
 comparison={n:{'before':h,'after':digest(ROOT/n),'same':h==digest(ROOT/n)} for n,h in baseline.items()}
 write(E/'baseline-comparison.json',comparison)
 if any(not x['same'] for x in comparison.values()):raise SystemExit('protected file changed; review baseline comparison')
 runs=[];groups=[];remaining=[];unknown=[]
 for path in sorted((ROOT/'.local/validation/runs').glob('*/report.json')):
  r=read(path)
  if r.get('owner')!='AV04':continue
  dest=E/'validation'/r['run_id'];dest.mkdir(parents=True,exist_ok=True)
  logs={}
  for p in [path]+sorted(path.parent.glob('*.log')):
   shutil.copy2(p,dest/p.name);logs[str((dest/p.name).relative_to(ROOT))]=digest(p)
  checks=[]
  for c in r.get('checks',[]):
   checks.append({k:c.get(k) for k in ['command','returncode','timed_out','diagnostic_error','cleanup_ok','process_group','duration_s','passed']})
   group=c.get('process_group')
   if group:
    groups.append(group)
    try:os.killpg(group,0)
    except ProcessLookupError:pass
    except PermissionError:unknown.append(group)
    else:remaining.append(group)
  runs.append({'run_id':r['run_id'],'action':r['action'],'passed':r['passed'],'exit_code':r['exit_code'],'error':r.get('error'),'checks':checks,'log_hashes':logs})
 if remaining or unknown:raise SystemExit('owned group audit unresolved '+repr([remaining,unknown]))
 write(E/'verification-index.json',runs)
 lock=read(ROOT/'.local/validation/godot-render.lock')
 cleanup={'checked_utc':dt.datetime.now(dt.timezone.utc).isoformat(),'recorded_process_groups':groups,'remaining_groups':remaining,'unknown_groups':unknown,'all_child_cleanup_ok':all(c['cleanup_ok'] for r in runs for c in r['checks']),'created_browser_tabs':0,'created_http_services':0,'started_editor':False,'started_ffmpeg':False,'lock_at_audit':lock,'own_lock_held':lock.get('owner')=='AV04' and lock.get('status')=='held','scope':'probe only AV04 recorded groups; no signals or changes to S14/user processes','failed_attempts_preserved':[{'run_id':r['run_id'],'reason':r.get('error') or 'sandbox user-log/system-CA diagnostics; child returned0 and cleaned'} for r in runs if not r['passed']]}
 write(E/'cleanup.json',cleanup)
 extras={str(p.relative_to(ROOT)):digest(p) for p in [E/'contracts.json',E/'comparison.md',E/'verification-index.json',E/'cleanup.json',E/'baseline-comparison.json',E/'baseline.json',E/'final-batch.json']}
 manifest={'date_cn':'2026-11-11','generated_utc':dt.datetime.now(dt.timezone.utc).isoformat(),'status':'pure_model_and_MAP02_static_fit_frozen_pending_coordinator_and_S14','identity':'B-25J-1-NC early glazed bomber / 1944-07 representative configuration','source_hashes':own_hashes,'readonly_dependency_hashes':readonly_hashes,'readonly_dependency_scope':'actual map/query/render resources plus conservative declared class/type closure; retained type references do not mean simulation is executed','readonly_copies_in_inputs':True,'reference_hashes':references,'captures':captures,'other_evidence_hashes':extras,'contract_checks':contract['checks'],'marker_count':len(contract['markers']),'gun_barrels':sum(g['barrels'] for g in contract['gun_specs'].values()),'payload_slots':len(contract['bomb_slots']),'stats':contract['stats'],'wrapper_runs':len(runs),'passed_wrapper_runs':sum(r['passed'] for r in runs),'recorded_groups':len(groups),'model_sha256':digest(ROOT/'aircraft/b25j/b25j.gd'),'chrome_done':False,'ordinary_showcase_registered':False,'scope_limits':contract['not_implemented']}
 write(E/'manifest.json',manifest)
 (E/'manifest.sha256').write_text(digest(E/'manifest.json')+'  manifest.json\n')
 print(json.dumps({'source_files':len(own_hashes),'readonly_files':len(readonly_hashes),'reference_files':len(references),'captures':len(captures),'checks':contract['checks'],'markers':len(contract['markers']),'wrapper_runs':len(runs),'passed_runs':sum(r['passed'] for r in runs),'recorded_groups':len(groups),'remaining_groups':remaining,'model_sha256':manifest['model_sha256'],'manifest_sha256':digest(E/'manifest.json')},ensure_ascii=False))
if __name__=='__main__':main()
