#!/usr/bin/env python3
"""Summarize retained ordinary Chrome samples without hiding slow frames."""
import json,math,statistics
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
BASE=ROOT/'docs/showcase/evidence/S08/final-20261111'
def dist(data):
 if not data:return None
 a=sorted(data)
 def q(p):
  x=(len(a)-1)*p;i=int(x);return a[i]+(a[min(i+1,len(a)-1)]-a[i])*(x-i)
 return {'frames':len(a),'p50_ms':q(.5),'p95_ms':q(.95),'p99_ms':q(.99),'mean_ms':statistics.mean(a),'mean_fps':1000/statistics.mean(a),'over_33_3ms_ratio':sum(x>33.3 for x in a)/len(a),'over_50ms_ratio':sum(x>50 for x in a)/len(a),'max_ms':max(a)}
def summarize(folder):
 r=[json.loads(x) for x in (folder/'samples.ndjson').read_text().splitlines()];audit=json.loads((folder/'run.json').read_text());phases={}
 for p in audit['phases']:
  name=p['name'];bounds=[p['begin'].get('browser_at_ms',-math.inf),p['end'].get('browser_at_ms',math.inf)];rows=[x for x in r if x['phase']==name and bounds[0]<=x['now_ms']<=bounds[1]];values=[f['ms'] for x in r for f in x['raf'] if f.get('phase',x['phase'])==name and f['visible']=='visible' and bounds[0]<=f['at']<=bounds[1]];cpu={}
  for row in rows:
   for key,value in row['game']['profile_us'].items():cpu[key]=cpu.get(key,0)+value
  phases[name]={'frames':dist(values),'requested':p['begin']['speed'],'actual_scale':p['actual_scale'],'wall_s':p['wall_s'],'sim_s':[p['begin']['time_s'],p['end']['time_s']],'pending_s':[p['begin']['pending_s'],p['end']['pending_s']],'module_cpu_ms_per_wall_s':{k:v/1000/p['wall_s'] for k,v in cpu.items()}}
 memory=[v for x in r for v in x['wasm_bytes']];audio=[v for x in r for v in x['audio']]
 windows={p['name']:[p['begin'].get('browser_at_ms',-math.inf),p['end'].get('browser_at_ms',math.inf)] for p in audit['phases']}
 def within(value,name):return value.get('phase')==name and windows.get(name,[-math.inf,math.inf])[0]<=value['at']<=windows.get(name,[-math.inf,math.inf])[1]
 paused=[v for v in audio if within(v,'sound_enabled_pause')];active=[v for v in audio if within(v,'audible')]
 result={'source':str(folder.relative_to(ROOT)),'samples':len(r),'phases':phases,'identity':audit.get('identity'),'passed':audit['passed'],'failure':audit.get('failure'),'cleanup':audit['cleanup'],'hardware':audit.get('hardware'),'wasm_bytes_range':[min(memory),max(memory)] if memory else None,'js_heap_bytes_range':[min(x['js_heap'] for x in r if x['js_heap']),max(x['js_heap'] for x in r if x['js_heap'])] if any(x['js_heap'] for x in r) else None,'sample_sources_created_max':max(x['audio_sources_created'] for x in r),'audio_peak':max((v['peak'] for v in audio),default=0),'paused_audio_rms_max_after_300ms':max([v['rms'] for v in paused if v['at']>paused[0]['at']+300],default=None),'audible_rms_max':max([v['rms'] for v in active],default=None),'peak_fragments':max(x['game']['fragments'] for x in r),'peaks':{k:max(x['game'][k] for x in r) for k in ['units','mounts','projectile_peak','draw_calls','node_count']},'effects_peak':{k:max(x['game']['effects'][k] for x in r) for k in ['allocated','active','render_instances','visible_instances','dropped','sound_sources','engine_sources']},'restarts':[x for x in audit['interactions'] if x['action'].startswith('restart')],'natural_active_wall_s':sum(p['wall_s'] for p in audit['phases'] if p['name'].startswith('natural'))}
 natural=[x for x in r if x['phase'].startswith('natural')]
 result['natural_sim_s']=sum(p['end']['time_s']-p['begin']['time_s'] for p in audit['phases'] if p['name'].startswith('natural'))
 result['natural_frames']=dist([f['ms'] for x in r for f in x['raf'] if f.get('phase',x['phase']).startswith('natural') and f['visible']=='visible'])
 result['natural_state']={'samples':len(natural),'paused_samples':sum(x['game']['paused'] for x in natural),'ended_samples':sum(bool(x['game']['ended']) for x in natural),'moving_units_range':[min(x['game']['moving_units'] for x in natural),max(x['game']['moving_units'] for x in natural)] if natural else None,'active_units_range':[min(x['game']['active_units'] for x in natural),max(x['game']['active_units'] for x in natural)] if natural else None}
 result['by_generation']={}
 for generation in sorted(set(x['game']['generation'] for x in r)):
  rows=[x['game'] for x in r if x['game']['generation']==generation]
  result['by_generation'][str(generation)]={'sim_s':[rows[0]['sim_s'],rows[-1]['sim_s']],'node_count_range':[min(x['node_count'] for x in rows),max(x['node_count'] for x in rows)],'nodes_at_25_to_40s':[x['node_count'] for x in rows if 25<=x['sim_s']<=40],'fragments_peak':max(x['fragments'] for x in rows),'counts_max':{k:max(x['counts'].get(k,0) for x in rows) for k in set(k for x in rows for k in x['counts'])}}
 result['owned_process_memory']={}
 memfile=folder/'memory.ndjson'
 if memfile.exists():
  for line in memfile.read_text().splitlines():
   sample=json.loads(line);types={x['id']:x['type'] for x in sample['processes']}
   for row in sample['memory']:
    if row['physical_footprint_bytes'] is None:continue
    key=str(row['pid']);entry=result['owned_process_memory'].setdefault(key,{'type':types.get(row['pid']),'scope':sample['scope'],'samples':0,'physical_footprint_bytes_range':[row['physical_footprint_bytes']]*2,'resident_bytes_range':[row['resident_bytes']]*2,'first_utc':sample['utc']})
    entry['samples']+=1;entry['last_utc']=sample['utc']
    for name in ['physical_footprint_bytes','resident_bytes']:
     entry[name+'_range']=[min(entry[name+'_range'][0],row[name]),max(entry[name+'_range'][1],row[name])]
 result['build_outputs']=audit.get('buildManifest',{}).get('outputs')
 result['actual_R_key_presses']=sum(x['action']=='key' and x.get('key')=='KeyR' for x in audit['interactions'])
 result['effects_preempted_peak']=max(x['game']['effects'].get('preempted',0) for x in r)
 result['effects_unallocated_peak']=max(x['game']['effects']['dropped']-x['game']['effects'].get('preempted',0) for x in r)
 result['final_state']=audit.get('final')
 return result
if __name__=='__main__':
 result={}
 for folder in [BASE/'baseline',BASE/'optimized',BASE/'chrome']:
  if (folder/'samples.ndjson').exists() and (folder/'run.json').exists():result[folder.name]=summarize(folder)
 (BASE/'summary.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
 for name,x in result.items():print(name,json.dumps({p:{'p95_ms':v['frames']['p95_ms'] if v['frames'] else None,'actual_scale':v['actual_scale'],'pending_end':v['pending_s'][1]} for p,v in x['phases'].items()},ensure_ascii=False))
