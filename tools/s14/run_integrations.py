#!/usr/bin/env python3
import argparse,json,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser();p.add_argument('--stage',default='.local/s14-final-runtime');p.add_argument('--modes',nargs='+',default=['four','escort']);a=p.parse_args()
reports=[]
for mode in a.modes:
 cmd=[sys.executable,str(ROOT/'tools/verify.py'),'--owner','S14-integrate-'+mode,'--timeout','145','--lock-timeout','60','--project',a.stage,'godot','--','--script','res://tests/s14_integration.gd','--','--mode='+mode]
 r=subprocess.run(cmd,cwd=ROOT,capture_output=True,text=True,timeout=215);print(r.stdout,end='',flush=True)
 if r.stderr:print(r.stderr,file=sys.stderr,flush=True)
 if r.returncode:raise SystemExit(r.returncode)
 reports.append(json.loads(r.stdout.strip().splitlines()[-1]))
print(json.dumps({'passed':True,'reports':reports}))
