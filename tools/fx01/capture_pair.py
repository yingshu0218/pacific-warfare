"""Capture a same-input before/after pair under the shared engine lock."""
from pathlib import Path
import subprocess,sys,json,hashlib,shutil
ROOT=Path(__file__).resolve().parents[2];STAGE=ROOT/'.local/fx01-project';OUT=ROOT/'docs/showcase/evidence/FX01'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def inputs():return {str(p.relative_to(STAGE)):sha(p) for p in STAGE.rglob('*') if p.is_file() and '.godot' not in p.parts and 'docs' not in p.relative_to(STAGE).parts}
before=inputs();reports=[]
for legacy in [True,False]:
 args=['--baseline','--evidence-dir=res://docs/showcase/evidence/FX01/before'] if legacy else []
 r=subprocess.run([sys.executable,str(ROOT/'tools/verify.py'),'--owner','FX01-r3-before' if legacy else 'FX01-r3-native','--timeout','180','--lock-timeout','45','--project',str(STAGE),'godot','--render','--','--script','res://tests/fx01_capture.gd','--',*args],cwd=ROOT,text=True,capture_output=True,timeout=240)
 print(r.stdout,end='',flush=True)
 if r.returncode:print(r.stderr);raise SystemExit(r.returncode)
 reports.append(json.loads(r.stdout.splitlines()[-1])['report'])
after=inputs();assert before==after,'Frozen runtime sources drifted during pair'
shutil.copytree(STAGE/'docs/showcase/evidence/FX01',OUT,dirs_exist_ok=True)
comparison={}
for case in ['water','flak','tracer','smoke']:
 a=json.loads((OUT/'before'/f'{case}_events.json').read_text());b=json.loads((OUT/'native'/f'{case}_events.json').read_text())
 comparison[case]={'identical_real_events':a==b,'count':len(b)}
 assert a==b,case+' changed simulated events'
(OUT/'native_input_comparison.json').write_text(json.dumps(comparison,indent=2)+'\n')
(OUT/'runtime_inputs.json').write_text(json.dumps({'stage':str(STAGE),'scope':'Frozen S10/S13 production input; FX01 revision3 overlay; batched presentation at6ticks/frame','sources':before,'hashes_stable_during_capture':before==after,'reports':reports},ensure_ascii=False,indent=2)+'\n')
print('FX01 same-input native pair passed',comparison)
