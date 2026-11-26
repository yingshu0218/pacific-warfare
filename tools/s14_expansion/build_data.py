#!/usr/bin/env python3
"""Convert actual admitted model sockets to candidate production definitions."""
from pathlib import Path
from collections import Counter
import copy,json,math
ROOT=Path(__file__).resolve().parents[2]; CAND=ROOT/'candidates/s14-expansion'; OUT=CAND/'overrides'
def read(p):return json.loads(p.read_text())
def put(n,d):p=OUT/n;p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
interfaces=read(CAND/'stage/data/expansion/carrier_model_interfaces.json')
put('data/expansion/carrier_model_interfaces.json',interfaces)
iowa=read(ROOT/'data/units/us_iowa_bb61_1944_12_28.json');yamato=read(ROOT/'data/units/jp_yamato_1944_04.json')
known={w['id']:w for u in [iowa,yamato] for w in u['weapon_definitions']}
for name in read(CAND/'admitted-inputs.json'):
 if Path(name).parent==Path('data/units'):
  for weapon in read(ROOT/name).get('weapon_definitions',[]):known[weapon['id']]=weapon
combat=read(ROOT/'data/combat/showcase.json');overlay=read(ROOT/'data/combat/s14_sb2c.json')
overlay.setdefault('weapon_profiles',{});overlay.setdefault('ammo_profiles',{})
mapping={'cv01_5in38_mk32_twin':('us_5in38_mk28_twin',2),'cv01_5in38_mk24_single':('us_5in38_mk28_twin',1),'us_bofors_40mm_quad':('us_bofors_40mm_quad',4),'us_oerlikon_20mm_single':('us_oerlikon_20mm_single',1),'cv02_type89_127mm_twin':('jp_type89_127mm_twin',2),'cv02_type96_25mm_triple':('jp_type96_25mm_triple',3)}
for ident,base,width,height,length,country,year,date in [
 ('us_essex_cv9_1944_04_15','essex_cv9_1944_04_15',44.98,40.5,265.7856,'us',1942,'1944-04-15'),
 ('jp_shokaku_1941_08_23','shokaku_1941_08_23',38.,40.87,257.5,'jp',1941,'1941-08-23')]:
 mounts=[];weapons={}
 for raw in interfaces[ident]['mounts']:
  m=copy.deepcopy(raw);wid=m['weapon_definition_id']
  # CV01 reuses the exact original light-AA interface IDs.
  if wid not in mapping:
   if 'bofors'in wid:mapping[wid]=('us_bofors_40mm_quad',4)
   elif 'oerlikon'in wid:mapping[wid]=('us_oerlikon_20mm_single',1)
  original,barrels=(wid,int(known[wid]['barrel_count'])) if wid in known else mapping[wid]
  w=copy.deepcopy(known[original]);w['id']=wid;w['barrel_count']=barrels
  if wid!=original:
   w['train_limits_deg']=[-180,180];w['elevation_limits_deg']=[-15,85] if country=='us' else [-8,90]
   w['source']={'status':'provisional','paths':[f'naval/{base}/data/assembly.json','data/combat/showcase.json'],'note':'Correct admitted mount type/barrels; same gun/ammo ballistics as existing127mm gun. Traverse/rate/cycle/stock are declared game approximations inherited from existing profile, not CV-specific measured trials.'}
   overlay['weapon_profiles'][wid]=copy.deepcopy(combat['weapon_profiles'][original])
  m['role']='main' if m['role'] in ['main_dual_purpose','dual_purpose'] else 'dedicated_aa'
  m['source']={'status':'provisional','basis':'Actual admitted pure model mount_sockets export','note':str(m.pop('source_status','model source-matched approximate station'))}
  mounts.append(m);weapons[wid]=w
 fixed=Counter(m['weapon_definition_id'] for m in mounts if m['role']=='main');aa=Counter(m['weapon_definition_id'] for m in mounts if m['role']=='dedicated_aa')
 def arm(c):return [{'weapon_definition_id':k,'mount_count':v,'barrels_per_mount':weapons[k]['barrel_count']}for k,v in c.items()]
 unit={'schema_version':1,'id':ident,'display_name':'埃塞克斯 CV-9' if country=='us' else '翔鹤','country_id':country,'domain':'ship','service_entry_year':year,'configuration_date':date,'dimensions_m':[width,height,length],'model_scene':f'res://scenes/ships/{ident}.tscn','mounts':mounts,'weapon_definitions':list(weapons.values()),'historical_fixed_armament':arm(fixed),'dedicated_aa_game':arm(aa),'dedicated_aa_historical':([{'description':'40mm四联; exact dated count uncertainty retained from CV01','mount_count':8,'barrels_per_mount':4},{'description':'20mm单装; dated historical estimate retained from CV01','mount_count':46,'barrels_per_mount':1}]if country=='us'else[{'description':'九六式25mm三联','mount_count':12,'barrels_per_mount':3}]),'source':{'status':'provisional','paths':[f'docs/showcase/acceptance/{"CV01"if country=="us"else"CV02"}-review.md',f'naval/{base}/data/assembly.json'],'note':'Admitted geometry and fixed armament. Live integration candidate; AA count exactly matches model. Coarse protection/damage/firing allocations explicitly gameplay estimates, not historical armor simulation.'}}
 # Use the admitted historical description verbatim rather than invent dated AA.
 assembly=read(ROOT/f'naval/{base}/data/assembly.json')
 if country=='us':unit['dedicated_aa_historical']=[{'description':'CV01 historical declaration: '+json.dumps(assembly['historical_armament'],ensure_ascii=False),'mount_count':0,'barrels_per_mount':1}]
 put(f'data/units/{ident}.json',unit)
 tscn=f'''[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://scripts/showcase/expansion/carrier_ship_adapter.gd" id="1"]\n[node name="Carrier" type="Node3D"]\nscript = ExtResource("1")\nmodel_scene = "res://naval/{base}/{"essex"if country=="us"else"shokaku"}.tscn"\n'''
 p=OUT/f'scenes/ships/{ident}.tscn';p.parent.mkdir(parents=True,exist_ok=True);p.write_text(tscn)
 # Same coarse collision proxy envelope declared by the model; split the hull
 # fore/mid/aft so propulsion and steering can actually be damaged.
 template=copy.deepcopy(combat['unit_profiles']['us_fletcher_dd445_1942_07_18'])
 template.update({'structure':2200 if country=='us'else 2050,'part_durability':480,'weapon_durability':45,'sensor_height_m':25 if country=='us'else 20,'visual_m':18000,'radar_ship_m':25000 if country=='us'else 0,'radar_aircraft_m':45000 if country=='us'else 0,'boxes':[]})
 for proxy in assembly['collision_proxies']:
  cen=proxy['center_m'];size=proxy['size_m']
  if proxy['id']=='hull':
   for part,z,frac in [('structure',-.33,1/3),('engine',0,1/3),('steering',.33,1/3)]:template['boxes'].append({'part':part,'center_m':[cen[0],cen[1],cen[2]+size[2]*z],'half_extents_m':[size[0]/2,size[1]/2,size[2]*frac/2],'armor_mm':10})
  else:template['boxes'].append({'part':'control' if proxy['id']=='island' else 'structure','center_m':cen,'half_extents_m':[v/2 for v in size],'armor_mm':10})
 template['damage_effects']={'fire_anchor_m':[5,15,10],'smoke_anchor_m':[5,17,10]}
 template['source_note']='Declared coarse model AABBs,10mm equivalent structural resistance and abstract hit points. Not a historical belt/deck armor map; no faction balancing.'
 overlay['unit_profiles'][ident]=template
put('data/combat/s14_expansion.json',overlay)
fleet={}
for ident,speed in [('us_essex_cv9_1944_04_15',33.0),('jp_shokaku_1941_08_23',34.2)]:
 fleet[ident]={'historical_max_knots':speed,'cruise_mps':15.,'acceleration_mps2':.08,'braking_mps2':.12,'coast_drag_mps2':.02,'turn_radius_m':950.,'yaw_acceleration_degps2':.015,'engagement_range_m':10000.,'flag_rank':80}
put('data/expansion/fleet_profiles.json',fleet)
for mode in ['harbor','carrier_gunnery','carrier_single','carrier_pair','carrier_partial','inspect_d4y2','inspect_g4m1','inspect_b25j']:
 d=read(ROOT/'data/scenarios/s14_guided.json');d['id']='s14_expansion_'+mode;d['showcase']['mode']=mode
 d['environment']['terrain_path']='res://data/maps/island_harbor_expanded.json';d['environment']['view_script']='res://scripts/map02/expanded_map_view.gd'
 d['ground_deployments'][0]['site_id']='map02_civil_coast_01';d['ground_deployments'][1]['site_id']='map02_town_aa_01';d['ground_deployments'][2]['site_id']='map02_main_ridge_aa'
 d['carrier_operations']={'carrier_id':'us_cv','stage':'zero_environment_wind_complete_f6f_wave_only'};d['fleet_profiles_path']='res://data/expansion/fleet_profiles.json';d['combat_overlay_path']='res://data/combat/s14_expansion.json'
 d['presentation'].update({'title':'青岬港湾 · 航母扩展候选','subtitle':'MAP02 · 两航母 · F6F真实作业 · 新机静态安装','duration_s':3600,'minimum_duration_s':3600})
 gun=mode=='carrier_gunnery'
 training=mode in ['carrier_single','carrier_pair','carrier_partial']
 for ident,faction,definition,x in [('us_cv','us','us_essex_cv9_1944_04_15',3500 if gun else 10500),('jp_cv','jp','jp_shokaku_1941_08_23',-3500 if gun else-9500)]:
  east=training and ident=='us_cv'
  d['spawns'].append({'id':ident,'unit_definition_id':definition,'faction_id':faction,'position_m':[x,0,9500],'rotation_rad':[0,-math.pi/2 if east else 0,0],'velocity_mps':[15,0,0] if east else [0,0,-15]})
 d['presentation']['names'].update({'us_cv':'埃塞克斯 CV-9 · 1944-04-15','jp_cv':'翔鹤 · 1941-08-23'})
 count=1 if mode=='carrier_single'else 2
 for i in range(count):
  ident=f'us_deck_{i+1}';origin=interfaces['f6f_parked']
  d['spawns'].append({'id':ident,'unit_definition_id':'us_f6f5_1944','faction_id':'us','position_m':[10500-(75+i*30),15.85+origin['position_m'][1],9497] if training else [(3500 if gun else 10500)-3,15.85+origin['position_m'][1],9575+i*30],'rotation_rad':[origin['rotation_rad'][0],-math.pi/2,0] if training else origin['rotation_rad'],'velocity_mps':[15,0,0] if training else [0,0,-15],'module_data':{'carrier_initial':{'carrier_id':'us_cv'}}})
  d['presentation']['names'][ident]=f'甲板 F6F {i+1}号'
 if training:d['showcase']['training_area_note']='Eastbound open-sea deck drill, relative patrol area. All combat/AA/damage remain active; northbound r3 enemy127mm loss is archived.'
 put('data/scenarios/'+d['id']+'.json',d)
print(json.dumps({'carriers':2,'mounts':[len(interfaces[k]['mounts'])for k in ['us_essex_cv9_1944_04_15','jp_shokaku_1941_08_23']],'expansion_modes':8}))
