#!/usr/bin/env python3
"""Encode only complete, indexed S14 final recordings, preserving true cadence."""
import hashlib,json,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'docs/showcase/evidence/S14/final'
clips=[]
for d in sorted((OUT/'native').iterdir()):
 if not d.is_dir() or not (d/'capture.json').exists():continue
 cap=json.loads((d/'capture.json').read_text())
 if 'frames' not in cap:continue
 assert cap['passed'] and len(list(d.glob('frame_*.png')))==cap['frames'],d.name
 for i in range(cap['frames']):assert (d/f'frame_{i:04}.png').exists()
 path=OUT/'videos'/(d.name+'.mp4');path.parent.mkdir(exist_ok=True)
 subprocess.run(['/opt/homebrew/bin/ffmpeg','-hide_banner','-loglevel','error','-y','-framerate',str(cap['fps']),'-i',str(d/'frame_%04d.png'),'-c:v','libx264','-preset','fast','-crf','21','-pix_fmt','yuv420p','-movflags','+faststart',str(path)],check=True,timeout=50)
 result=subprocess.run(['/opt/homebrew/bin/ffprobe','-v','error','-select_streams','v:0','-show_entries','stream=width,height,r_frame_rate,nb_frames,duration','-of','json',str(path)],check=True,capture_output=True,text=True,timeout=6)
 data=json.loads(result.stdout)['streams'][0];assert int(data['nb_frames'])==cap['frames'] and data['width']==1280 and data['height']==720
 clips.append({'mode':d.name,'path':str(path.relative_to(ROOT)),'fps':cap['fps'],'frames':cap['frames'],'duration_s':cap['frames']/cap['fps'],'probe':data,'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'capture_sha256':hashlib.sha256((d/'capture.json').read_bytes()).hexdigest()})
 print(d.name+' '+str(cap['frames'])+' frames',flush=True)
(OUT/'videos.json').write_text(json.dumps(clips,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'clips':len(clips),'frames':sum(x['frames'] for x in clips),'duration_s':sum(x['duration_s'] for x in clips),'sampling_is_not_game_performance':True}))
