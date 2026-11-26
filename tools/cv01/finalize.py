#!/usr/bin/env python3
"""Audit CV01-only frozen sources, deterministic generation, links and owned cleanup."""
import ast,datetime as dt,hashlib,json,os,re,shutil,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'docs/showcase/evidence/CV01'
REF=ROOT/'docs/references/ships/essex_cv9_1944_04_15'
SHA=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def save(p,j):p.write_text(json.dumps(j,ensure_ascii=False,indent=2)+'\n')
def report_runs():
 runs=[]
 for p in sorted((ROOT/'.local/validation/runs').glob('*/report.json')):
  j=json.loads(p.read_text())
  if j.get('owner')!='CV01':continue
  dest=OUT/'verification'/j['run_id'];dest.mkdir(parents=True,exist_ok=True)
  shutil.copy2(p,dest/'report.json')
  for log in p.parent.glob('*.log'):shutil.copy2(log,dest/log.name)
  runs.append(j)
 return runs

def main():
 errors=[];runtime=json.loads((OUT/'build_manifest.json').read_text())
 changed=[name for name,value in runtime['source_sha256'].items() if not (ROOT/name).is_file() or SHA(ROOT/name)!=value]
 if changed:errors.append('Frozen runtime changed: '+repr(changed))
 generated=sorted([p for p in (ROOT/'naval/essex_cv9_1944_04_15').rglob('*') if p.suffix in ['.json','.tscn']])
 before={str(p.relative_to(ROOT)):SHA(p) for p in generated}
 result=subprocess.run([sys.executable,str(ROOT/'tools/cv01/build_data.py')],cwd=ROOT,text=True,capture_output=True,timeout=10)
 if result.returncode:errors.append('Generator failed: '+result.stdout+result.stderr)
 generation_matches=all(SHA(ROOT/name)==value for name,value in before.items())
 if not generation_matches:errors.append('Generated data/scenes not reproducible')
 for p in (ROOT/'tools/cv01').glob('*.py'):ast.parse(p.read_text(),filename=str(p))
 syntax=subprocess.run(['/opt/homebrew/bin/node','--check',str(ROOT/'tools/cv01/chrome_check.mjs')],capture_output=True,text=True,timeout=10)
 if syntax.returncode:errors.append('Chrome script syntax failed: '+syntax.stderr)
 mechanism=json.loads((OUT/'mechanism.json').read_text());chrome=json.loads((OUT/'chrome/run.json').read_text())
 if not mechanism['passed'] or not chrome['passed']:errors.append('Final mechanism or Chrome not passed')
 if not all(chrome['cleanup'].values()):errors.append('Chrome cleanup incomplete')
 refs=json.loads((REF/'sources.json').read_text())
 inspected=[r['id'] for r in refs if 'actually opened' in r.get('status','')]
 if len(inspected)!=11:errors.append('Expected 5 photo + 6 plan original inspections')
 for row in refs:
  if row['id'] not in inspected:continue
  p=ROOT/row['local_path']
  if SHA(p)!=row['sha256']:errors.append('Reference hash changed: '+row['id'])
 runs=report_runs();groups=[]
 for run in runs:
  for check in run.get('checks',[]):
   pid=check.get('process_group')
   if not pid:continue
   try:os.killpg(pid,0);alive=True
   except ProcessLookupError:alive=False
   except PermissionError:alive='permission_denied'
   groups.append(dict(run_id=run['run_id'],pid=pid,cleanup_ok=check.get('cleanup_ok'),alive=alive))
   if check.get('cleanup_ok') is not True or alive is not False:errors.append('Unverified prior owned process group '+str(pid))
 ps=subprocess.run(['/bin/ps','-axo','pid=,pgid=,command='],capture_output=True,text=True,timeout=5)
 markers=['.local/cv01-chrome-','tools/cv01/chrome_check.mjs']
 leftovers=[line for line in ps.stdout.splitlines() if any(m in line for m in markers)] if ps.returncode==0 else ['ps unavailable']
 if leftovers:errors.append('Owned browser/server process inspection: '+repr(leftovers))
 crops=ROOT/'.local/cv01-reference-crops'
 if crops.exists():shutil.rmtree(crops)
 cleanup=dict(passed=not errors,owned_groups=groups,chrome=chrome['cleanup'],owned_browser_server_processes=leftovers,temporary_reference_crops_removed=not crops.exists(),scope='Only CV01-owned groups inspected with signal0; no unrelated/user process signalled; current finalizer wrapper cleans itself after exit',checked_utc=dt.datetime.now(dt.timezone.utc).isoformat())
 save(OUT/'cleanup.json',cleanup)
 validation=dict(passed=not errors,errors=errors,mechanism_checks=mechanism['checks'],chrome_checks=len(chrome['checks']),chrome_views=len(chrome['views']),frozen_sources_unchanged=not changed,generator=dict(command='python3 tools/cv01/build_data.py',files=len(before),sha256_unchanged=generation_matches,stdout=result.stdout.strip()),python_ast=True,node_syntax=syntax.returncode==0,inspected_original_ids=inspected,runs=[dict(run_id=r['run_id'],action=r['action'],passed=r['passed'],error=r.get('error'),exit_code=r['exit_code'],project=r['project'],evidence='verification/'+r['run_id']+'/report.json') for r in runs])
 save(OUT/'validation.json',validation)
 owned=[]
 for directory in [ROOT/'naval/essex_cv9_1944_04_15',ROOT/'tools/cv01',REF]:
  owned.extend(p for p in directory.rglob('*') if p.is_file() and p.suffix not in ['.pyc','.import'] and '__pycache__' not in str(p))
 owned += [ROOT/'docs/carrier-deck-contracts.md',ROOT/'docs/showcase/deliveries/CV01.md',ROOT/'docs/deliveries/CV01.md']
 evidence=[p for p in OUT.rglob('*') if p.is_file() and p.name!='manifest.json']
 save(OUT/'manifest.json',dict(status='pending coordinator visual acceptance',runtime_source_sha256=runtime['source_sha256'],owned_file_sha256={str(p.relative_to(ROOT)):SHA(p) for p in sorted(set(owned))},evidence_sha256={str(p.relative_to(ROOT)):SHA(p) for p in sorted(evidence)},unchanged_shared_dependencies=[name for name in runtime['source_sha256'] if not name.startswith('naval/essex_cv9_1944_04_15/')],model_id='us_essex_cv9_1944_04_15',configuration_date='1944-04-15'))
 broken=[]
 for p in owned:
  if p.suffix!='.md':continue
  for rel in re.findall(r'\]\(([^)]+)\)',p.read_text()):
   if '://' in rel or rel.startswith('#'):continue
   target=(p.parent/rel.split('#')[0]).resolve()
   if not target.exists():broken.append([str(p.relative_to(ROOT)),rel])
 if broken:
  errors.append('Broken local links '+repr(broken));validation.update(passed=False,errors=errors);save(OUT/'validation.json',validation)
 print(json.dumps(dict(passed=not errors,errors=errors,runs=len(runs),process_groups=len(groups),owned_files=len(set(owned)),evidence_files=len(evidence),runtime_files=len(runtime['source_sha256']),generated_files=len(before)),ensure_ascii=False))
 return 0 if not errors else 1
if __name__=='__main__':raise SystemExit(main())
