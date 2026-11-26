#!/usr/bin/env python3
"""CV01-only data/scenes. Never writes registered unit/weapon/ammunition directories."""
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
BASE=ROOT/'naval/essex_cv9_1944_04_15'
RES='res://naval/essex_cv9_1944_04_15/'
def write(p,value):
 p=BASE/p;p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n' if not isinstance(value,str) else value)
def rect(x0,x1,z0,z1):return [[x0,z0],[x1,z0],[x1,z1],[x0,z1]]
# Source P03 provides class plan ratios; E01-E05 resolve CV9-specific silhouette.
boundary=[[-14.4,-131.3688],[10.7,-131.3688],[13.7092,-121],[13.7092,122.0],[10.7,131.3688],[-15.0,131.3688],[-16.7,126],[-16.7,91],[-19.2092,85],[-19.2092,-70],[-18.1,-81],[-14.4,-91]]
deck=dict(schema_version='0.1',ship_id='us_essex_cv9_1944_04_15',configuration_date='1944-04-15',
 source_status='CV9 photos E01-E05 plus CV17 1946 class plans P01-P06; metric envelope from NHC; positions/height photo and plan-ratio reconstruction, not shipyard surveyed CV9 coordinates',
 axes=dict(right='+X',up='+Y',forward='-Z',origin='overall-length midpoint at full-load design waterline',scale=[1,1,1]),
 flight_deck=dict(height_m=15.85,thickness_m=.38,boundary_xz_m=boundary,nominal_length_m=262.7376,nominal_max_width_m=32.9184),
 obstacles=[dict(id='island_and_twin_battery',polygon_xz_m=rect(11.7,22,-56,39),bottom_m=15.85,top_m=40.5,host_id='island'),dict(id='port_forward_battery_edge',polygon_xz_m=rect(-22.0,-18.1,-110,-74),bottom_m=13.55,top_m=17.5,host_id='port_forward_sponson'),dict(id='port_aft_battery_edge',polygon_xz_m=rect(-22.0,-16.7,76,116),bottom_m=13.55,top_m=17.5,host_id='port_aft_sponson')],
 reference_lines=[dict(id='takeoff_axial',kind='takeoff',points_m=[[-3,15.85,-40],[-3,15.85,-130]],half_width_m=8.0,source_status='axial propeller-carrier geometry reference; OPS01 must choose run length for aircraft/wind'),dict(id='landing_axial',kind='landing',points_m=[[-3,15.85,129],[-3,15.85,90],[-3,15.85,15],[-3,15.85,-40]],half_width_m=9.0,source_status='straight axial landing reference; not angled or simultaneous operations')],
 zones=[dict(id='forward_park',kind='parking',polygon_xz_m=rect(-12,8,-78,-42),height_m=15.85,requires_folded_wings=False),dict(id='aft_park',kind='parking',polygon_xz_m=rect(-12,8,64,112),height_m=15.85,requires_folded_wings=False),dict(id='port_fold',kind='folding',polygon_xz_m=rect(-17,-7,-65,-40),height_m=15.85,requires_folded_wings=True),dict(id='bow_hold',kind='holding',polygon_xz_m=rect(-11,5,-122,-105),height_m=15.85,requires_folded_wings=False),dict(id='landing_exit',kind='exit',polygon_xz_m=rect(-13,6,-40,-2),height_m=15.85,requires_folded_wings=False)],
 elevators=[dict(id='elevator_forward',center_xz_m=[0,-89.0],size_xz_m=[13.4874,14.7066],upper_height_m=15.85,lower_height_m=7.926,translation_axis=[0,1,0],node_path='FlightDeck/Elevators/elevator_forward',opening='inboard',corner_radius_m=0.0),dict(id='elevator_aft',center_xz_m=[0,45.0],size_xz_m=[13.4874,14.7066],upper_height_m=15.85,lower_height_m=7.926,translation_axis=[0,1,0],node_path='FlightDeck/Elevators/elevator_aft',opening='inboard',corner_radius_m=0.0),dict(id='elevator_port',center_xz_m=[-19.6,-20],size_xz_m=[10.3632,18.288],upper_height_m=15.85,lower_height_m=7.926,translation_axis=[0,1,0],node_path='FlightDeck/Elevators/elevator_port',opening='deck_edge',corner_radius_m=0.0)],
 paths=[dict(id='forward_hold_to_run',kind='holding',points_m=[[-3,15.85,-60],[-3,15.85,-105]],half_width_m=7.8),dict(id='landing_exit_reference',kind='exit',points_m=[[-3,15.85,10],[-3,15.85,-7],[-3,15.85,-40]],half_width_m=7.8)],
 arresting_wires=[dict(id='wire_%02d'%i,points_m=[[-14,15.87,z],[10,15.87,z]]) for i,z in enumerate([117,111,105,99,93,87,81,75,69,63,57,51],1)],
 barriers=[dict(id='barrier_1',points_m=[[-15,15.88,28],[10,15.88,28]]),dict(id='barrier_2',points_m=[[-15,15.88,23],[10,15.88,23]])],
 catapults=[dict(id='hydraulic_port',points_m=[[-10,15.87,-128],[-10,15.87,-96]],source_status='two visible tracks for April refit; hydraulic type/performance not approved here'),dict(id='hydraulic_starboard',points_m=[[9,15.87,-128],[9,15.87,-96]],source_status='two visible tracks for April refit; no launch behaviour')])
write(Path('data/deck.json'),deck)
mounts=[]
def station(id,kind,pos,yaw,host,radius,source,foundation=.12):
 count={'mk32':2,'mk24':1,'bofors':4,'oerlikon':1}[kind]
 mounts.append(dict(id=id,kind=kind,position_m=pos,base_yaw_deg=yaw,host_id=host,interface_id={'mk32':'cv01_5in38_mk32_twin','mk24':'cv01_5in38_mk24_single','bofors':'us_bofors_40mm_quad','oerlikon':'s03_us_oerlikon_20mm_single'}[kind],role='main_dual_purpose' if kind in ['mk32','mk24'] else 'dedicated_aa',barrel_count=count,foundation_height_m=foundation,foundation_radius_m=radius,source_ids=source,placement_status='photo and class-plan ratio reconstruction; longitude approx +/-1.5m, elevation +/-0.5m'))
for id,z,y,yaw in [('51',-50.5,15.85,0),('53',-38.0,18.08,0),('55',22.0,18.08,180),('57',34.5,15.85,180)]:station('dp_'+id,'mk32',[16.4,y,z],yaw,'stbd_'+id,2.55,['E04','E05','P02','P03'])
for id,z in [('52',-104),('54',-92),('56',94),('58',106)]:station('dp_'+id,'mk24',[-20.35,13.55,z],90,'port_forward_sponson' if z<0 else 'port_aft_sponson',1.15,['E01','E03','P05'])
for id,pos,yaw,host in [('bow',[0,10.2,-124],0,'bow_bofors'),('stern',[-3.0,9.1,124],180,'stern_bofors'),('port_fore',[-20.5,13.55,-79],90,'port_forward_sponson'),('port_aft',[-20.5,13.55,81],90,'port_aft_sponson'),('island_aft',[16.4,22.0,11.3],180,'island_aft_bofors')]:station('aa40_'+id,'bofors',pos,yaw,host,1.0,['E01','E02','E04'],0)
for i,(x,z) in enumerate([(-14,-119),(11,-119),(-18,-61),(-18,-47),(-18,1),(-18,18),(-16,64),(-16,119),(12,119),(14,77),(14,93),(14,-70)]):
 station('aa20_%02d'%(i+1),'oerlikon',[x,16.0,z],90 if x<0 else -90,'aa_gallery_%02d'%(i+1),.38,['E01','E02','E04'],0)
write(Path('data/assembly.json'),dict(id=deck['ship_id'],configuration_date='1944-04-15',model_scene=RES+'essex.tscn',length_overall_m=265.7856,waterline_length_m=249.936,hull_beam_m=28.3464,draft_m=8.6868,deck_path=RES+'data/deck.json',mounts=mounts,
 historical_armament=dict(main='4x2 Mk32 + 4x1 Mk24 5in/38, 12 barrels, fixed; no separate secondary battery',dedicated_aa='as-built 8x4 40mm + 46x1 20mm. April 1944 forward-island quad removed; exact post-refit 20mm total not confirmed from selected photographs'),
 game_armament=dict(main='same 4x2 + 4x1',dedicated_aa='5x4 40mm; 12x1 20mm, explicitly reduced dedicated-AA layout; not a full historical 20mm inventory'),
 collision_proxies=[dict(id='hull',part_id='hull',center_m=[0,1,0],size_m=[28.3,16,249]),dict(id='hangar',part_id='aviation',center_m=[0,12,0],size_m=[24,8,203]),dict(id='island',part_id='superstructure',center_m=[16.5,25,-12],size_m=[10,16,65])],
 runtime_registration='development only; not in DefinitionCatalog; shared simulation integration belongs to S14 extension owner'))
for name in ['hull','hangar','flight_deck','island','platforms','equipment']:
 write(Path('modules/'+name+'.tscn'),f'[gd_scene load_steps=2 format=3]\n\n[ext_resource type="Script" path="{RES}modules/{name}.gd" id="1"]\n\n[node name="{name.title().replace("_", "")}" type="Node3D"]\nscript = ExtResource("1")\n')
for name in ['mk32','mk24']:
 write(Path('weapons/'+name+'.tscn'),f'[gd_scene load_steps=2 format=3]\n\n[ext_resource type="Script" path="{RES}weapons/five_inch.gd" id="1"]\n\n[node name="{name.upper()}" type="Node3D"]\nscript = ExtResource("1")\nmount_kind = "{name}"\n')
write(Path('essex.tscn'),f'[gd_scene load_steps=2 format=3]\n\n[ext_resource type="Script" path="{RES}essex.gd" id="1"]\n\n[node name="USS_Essex_CV9_1944_04_15" type="Node3D"]\nscript = ExtResource("1")\n')
print('CV01 data and scenes generated:',len(mounts),'mounts, 3 elevators; no registered definitions written')
