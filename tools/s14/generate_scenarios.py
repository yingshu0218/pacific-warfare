#!/usr/bin/env python3
"""Repeatable S14 scenario and independent SB2C flight admission data."""
import copy, json, math
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
def write(path, obj):
 p=ROOT/path;p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(obj,ensure_ascii=False,indent=2)+'\n')
def spawn(id, faction, p, model, yaw=0, speed=100):
 return {'id':id,'unit_definition_id':model,'faction_id':faction,'position_m':p,'rotation_rad':[0,yaw,0],
 'velocity_mps':[-math.sin(yaw)*speed,0,-math.cos(yaw)*speed],
 'module_data':{'aircraft_initial':{'withdrawal_center_m':[10000 if faction=='us' else -10000,1500,8500],'withdrawal_radius_m':650}}}
def main():
 base=json.loads((ROOT/'data/scenarios/island_harbor_defence.json').read_text())
 base['spawns']=[x for x in base['spawns'] if '_air_' not in x['id']]
 base['aircraft_tasks_script']='res://scripts/showcase/sb2c_showcase_tasks.gd'
 base['combat_overlay_path']='res://data/combat/s14_sb2c.json'
 base['presentation'].update(title='青岬群岛 · 全单位',subtitle='四舰 · 三型机 · 岸防 · 真实编队与立体飞行',minimum_duration_s=420,duration_s=900)
 names=base['presentation']['names']
 for i in range(4):
  offset=[-350*(i//2)+90*(i%2),120*(i%2)+300*(i//2),360*(i//2)+180*(i%2)]
  compact=[[0,0,0],[100,40,120],[-120,80,100],[-20,120,220]][i]
  base['spawns'].append(spawn('us_air_'+str(i+1),'us',[compact[0],1500+compact[1],3200+compact[2]],'us_f6f5_1944'))
  base['spawns'].append(spawn('jp_air_'+str(i+1),'jp',[-offset[0],1500+offset[1],-600-offset[2]],'jp_a6m5a_1944',math.pi))
 for i in range(2):
  id='us_pair_demo_'+str(i+1);names[id]='巡航双机 '+str(i+1)
  base['spawns'].append(spawn(id,'us',[-1500+70*i,1600+50*i,5000+110*i],'us_f6f5_1944',0,100))
  id='us_sb2c_'+str(i+1);names[id]='SB2C-4 '+str(i+1)+' · 受护航'
  base['spawns'].append(spawn(id,'us',[1300+90*i,1100+120*i,3200+180*i],'us_sb2c4_1944',0,80))
 base['groups'] += [{'id':'us_cruise_pair','faction_id':'us','member_ids':['us_pair_demo_1','us_pair_demo_2']},
 {'id':'us_strike','faction_id':'us','member_ids':['us_sb2c_1','us_sb2c_2']}]
 names.update(us_cruise_pair='巡航双机组',us_strike='SB2C 巡航双机组')
 # Every mode contains all 19 real units, including the same 3 ground deployments.
 modes=['guided','pair','four','maneuver','escort','fire']+['train_'+f+'_'+k for f in ['us','jp'] for k in ['bank_turn','climb_dive','axial_roll','roll_reversal','split_s']]
 for mode in modes:
  s=copy.deepcopy(base);s['id']='s14_'+mode;s['showcase']={'mode':mode}
  if mode=='maneuver':
   # A real tail-contact envelope. The controller chooses/executes the maneuver.
   for p in s['spawns']:
    if p['id']=='us_pair_demo_1':p.update(position_m=[0,2400,3000],velocity_mps=[0,0,-100],rotation_rad=[0,0,0])
    if p['id']=='us_pair_demo_2':p.update(position_m=[90,2520,3180],velocity_mps=[0,0,-100],rotation_rad=[0,0,0])
    if p['id']=='jp_air_1':p.update(position_m=[-60,2400,3450],velocity_mps=[0,0,-120],rotation_rad=[0,0,0])
    if p['id']=='jp_air_2':p.update(position_m=[-250,2520,3630],velocity_mps=[0,0,-120],rotation_rad=[0,0,0])
  if mode=='escort':
   for p in s['spawns']:
    if p['id'].startswith('us_air_'):
     i=int(p['id'][-1])-1;p.update(position_m=[1300-350*(i//2)+90*(i%2),1400+120*(i%2)+300*(i//2),3500+360*(i//2)+180*(i%2)])
    if p['id'].startswith('jp_air_'):
     i=int(p['id'][-1])-1;p.update(position_m=[1300-350*(i//2)+90*(i%2),1400+120*(i%2),-600-360*(i//2)-180*(i%2)])
  if mode != 'fire':
   for p in s['spawns']:
    if p['unit_definition_id'] in ['us_f6f5_1944','jp_a6m5a_1944','us_sb2c4_1944']:
     p['position_m'][2]+=6500
  if mode.startswith('train_'):
   faction=mode.split('_')[1];subject='us_pair_demo_1' if faction=='us' else 'jp_air_1'
   s['showcase'].update(subject_id=subject,maneuver=mode[len('train_'+faction+'_'):],direction=1)
   s['presentation']['names'][subject]=('F6F-5' if faction=='us' else 'A6M5a')+' 训练机'
   for i,p in enumerate(s['spawns']):
    if p['unit_definition_id'] not in ['us_f6f5_1944','jp_a6m5a_1944','us_sb2c4_1944']:continue
    if p['id']==subject:p.update(position_m=[0,2400,10500],velocity_mps=[0,0,-115],rotation_rad=[0,0,0])
    else:p.update(position_m=[(6000 if p['faction_id']=='us' else -6000)+250*(i%3),1500+180*(i%2),11500+400*(i%4)],velocity_mps=[0,0,-90],rotation_rad=[0,0,0])
  if mode=='escort':
   # Two real attackers enter the protection area; the other pair remains on
   # patrol. No projectile/health/performance overrides are used.
   for p in s['spawns']:
    if p['id'] in ['jp_air_3','jp_air_4']:p['position_m'][0]-=5000
  write(Path('data/scenarios')/('s14_'+mode+'.json'),s)
 definition={'schema_version':1,'id':'us_sb2c4_1944','display_name':'Curtiss SB2C-4 Helldiver','country_id':'us','domain':'aircraft',
 'service_entry_year':1944,'configuration_date':'1944–1945 subtype; no individual airframe fixed',
 'dimensions_m':[15.164,4.496,11.049],'model_scene':'res://scenes/units/aircraft/sb2c4_flight.tscn','weapon_definitions':[], 'mounts':[],
 'historical_fixed_armament':[], 'dedicated_aa_historical':[],'dedicated_aa_game':[],
 'source':{'status':'provisional','paths':['docs/showcase/deliveries/SB2C-admission.md','docs/references/bombers/sb2c/README.md','docs/showcase/S14-scene-layout.md'],
 'note':'Admitted r2 model; historical 2x20mm and flexible twin .30 are visual only, no combat mounts admitted. Clean navigation/escort ward, no bombing/rear gunner. Height estimate from family model.'}}
 write('data/units/us_sb2c4_1944.json',definition)
 perf=json.loads((ROOT/'data/aircraft/performance.json').read_text())
 perf['us_sb2c4_1944']={'role':'strike_navigation_only','cruise_mps':80.0,'combat_mps':100.0,'max_level_mps':131.88,'sea_level_max_mps':118.0,
 'optimum_altitude_m':5100.0,'ceiling_m':8870.0,'climb_mps':9.14,'sink_mps':25.0,'stall_mps':42.0,'max_bank_deg':40.0,
 'roll_rate_degps':32.0,'pitch_rate_degps':6.0,'acceleration_mps2':2.4,'drag_mps2':2.4,'turn_drag_mps2':0.65,
 'fuel_capacity_kg':850.0,'cruise_burn_kgps':0.10,'full_burn_kgps':0.24,'reserve_s':480.0,'reference_mass_kg':6500.0,
 'source':'Independent clean-flight operating approximation. Reference envelope 295mph class/29100ft. Mission cruise80m/s, mass6500kg, fuel850kg, climb9.14m/s, sea-level118m/s, stall/control/burn/drag values provisional estimates, not a digitized SB2C-4 handbook or historic maximum maneuver claims. No bomb load; not F6F data. Reference: NHHC DANAS vol1 appendices, existing SB2C reference card.',
 'spatial':{'operating_load_g':3.5,'minimum_load_g':-0.25,'load_slew_gps':4.0,'combat_bank_deg':50.0,'guidance_gain':0.55,'density_scale_m':8500.0,
 'recovery_floor_m':220.0,'clearance_m':100.0,'dive_speed_factor':1.15,'max_attack_pitch_deg':30.0,'cover_height_m':180.0,'support_height_m':250.0,
 'zoom_energy_horizon_s':5.0,'stall_control_margin':1.12,'roll_acceleration_degps2':65.0,'wing_span_m':15.164,'oswald_efficiency':0.8,
 'source':'SB2C clean navigation operating estimates; no attack/rear gunner or DM01 detachable parts. Same force-integrating production controller, own profile.'}}
 write('data/aircraft/performance.json',perf)
 profile={'structure':110,'sensor_height_m':0,'visual_m':8000,'radar_ship_m':0,'radar_aircraft_m':0,'part_durability':65,'weapon_durability':10,
 'fire_loss_per_s':3,'fire_decay_per_s':0.004,'flood_loss_per_s':0,'loss_duration_s':30,
 'boxes':[{'part':'engine','center_m':[0,0,-3.6],'half_extents_m':[0.9,0.9,1.2],'armor_mm':1},
 {'part':'structure','center_m':[0,0,0],'half_extents_m':[0.8,0.8,3.0],'armor_mm':1},
 {'part':'control','center_m':[0,0.2,4.1],'half_extents_m':[2.9,0.35,1.2],'armor_mm':0},
 {'part':'structure','center_m':[-4,0,0],'half_extents_m':[3.5,0.15,1.4],'armor_mm':0},
 {'part':'structure','center_m':[4,0,0],'half_extents_m':[3.5,0.15,1.4],'armor_mm':0}],
 'damage_effects':{'fire_anchor_m':[0,0.6,-3.6],'smoke_anchor_m':[0,0.8,-3.6]},
 'source_note':'S14 coarse approximate collision/survivability profile. No precut DM01 for this model; uses existing generic damage path.'}
 write('data/combat/s14_sb2c.json',{'unit_profiles':{'us_sb2c4_1944':profile}})
if __name__=='__main__': main()
