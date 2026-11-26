#!/usr/bin/env python3
"""Encode actual fixed-tick frames without interpolation, and audit provenance."""
from pathlib import Path
import argparse, hashlib, json, subprocess

ROOT = Path(__file__).resolve().parents[2]
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    parser=argparse.ArgumentParser();parser.add_argument('stage');args=parser.parse_args()
    folder=ROOT/'docs/showcase/evidence/BOMB01'/args.stage
    source=json.loads((folder/'input-manifest.json').read_text())
    stage=Path(source['stage'])
    drift=[name for name,digest in source['inputs'].items() if sha(stage/name)!=digest]
    if drift: raise SystemExit('Frozen source drift: '+str(drift))
    records=[]
    for name in ['b25-bombing','d4y-bombing','sb2c-bombing','g4m-bombing','g4m-interception','b25-interception']:
        clip=folder/'native'/name
        capture=json.loads((clip/'capture.json').read_text())
        frames=sorted(clip.glob('frame_*.png'))
        expected=[f'frame_{i:05d}.png' for i in range(capture['frames'])]
        assert [p.name for p in frames]==expected
        samples=capture['samples']
        assert len(samples)==len(frames)
        assert all(samples[i]['tick']-samples[i-1]['tick']==4 for i in range(1,len(samples)))
        assert capture['fps']==15
        assert all(float(row['distance_m'])<.005 for row in capture['slot_comparisons'])
        movie=clip/'action.mp4'
        command=['/opt/homebrew/bin/ffmpeg','-nostdin','-y','-loglevel','error','-framerate','15','-i',str(clip/'frame_%05d.png'),'-frames:v',str(len(frames)),'-c:v','libx264','-preset','fast','-crf','19','-pix_fmt','yuv420p','-movflags','+faststart',str(movie)]
        subprocess.run(command,check=True,timeout=45)
        info=json.loads(subprocess.check_output(['/opt/homebrew/bin/ffprobe','-v','error','-select_streams','v:0','-show_entries','stream=nb_frames,avg_frame_rate,width,height','-of','json',str(movie)],timeout=10))['streams'][0]
        assert int(info['nb_frames'])==len(frames) and info['avg_frame_rate']=='15/1'
        record={'name':name,'case_id':capture['case_id'],'observed_unit_id':capture['observed_unit_id'],'frames':len(frames),'fps':15,'video':str(movie.relative_to(ROOT)),'video_sha256':sha(movie),'capture_sha256':sha(clip/'capture.json'),'frames_sha256':{p.name:sha(p) for p in frames},'frame_probe':info,'first_tick':samples[0]['tick'],'last_tick':samples[-1]['tick'],'fixed_ticks_per_frame':4,'interpolation':False,'maximum_slot_error_m':max([float(p['distance_m']) for p in capture['slot_comparisons']] or [0]),'events':{kind:sum(e['kind']==kind for e in capture['events']) for kind in ['bomb_released','bomb_source_cleared','bomb_contact','bomb_explosion','damaged','aircraft_part_detached','unit_surface_contact']}}
        records.append(record)
        print(json.dumps({k:record[k] for k in ['name','frames','video_sha256','events']}),flush=True)
    result={'stage':args.stage,'input_manifest_sha256':sha(folder/'input-manifest.json'),'source_drift':drift,'capture_script_sha256':source['inputs']['tests/bombing/capture.gd'],'encoder_script_sha256':sha(Path(__file__)),'clips':records}
    (folder/'native-manifest.json').write_text(json.dumps(result,indent=2)+'\n')

if __name__=='__main__':main()
