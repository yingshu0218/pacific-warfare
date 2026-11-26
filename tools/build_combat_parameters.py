"""Rebuild explicit S05 parameters only. Does not edit any unit/model/ammo files."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
def read(path):
    return json.loads((ROOT / path).read_text())
def box(part, center, half, armor=0):
    return dict(part=part, center_m=center, half_extents_m=half, armor_mm=armor)
def ship(structure, sensor_height, visual, surface_radar, air_radar, armor):
    return dict(structure=structure, sensor_height_m=sensor_height, visual_m=visual,
                radar_ship_m=surface_radar, radar_aircraft_m=air_radar,
                part_durability=structure * .22, weapon_durability=30,
                weapon_armor_mm=armor * .1, fire_loss_per_s=1.2,
                flood_loss_per_s=4., fire_decay_per_s=.001,
                flood_growth_per_s=.0003, sink_mps=.4, loss_duration_s=45., boxes=[])
units = {}
yamato = ship(6000, 30, 20000, 25000, 40000, 410)
yamato['main_weapon_armor_mm']=650
hull_data=read('data/hull_stations.json')
stations=hull_data['stations']
def yamato_deck(z):
    levels=hull_data['deck_sheer_stations_m']
    for (a,y),(b,y2) in zip(levels,levels[1:]):
        if a<=z<=b:return y+(y2-y)*(z-a)/(b-a)
    return levels[0][1] if z<levels[0][0] else levels[-1][1]
for (z,w),(z2,w2) in zip(stations,stations[1:]):
    mid=(z+z2)/2
    part='engine' if -15 < mid < 65 else 'steering' if mid > 100 else 'structure'
    top=yamato_deck(mid);bottom=-10.4
    yamato['boxes'].append(box(part,[0,(top+bottom)/2,mid],[max(.2,(w+w2)*.45),(top-bottom)/2,(z2-z)/2],410))
# Use the actual S02 section offsets; a coarse box must not move a tower over a gun.
for path in ['data/bridge_geometry.json','data/aft_bridge_geometry.json']:
    data=read(path);levels=data['sections'];offset=data['local_z_offset']
    for low,high in zip(levels,levels[1:]):
        front=min(low['front_z'],high['front_z'])+offset
        rear=max(low['rear_z'],high['rear_z'])+offset
        yamato['boxes'].append(box('control',[0,(low['y']+high['y'])/2,(front+rear)/2],[max(low['half_width'],high['half_width']),(high['y']-low['y'])/2,(rear-front)/2],20))
for z,z2,w in [(-14,-1,5.5),(-1,5,12),(5,29,14.1),(29,37,11.3),(37,46,6),(46,53.2,3.5)]:
    yamato['boxes'].append(box('structure',[0,9,(z+z2)/2],[w,2.5,(z2-z)/2],25))
yamato['boxes'] += [box('structure',[0,10.8,-5.5],[5.1,2.5,8.5],25),box('structure',[0,21.05,22.5],[4.1,9.55,7.9],20)]
for side in [-1,1]:yamato['boxes'].append(box('structure',[side*7.8,13.475,20.5],[2.5,2.025,15.5],20))
units['jp_yamato_1944_04']=yamato
iowa=ship(5400,32,20000,32000,50000,307)
iowa['main_weapon_armor_mm']=495
iowa['mount_limits']={'main_02':{'minimum_elevation_deg':0}}
# Coarse sections from the exact S02 model's data-only control table.
import ast
import re
source=(ROOT/'iowa/scripts/iowa_ship.gd').read_text()
raw=ast.literal_eval(re.search(r'var raw: Array\[Array\] = (\[.*?\n\t\])',source,re.S).group(1))
for one,two in zip(raw,raw[1:]):
    z,w,top,bottom=one;z2,w2,top2,bottom2=two
    mid=(z+z2)/2;low=min(bottom,bottom2);high=max(top,top2)
    iowa['boxes'].append(box('engine' if -23<mid<75 else 'steering' if mid>113 else 'structure',[0,(low+high)/2,mid],[max(.2,(w+w2)*.45),(high-low)/2,(z2-z)/2],307))
for z,z2,w in [(-26.5,-15,4.5),(-15,1,9.2),(1,29.7,8.8),(29.7,46,8.9),(46,54,4.)]:
    iowa['boxes'].append(box('structure',[0,7.85,(z+z2)/2],[w,2.65,(z2-z)/2],25))
iowa['boxes'] += [box('control',[0,12.3,-12],[5.3,1.8,13.5],25),box('control',[0,15.6,-16],[3.2,2.5,3.2],495),box('control',[0,18.95,-9.2],[4,1.15,3.7],20),box('control',[0,23.55,-3.6],[3.8,9.45,5.3],20),box('structure',[0,15.5,5.3],[4.75,10.7,6.5],20),box('structure',[0,16.6,31],[4.7,11.4,6.7],20),box('control',[0,16.6,49.8],[3.8,6.1,6.25],20)]
units['us_iowa_bb61_1944_12_28']=iowa
for name,dirname in [('us_fletcher_dd445_1942_07_18','fletcher_dd445'),('jp_yukikaze_1942_06','yukikaze')]:
    assembly=read(f'data/ships/{dirname}/assembly.json')
    profile=ship(850 if dirname=='fletcher_dd445' else 780,16,16000,22000 if dirname=='fletcher_dd445' else 0,40000 if dirname=='fletcher_dd445' else 0,12)
    for one,two in zip(assembly['hull']['stations'],assembly['hull']['stations'][1:]):
        z,w,top,bottom=one[:4];z2,w2,top2,bottom2=two[:4]
        if z2-z<.1: continue
        mid=(z+z2)/2;low=min(bottom,bottom2);high=max(top,top2)
        profile['boxes'].append(box('engine' if -10<mid<18 else 'steering' if mid>44 else 'structure',[0,(low+high)/2,mid],[max(.1,(w+w2)*.45),(high-low)/2,(z2-z)/2],12))
    for group,structures in assembly['structures'].items():
        for s in structures:
            pos=s['position_m'].copy();pos[1]+=s['height_m']/2
            profile['boxes'].append(box('control' if group=='bridge' else 'structure',pos,[s['width_m']/2,s['height_m']/2,s['length_m']/2],8))
    units[name]=profile
units['us_f6f5_1944']=dict(structure=90,sensor_height_m=2.3,visual_m=8000,radar_ship_m=0,radar_aircraft_m=0,part_durability=55,weapon_durability=10,fire_loss_per_s=3.,fire_decay_per_s=.004,flood_loss_per_s=0,loss_duration_s=30.,boxes=[box('engine',[0,2.3,-2.9],[.75,.8,1.4],3),box('structure',[0,2.25,0],[.65,.7,2],1),box('control',[0,2.6,3.8],[2.5,.25,1.1],0),box('structure',[-3.1,2.13,-.1],[3.1,.16,1.2],0),box('structure',[3.1,2.13,-.1],[3.1,.16,1.2],0)])
# S04 frozen flight origins: subtract raw display height, preserve x/z stations.
for item in units['us_f6f5_1944']['boxes']:
    item['center_m'][1]-=2.30
units['us_f6f5_1944']['sensor_height_m']=0.
units['jp_a6m5a_1944']=dict(structure=65,sensor_height_m=0.,visual_m=8000,radar_ship_m=0,radar_aircraft_m=0,part_durability=35,weapon_durability=8,fire_loss_per_s=4.,fire_decay_per_s=.002,flood_loss_per_s=0,loss_duration_s=30.,boxes=[box('engine',[0,-.05,-2.8],[.67,.55,1.35],1),box('structure',[0,0,0],[.55,.6,2.],0),box('control',[0,.3,3.7],[2.,.25,.85],0),box('structure',[-2.8,.02,-.1],[2.7,.12,1.45],0),box('structure',[2.8,.02,-.1],[2.7,.12,1.45],0)])
weapons={}
def gun(id,cycle,rng,disp,domains,train=None,elev=None,stock=None,dp=False):
    p=dict(cycle_s=cycle,range_m=rng,dispersion_rad=disp,domains=domains,dual_purpose=dp,aim_tolerance_rad=.0025,fuze_error_s=.18,reload_track_interval_s=.1)
    if train is not None:p['train_rate_degps']=train
    if elev is not None:p['elevation_rate_degps']=elev
    if stock is not None:p['initial_rounds_per_barrel']=stock
    weapons[id]=p
surface=['ship'];aa=['aircraft'];both=surface+aa
gun('jp_type94_460mm_triple',35,35000,.0018,surface,2,8,100)
gun('jp_type3_155mm_triple',12,18000,.002,surface,5,10,150)
gun('jp_type89_127mm_twin',7.5,9000,.004,both,6,12,300,True)
gun('jp_type96_25mm_triple',.5,2500,.009,aa,18,12,2000)
gun('jp_type96_25mm_single',.5,2500,.009,aa,18,12,2000)
gun('jp_type93_13mm_twin',.24,1200,.01,aa,25,20,2500)
gun('us_16in50_mk7_triple',30,35000,.0016,surface,4,12,130)
gun('us_5in38_mk28_twin',4,10000,.003,both,25,15,450,True)
weapons['us_5in38_mk28_twin']['proxy_half_extents_m']=[2.25,1.4,2.5]
gun('us_bofors_40mm_quad',.70588235294,3500,.006,aa,25,24,2000)
gun('us_oerlikon_20mm_single',.2,1800,.009,aa,60,45,1500)
gun('us_an_m2_127mm_single',.075,1000,.006,both,0,0,400)
weapons['us_an_m2_127mm_single']['aim_tolerance_rad']=.018
gun('jp_type97_77mm_single',.1,800,.008,both,0,0,500)
gun('jp_type99_2_model4_20mm_single',.12,1000,.007,both,0,0,125)
weapons['jp_type97_77mm_single']['aim_tolerance_rad']=.018
weapons['jp_type99_2_model4_20mm_single']['aim_tolerance_rad']=.018
# S03 base generator remains provisional; authoritative S05 overlays stay here.
gun('s03_us_5in38_mk30_single',4,10000,.003,both,25,15,300,True)
weapons['s03_us_5in38_mk30_single']['ammo_id']='us_127mm_5in38_shell'
gun('s03_us_11in_mk2_quad',.6,2500,.008,aa,24,24,800)
gun('s03_us_oerlikon_20mm_single',.2,1800,.009,aa,60,45,1500)
gun('s03_jp_127mm_type3_c_twin',7,15000,.003,surface,6,12,150)
gun('s03_jp_type96_25mm_twin',.5,2500,.009,aa,18,12,2000)
ammo={}
for p in sorted((ROOT/'data/ammunition').glob('*.json')):
    d=json.loads(p.read_text());c=d['caliber_m'];kind='ap' if c>.3 or '155mm' in d['id'] else 'he' if c>=.02 else 'ball'
    ammo[d['id']]=dict(kind=kind,damage_scale=.07 if c>.3 else .045 if c>.1 else .035,burst_radius_m=24 if .12<c<.13 and 'type1_' not in d['id'] else 0)
# Reviewed ammunition overlays: catalog/model data and their generators remain untouched.
corrections={
 'jp_127mm_type89_shell':(.127,23.45,720.),
 'jp_13mm_type93_ball':(.0132,.0518,805.),
 'us_20mm_oerlikon_shell':(.02,.123,835.),
 'us_127mm_m2_ball':(.0127,.0458,884.),
 's03_jp_25mm_type96_he':(.025,.24,900.),
}
for id,(caliber,mass,speed) in corrections.items():
    ammo[id].update(caliber_m=caliber,projectile_mass_kg=mass,muzzle_speed_mps=speed)
ammo['s03_us_127mm_mk32_common']['burst_radius_m']=0
ammo['s03_jp_127mm_type1_common']['burst_radius_m']=0
# Presentation anchors on exposed decks / engine skin in the frozen model origins.
# They represent a single aggregate fire state, not a measured internal hit location.
anchors={
 'jp_yamato_1944_04':([12.,9.,60.],[12.,10.,60.]),
 'us_iowa_bb61_1944_12_28':([10.,6.1,60.],[10.,7.,60.]),
 'us_fletcher_dd445_1942_07_18':([3.9,4.25,17.],[3.9,5.,17.]),
 'jp_yukikaze_1942_06':([3.6,3.8,17.],[3.6,4.6,17.]),
 'us_f6f5_1944':([0.,.65,-2.8],[0.,.8,-2.8]),
 'jp_a6m5a_1944':([0.,.45,-2.5],[0.,.6,-2.5]),
}
for id,(fire,smoke) in anchors.items():
    units[id]['damage_effects']=dict(fire_anchor_m=fire,smoke_anchor_m=smoke)
output=dict(schema_version=1,contacts=dict(scan_interval_s=.5,fresh_s=3.,expiry_s=20.,uncertainty_mps=8.,target_cooldown_s=2.),unit_profiles=units,weapon_profiles=weapons,ammo_profiles=ammo,environment=dict(sea_level_m=0,friendly_fire=False,solids=[]),limits=dict(projectiles=8192,tracer_every=3,wreck_lifetime_s=30.),source=dict(status='historical_ballistics_with_explicit_game_approximations',paths=['docs/references/combat/s05-sources.md'],note='Damage, sensor envelopes, effective fire cadence, scatter, collision proxies, stocks and limits are explicit game parameters. No faction balancing multiplier.'))
(ROOT/'data/combat/showcase.json').write_text(json.dumps(output,ensure_ascii=False,indent=2)+'\n')
print('Wrote data/combat/showcase.json:',len(units),'unit profiles,',len(weapons),'weapon profiles,',len(ammo),'ammunition profiles')
