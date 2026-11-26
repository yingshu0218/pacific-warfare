#!/usr/bin/env python3
"""Serial native captures; each child acquires the shared verification lock."""
from pathlib import Path
import json,subprocess,sys
ROOT=Path(__file__).resolve().parents[2]
CAND=ROOT/'candidates/s14-bombing'
rows=[]
for name,mode,take,frames in [
 ('d4y-release-r12','attack_d4y','release',480),
 ('g4m-release-r12','attack_g4m','release',660),
 ('b25-intercept-r12','intercept_b25','damage',480),
 ('sb2c-sea-r12','attack_sb2c','sea',180),
 ('inventory-r12','attack_b25','inventory',0),
]:
 out=CAND/'native'/name
 assert not out.exists(), 'Never overwrite native evidence'
 cmd=[sys.executable,str(ROOT/'tools/verify.py'),'--owner','S14-bomb-'+name,'--project',str(CAND/'stage'),'--timeout','200','--lock-timeout','45','godot','--render','--','--position','-1800,0','--resolution','1280x720','--script','res://tests/s14_bombing/capture.gd','--','--case='+mode,'--take='+take,'--frames='+str(frames),'--output='+str(out)]
 print('CAPTURE_START '+name,flush=True)
 r=subprocess.run(cmd,cwd=ROOT,capture_output=True,text=True,timeout=260)
 print(r.stdout,end='',flush=True)
 if r.returncode:print(r.stderr);raise SystemExit(r.returncode)
 rows.append({'capture':name,**json.loads(r.stdout.strip().splitlines()[-1])})
 (CAND/'evidence/native-reports-r12.json').write_text(json.dumps(rows,indent=2)+'\n')
