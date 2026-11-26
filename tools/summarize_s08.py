#!/usr/bin/env python3
"""Summarize observed browser frames; retain all raw records and operation windows."""
from __future__ import annotations
import json
import math
from pathlib import Path
import statistics

ROOT=Path(__file__).resolve().parents[1]
EVIDENCE=ROOT/'docs/showcase/evidence/S08'

def distribution(values):
    if not values: return None
    ordered=sorted(values)
    def q(p):
        index=(len(ordered)-1)*p;lo=int(index);hi=min(lo+1,len(ordered)-1)
        return ordered[lo]+(ordered[hi]-ordered[lo])*(index-lo)
    return {'frames':len(values),'p50_ms':q(.5),'p95_ms':q(.95),'p99_ms':q(.99),
            'mean_ms':statistics.mean(values),'mean_fps':1000/statistics.mean(values),
            'over_33_333ms_ratio':sum(v>1000/30 for v in values)/len(values),
            'over_50ms_ratio':sum(v>50 for v in values)/len(values),'over_100ms_ratio':sum(v>100 for v in values)/len(values),'max_ms':max(values)}

def summarize(path):
    rows=[json.loads(line) for line in path.read_text().splitlines()]
    generations={};active_wall_s=0.0;moving_wall_s=0.0;previous=None;epoch=0
    audio_peaks=[];wasm=[];heap=[]
    for row in rows:
        if previous and row['serial']<=previous['serial']: epoch+=1
        row['_epoch']=epoch
        game=row['game'];generation=str(epoch)+':'+str(game['generation'])
        group=generations.setdefault(generation,{'first_utc':row['received_utc'],'first_sim_s':game['sim_s'],'first_now_ms':row['now_ms']})
        group.update(last_utc=row['received_utc'],last_sim_s=game['sim_s'],last_now_ms=row['now_ms'],ended=game['ended'],counts=game['counts'],report=game['report'],last_sequence=game['last_sequence'])
        if previous and previous['_epoch']==epoch and previous['game']['generation']==game['generation'] and not previous['game']['paused'] and not previous['game']['ended'] and previous['environment']['visibility']=='visible':
            interval=(row['now_ms']-previous['now_ms'])/1000
            active_wall_s+=interval
            if previous['game'].get('moving_units',previous['game']['active_units'])>0: moving_wall_s+=interval
        previous=row
        wasm+=row.get('wasm_memory_bytes',[])
        if row.get('js_heap'):heap.append(row['js_heap']['used'])
        audio_peaks += [v['peak'] for frame in row['audio'] for v in frame[1]]
    first_gen=rows[0]['game']['generation']
    selected=[r for r in rows if r['_epoch']==0 and r['game']['generation']==first_gen and 10<=r['game']['sim_s']<=60 and r['game']['speed']==1 and not r['game']['paused'] and r['environment']['visibility']=='visible' and r['game']['camera']['mode']=='auto']
    frames=[f[1] for row in selected for f in row['raf'] if f[2]=='visible']
    cpu=[f for row in selected for f in row['game']['frames']]
    phases={}
    for row in selected:
        phase=row['game']['camera']['label']
        phases.setdefault(phase,[]).extend(f[1] for f in row['raf'] if f[2]=='visible')
    return {'source':str(path.relative_to(ROOT)),'samples':len(rows),'serials_contiguous':all(b['serial']==a['serial']+1 for a,b in zip(rows,rows[1:])),
            'environment':rows[-1]['environment'],'first_utc':rows[0]['received_utc'],'last_utc':rows[-1]['received_utc'],
            'representative_window':'first generation, auto camera, 1x, unpaused, visible, sim 10..60 s; first 10 s warmup excluded',
            'representative_frames':distribution(frames),'camera_phases':{k:distribution(v) for k,v in phases.items()},
            'cpu_mean_ms':{label:statistics.mean(f[index] for f in cpu) for label,index in [('advance',2),('presentation',3),('camera',4),('hud',5)]} if cpu else {},
            'draw_calls_range':[min(r['game']['draw_calls'] for r in selected),max(r['game']['draw_calls'] for r in selected)] if selected else [],
            'generations':generations,'reloads':epoch,'restart_transitions':sum(b['_epoch']==a['_epoch'] and b['game']['generation']>a['game']['generation'] for a,b in zip(rows,rows[1:])),
            'observed_active_wall_s':active_wall_s,'observed_moving_wall_s':moving_wall_s,
            'peaks':{key:max(r['game'][key] for r in rows) for key in ['units','active_units','mounts','projectiles','projectile_peak','pending_s','draw_calls','primitives']},
            'effect_peaks':{key:max(r['game']['effects'][key] for r in rows) for key in ['allocated','active','dropped','sound_sources','engine_sources']},
            'wasm_linear_memory_bytes_range':[min(wasm),max(wasm)] if wasm else None,'js_used_heap_bytes_range':[min(heap),max(heap)] if heap else None,
            'audio_peak_max':max(audio_peaks,default=None),'nonzero_audio_frames':sum(v>1e-5 for v in audio_peaks),
            'audio_sources_created_range':[min(r.get('audio_sources_created',0) for r in rows),max(r.get('audio_sources_created',0) for r in rows)] if 'audio_sources_created' in rows[0] else None,
            'audio_files':[p.name for p in path.parent.glob('audio-*')],
            'operation_evidence':str((path.parent/'actions.ndjson').relative_to(ROOT)),'screenshots':[p.name for p in path.parent.glob('capture-*.png')]}

if __name__=='__main__':
    result={str(path.parent.relative_to(EVIDENCE)):summarize(path) for path in EVIDENCE.rglob('samples.ndjson')}
    (EVIDENCE/'summary.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    for name,summary in result.items():
        print(name,json.dumps({k:summary[k] for k in ['samples','serials_contiguous','representative_frames','observed_active_wall_s','restart_transitions','wasm_linear_memory_bytes_range','audio_peak_max']},ensure_ascii=False))
