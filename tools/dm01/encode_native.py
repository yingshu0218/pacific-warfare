#!/usr/bin/env python3
"""Encode real DM01 frame sequences; run only inside tools/verify.py exec."""
from pathlib import Path
import json,subprocess,hashlib,shutil,argparse
ROOT=Path(__file__).resolve().parents[2]
parser=argparse.ArgumentParser()
parser.add_argument('--source',default='.local/dm01-final-frames')
args=parser.parse_args()
SOURCE=ROOT/args.source
OUT=ROOT/'docs/showcase/evidence/DM01/final-native'
OUT.mkdir(parents=True,exist_ok=True)
records=[]
for folder in sorted(SOURCE.iterdir()):
    capture=folder/'capture.json'
    if not capture.exists():continue
    data=json.loads(capture.read_text());name=folder.name
    command=['/opt/homebrew/bin/ffmpeg','-hide_banner','-loglevel','error','-y','-framerate',str(data['fps']),'-i',str(folder/'frame_%04d.png'),'-c:v','libx264','-preset','fast','-crf','21','-pix_fmt','yuv420p','-movflags','+faststart',str(OUT/(name+'.mp4'))]
    result=subprocess.run(command,capture_output=True,text=True,timeout=45)
    if result.returncode:raise RuntimeError(result.stderr)
    movie=OUT/(name+'.mp4');shutil.copyfile(capture,OUT/(name+'.json'))
    shutil.copyfile(folder/'frame_0045.png',OUT/(name+'.png'))
    counts={}
    for event in data['events']:counts[event['kind']]=counts.get(event['kind'],0)+1
    impacts=[e for e in data['events']if e['kind']=='unit_impact']
    if impacts:
        frame=min(data['frames']-1,int((impacts[0]['time_s']+1.5)*data['fps']))
        shutil.copyfile(folder/('frame_%04d.png'%frame),OUT/(name+'-water.png'))
    records.append({'name':name,'fps':data['fps'],'frames':data['frames'],'seconds':data['frames']/data['fps'],'resolution':data['resolution'],'command':command,'event_counts':counts,'impact_time_s':impacts[0]['time_s']if impacts else None,'last_phase':data['samples'][-1]['target']['module_data']['damage']['phase'],'peak_effects':max(s['effects']['visible_instances']for s in data['samples']),'bytes':movie.stat().st_size,'sha256':hashlib.sha256(movie.read_bytes()).hexdigest()})
(OUT/'index.json').write_text(json.dumps({'scope':'Eight genuine existing-ammo native damage sequences; 15fps recording cadence, not a performance benchmark. Fixed audited FX01 revision3 patch2.','clips':records},ensure_ascii=False,indent=2)+'\n')
print('Encoded',len(records),'native clips,',sum(r['frames']for r in records),'frames; genuine event counts retained.')
