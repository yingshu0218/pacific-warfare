#!/usr/bin/env python3
"""Serial native capture through the shared verify lock; no command-side simulation edits."""
import argparse,json,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser();p.add_argument('--stage',default='.local/s14-final-runtime');p.add_argument('--modes',nargs='+',default=['inventory','four','escort']);p.add_argument('--timeout',type=int,default=180);a=p.parse_args()
for mode in a.modes:
 out=ROOT/'docs/showcase/evidence/S14/final/native'/mode
 fps=15 if mode.startswith('train_') else 10
 limit=65 if mode.startswith('train_') else 235
 command=[sys.executable,str(ROOT/'tools/verify.py'),'--owner','S14-native-'+mode,'--timeout',str(a.timeout),'--lock-timeout','60','--project',a.stage,'godot','--render','--','--minimized','--resolution','1280x720','--script','res://tests/s14_final_capture.gd','--','--mode='+mode,'--fps='+str(fps),'--limit='+str(limit),'--output='+str(out)]
 r=subprocess.run(command,cwd=ROOT,capture_output=True,text=True,timeout=a.timeout+75);print(r.stdout,end='',flush=True)
 if r.stderr:print(r.stderr,file=sys.stderr,flush=True)
 if r.returncode:raise SystemExit(r.returncode)
 print('Captured '+mode,flush=True)
