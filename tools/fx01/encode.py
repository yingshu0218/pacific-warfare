from pathlib import Path
import subprocess,json
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'docs/showcase/evidence/FX01'
audit=[]
for name in ['water','flak','tracer','smoke']:
 source=OUT/'native'/name/'frame_%03d.png';target=OUT/(name+'_continuous.mp4')
 command=['/opt/homebrew/bin/ffmpeg','-hide_banner','-loglevel','error','-y','-framerate','10','-i',str(source),'-c:v','libx264','-crf','20','-pix_fmt','yuv420p','-movflags','+faststart','-metadata','comment=Controlled real projectile witness. 10fps evidence encoding, not game performance.',str(target)]
 subprocess.run(command,check=True,timeout=45)
 result=subprocess.run(['/opt/homebrew/bin/ffprobe','-v','error','-show_entries','stream=width,height,avg_frame_rate,nb_frames,duration','-of','json',str(target)],text=True,capture_output=True,check=True,timeout=10)
 audit.append({'case':name,'command':command,'probe':json.loads(result.stdout)})
(OUT/'video_encoding.json').write_text(json.dumps(audit,indent=2)+'\n')
print('FX01 encoded four bounded evidence clips')
