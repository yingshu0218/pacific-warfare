#!/usr/bin/env python3
"""Encode bounded RX02 native proof; run under the shared verify lock."""
from pathlib import Path
import json,hashlib,subprocess
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'docs/showcase/evidence/RX02'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
records=[]
for name in ['fire-heavy-r3','follow-sequence']:
 folder=OUT/name;capture=json.loads((folder/'capture.json').read_text());movie=folder/'continuous.mp4';assert not movie.exists()
 frames=[folder/f'frame_{i:04d}.png'for i in range(capture['frames'])];assert all(p.exists()for p in frames)
 subprocess.run(['/opt/homebrew/bin/ffmpeg','-hide_banner','-loglevel','warning','-framerate',str(capture['fps']),'-i',str(folder/'frame_%04d.png'),'-frames:v',str(capture['frames']),'-an','-c:v','libx264','-crf','20','-pix_fmt','yuv420p','-movflags','+faststart',str(movie)],check=True,timeout=35)
 info=json.loads(subprocess.check_output(['/opt/homebrew/bin/ffprobe','-v','error','-show_entries','stream=width,height,avg_frame_rate,nb_frames:format=duration','-of','json',str(movie)],text=True,timeout=10));assert int(info['streams'][0]['nb_frames'])==capture['frames']
 records.append({'sequence':name,'capture_sha256':sha(folder/'capture.json'),'movie_sha256':sha(movie),'frames':capture['frames'],'fps':capture['fps'],'simulation_step_s':capture['simulation_step_s'],'simulated_seconds_per_playback_second':capture['simulation_step_s']*capture['fps'],'probe':info,'png_sha256':{p.name:sha(p)for p in frames},'not_performance':True})
(OUT/'sequences.json').write_text(json.dumps(records,indent=2)+'\n');print(json.dumps([{k:v for k,v in r.items()if k not in ['png_sha256','probe']}for r in records]))
