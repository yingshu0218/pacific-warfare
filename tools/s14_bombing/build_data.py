#!/usr/bin/env python3
"""Generate the six production-movement/AA cases from the admitted model data."""
from pathlib import Path
import json
ROOT=Path(__file__).resolve().parents[2]; CAND=ROOT/'candidates/s14-bombing'; O=CAND/'overrides'
def read(p):return json.loads(p.read_text())
def put(name,value):
 p=O/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n')
integration=CAND/'stage/data/bombing'
parameters=read(integration/'parameters.json');performance=read(integration/'performance.json')
current=read(O/'data/aircraft/performance.json')
for key in parameters['aircraft']:current[key]=performance[key]
assert current['us_f6f5_1944']['role']=='fighter' and current['jp_a6m5a_1944']['role']=='fighter'
put('data/aircraft/performance.json',current)
for unit in read(integration/'units.json'):
 key=unit['id'];unit['model_scene']='res://scenes/units/aircraft/'+key+'.tscn'
 put('data/units/'+key+'.json',unit)
 p=O/('scenes/units/aircraft/'+key+'.tscn');p.parent.mkdir(parents=True,exist_ok=True)
 p.write_text('[gd_scene load_steps=2 format=3]\n\n[ext_resource type="Script" path="res://scripts/showcase/bombing/aircraft_adapter.gd" id="1"]\n\n[node name="BombingAircraft" type="Node3D"]\nscript = ExtResource("1")\ndefinition_id = "'+key+'"\n')
for key,ammo in parameters['ammunition'].items():put('data/ammunition/'+key+'.json',ammo)
combat=read(O/'data/combat/s14_expansion.json');extra=read(integration/'combat_profiles.json')
combat['unit_profiles'].update(extra['unit_profiles']);combat['ammo_profiles'].update(parameters['ammo_profiles'])
put('data/combat/s14_bombing.json',combat)
base=read(O/'data/scenarios/s14_expansion_harbor.json')
site=next(v['site_id']for v in base['ground_deployments']if v['id']=='us_aa_01')
names={'us_sb2c4_1944':'SB2C-4','jp_d4y2_model12_1944_10':'D4Y2','jp_g4m1_1942_07':'G4M1','us_b25j_1944_07':'B-25J'}
for original,case in read(integration/'scenarios.json')['cases'].items():
 key={'bombing_us_sb2c4_1944':'attack_sb2c','bombing_jp_d4y2_model12_1944_10':'attack_d4y','bombing_jp_g4m1_1942_07':'attack_g4m','bombing_us_b25j_1944_07':'attack_b25','intercept_jp_g4m1_1942_07':'intercept_g4m','intercept_us_b25j_1944_07':'intercept_b25'}[original]
 if key=='attack_sb2c':
  case['spawns'][0]['position_m'][2]=2800
  wing=json.loads(json.dumps(case['spawns'][0]));wing['id']='wing';wing['position_m'][0]+=180;wing['position_m'][2]+=80;case['spawns'].append(wing);case['goals'][0]['unit_ids'].append('wing')
 d={k:v for k,v in base.items() if k in ['seed','tick_hz','factions','environment','fleet_profiles_path']}
 d.update(id='s14_'+key,spawns=[],groups=[],ground_deployments=[],bombing_goals=[g for g in case['goals']if g['order_type']=='bombing'],combat_overlay_path='res://data/combat/s14_bombing.json',combat_profile_override_ids=['us_sb2c4_1944'],showcase={'mode':key})
 labels={};model=case['spawns'][0]['unit_definition_id']
 for spawn in case['spawns']:
  spawn=json.loads(json.dumps(spawn));spawn.get('module_data',{}).pop('combat_intent',None)
  if spawn['id']=='target' and spawn['unit_definition_id']=='us_40mm_m1_m2a1_1944':
   d['ground_deployments'].append({'id':'target','site_id':site,'unit_definition_id':spawn['unit_definition_id'],'faction_id':'us'});labels['target']='港区 M1 防空炮';continue
  if spawn['id']=='target':spawn['velocity_mps']=[0,0,-10];labels['target']='雪风 · 机动防空'
  elif spawn['id']=='fighter':labels['fighter']='F6F 截击机' if spawn['faction_id']=='us' else '零战截击机'
  else:labels[spawn['id']]=names[model]+(' 长机' if spawn['id']=='bomber' else ' 僚机')
  d['spawns'].append(spawn)
 d['groups']=[{'id':'strike','faction_id':case['goals'][0]['faction_id'],'member_ids':case['goals'][0]['unit_ids']}]
 labels['strike']=names[model]+'轰炸编组'
 d['fleet_overrides']={'commanders':{'jp':{'patrol_center_m':[0,0,-5000],'patrol_radius_m':700},'us':{'patrol_center_m':[-5300,0,-3880],'patrol_radius_m':1200}}}
 d['presentation']={'title':'海空交锋 · 轰炸与截击','subtitle':'在空初态 · 真实移动/防空 · 有限载荷','names':labels,'duration_s':1200,'minimum_duration_s':900,'disengaged_after_s':120}
 d['integration_scope']='Production motion, contacts, weapons and DM; Bomber goals only; FleetPlanner exclusively assigns fighters. No timed results or passive-target overrides.'
 put('data/scenarios/s14_'+key+'.json',d)
print('Generated four bombing and two interception scenarios; live target AA and movement enabled.')
