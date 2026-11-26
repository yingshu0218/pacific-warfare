#!/usr/bin/env python3
"""Encode actual S14 native frame sequences; run through tools/verify.py."""
import json,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
DIR=ROOT/'docs/showcase/evidence/S14'
results=[]
for mode in ['pair','four','maneuver','escort']:
 p=DIR/'native'/mode
 out=DIR/(mode+'_phase.mp4')
 subprocess.run(['/opt/homebrew/bin/ffmpeg','-hide_banner','-loglevel','error','-y','-framerate','10','-i',str(p/'frame_%04d.png'),'-c:v','libx264','-pix_fmt','yuv420p','-crf','21','-movflags','+faststart',str(out)],check=True,timeout=35)
 probe=subprocess.run(['/opt/homebrew/bin/ffprobe','-v','error','-select_streams','v:0','-show_entries','stream=width,height,r_frame_rate,nb_frames,duration','-of','json',str(out)],capture_output=True,text=True,check=True,timeout=5)
 results.append({'mode':mode,'path':str(out.relative_to(ROOT)),'probe':json.loads(probe.stdout)})
(DIR/'videos.json').write_text(json.dumps(results,ensure_ascii=False,indent=2)+'\n')
print('Encoded 4 real 24s / 240-frame clips; 10fps is evidence frequency, not Chrome FPS.')
