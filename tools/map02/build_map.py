#!/usr/bin/env python3
"""Author MAP02 facilities and region contracts; delegates all runtime heights to TerrainQueries.
No edits to shared runtime or equipment catalogs. Regeneration is deterministic.
"""
import copy
import json
import math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
DATA=ROOT/'data/map02'

def write(path,data):
    p=ROOT/path;p.parent.mkdir(parents=True,exist_ok=True)
    p.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')

def part(id,position,size,color,shape='box',solid=True,quay=False):
    return dict(id=id,position_m=position,size_m=size,color=color,shape=shape,solid=solid,quay=quay)

def building(width,depth,height,roof,color,roof_color):
    return [part('wall',[0,0,0],[width,height,depth],color),part('roof',[0,height,0],[width+1.5,roof,depth+1.5],roof_color,'gable'),part('door',[0,.1,depth*.501],[width*.35,height*.62,.12],'465759',solid=False),part('windows',[0,height*.65,-depth*.501],[width*.65,1.4,.12],'566a6a',solid=False)]

def build_modules():
    m={}
    m['town_house']=dict(label='木石低层民居',parts=building(18,24,8,3,'bcb39a','885e4c'))
    m['town_shop']=dict(label='沿街商铺',parts=building(28,20,10,2.8,'c6bea4','696f65')+[part('awning',[0,7,13],[29,.6,7],'b59f76',solid=False),part('porch',[0,-.4,12],[29,.4,8],'8e9282')])
    m['public_hall']=dict(label='公共会馆/钟楼',parts=building(46,32,13,5,'c9c3a5','655d4d')+[part('tower',[0,0,0],[11,30,11],'b6b398'),part('cap',[0,30,0],[13,4,13],'6d5d4c','pyramid'),part('clock',[0,24,5.6],[4,4,.12],'e8e4cc',solid=False)])
    m['cargo_warehouse']=dict(label='民港货仓',parts=building(56,84,14,6,'aaa997','5d797b'))
    m['military_warehouse']=dict(label='军需仓库',parts=building(78,48,12,5,'8e9786','636e67'))
    m['repair_shed']=dict(label='军港维修棚',parts=building(92,112,24,10,'a4aaa0','626e70')+[part('bay_door',[0,.2,56.1],[70,21,.2],'34484c',solid=False),part('beam',[0,22,56.8],[91,2,2],'7b8479')])
    m['air_hangar']=dict(label='陆基机库',parts=building(76,62,18,8,'aab09e','626d68')+[part('hangar_door',[0,.2,31.1],[64,16,.2],'3a5158',solid=False)])
    m['barracks']=dict(label='军营/勤务房',parts=building(44,16,7,3,'9da18c','657466'))
    m['control_tower']=dict(label='港务/场站控制塔',parts=[part('base',[0,0,0],[12,4,12],'858f87'),part('shaft',[0,4,0],[7,17,7],'a6a98e'),part('cab',[0,21,0],[13,5,11],'596f72'),part('roof',[0,26,0],[15,1.5,13],'707c73')])
    m['fuel_tank']=dict(label='立式燃油罐',parts=[part('plinth',[0,-.6,0],[23,.6,23],'858a7c'),part('shell',[0,0,0],[18,16,18],'a2aaa1','cylinder'),part('top',[0,16,0],[18,2,18],'b6b9a7','cone'),part('top_hatch',[0,18,0],[2,.5,2],'687b78','cylinder',solid=False)])
    m['dock_crane']=dict(label='码头门式吊机',parts=[part('pad',[0,0,0],[20,.8,18],'8c948b')]+[part(f'leg_{i}',[x,.8,z],[2,25,2],'697f7a') for i,(x,z) in enumerate([(-7,-5),(7,-5),(-7,5),(7,5)])]+[part('top_frame',[0,25.8,0],[20,3,14],'637973'),part('boom',[13,28,0],[52,2.5,3],'788e83'),part('counterweight',[-16,25,0],[7,6,7],'667973'),part('cabin',[0,22,5],[5,4,5],'465e61'),part('hoist',[34,12,0],[.2,16,.2],'667c79')])
    m['pier_furniture']=dict(label='系缆柱/安全边线',parts=[part('bollard',[0,0,0],[1.3,1.4,1.3],'596b66','cylinder'),part('mark',[0,.01,0],[3,.03,3],'c8c6a6',solid=False)])
    return m

def main():
    base=json.loads((ROOT/'data/maps/island_harbor.json').read_text())
    source=copy.deepcopy(base);source['id']='island_harbor_expanded';source['label']='青岬群岛 · 港湾扩展'
    source['objects']=[];source['roads']=[];source['pads']=[];source['deployment_sites']=[];source['viewpoints']=[]
    source.pop('navigation',None)
    source['map02_schema_version']=1
    # Refine only expanded NE terrain, keeping the exact shoreline polygon.
    ne=source['islands'][1];outline=ne['outline_m'];ne['outline_m']=[q for a,b in zip(outline,outline[1:]+outline[:1]) for q in [a,[(a[j]+b[j])*.5 for j in range(3)]]];ne['rings']=32
    source['authorship']='Original fictional 1944-45 Pacific facilities and layout. Uses unchanged S09 terrain algorithm; no extracted game assets.'
    # Same islands; only the independent expanded version adds working terraces.
    pads=[('civil_town',[-5130,18,-3530],640,160),('civil_apron',[-4500,10,-3370],300,150),('civil_coast',[-3010,32,-3200],240,140),('main_ridge',[-5200,590,-4630],125,180),('naval_apron',[3250,12,-4770],760,220),('naval_oil',[4350,18,-5700],360,150),('naval_ridge',[2950,478,-5700],180,150),('naval_cape',[2150,42,-5050],240,140),('airfield',[6800,8,-2400],1500,140)]
    for id,p,r,b in pads:source['pads'].append(dict(id='map02_'+id,position_m=p,radius_m=r,blend_m=b))
    modules=build_modules();instances=[]
    def instance(id,module,p,region,q=0):instances.append(dict(id=id,module_id=module,position_m=p,region_id=region,yaw_quarters=q))
    # Town blocks have deliberate street gaps, a public square and a distinct harbour front.
    for row in range(6):
        for col in range(8):
            if (row in [2,3] and col in [3,4]):continue
            instance(f'town_home_{row}_{col}','town_house',[-5500+col*62,18,-3690+row*62],'civil_town',col%2*2)
    for i in range(5):instance(f'town_shop_{i}','town_shop',[-5420+i*80,18,-3190],'civil_town')
    instance('town_hall','public_hall',[-5270,18,-3535],'civil_town')
    instance('harbor_office','control_tower',[-4650,10,-3400],'civil_port')
    for i in range(3):instance(f'civil_store_{i}','cargo_warehouse',[-4520,10,-3520+i*105],'civil_port',1)
    instance('civil_crane','dock_crane',[-4200,10,-2920],'civil_port',1)
    for i in range(5):instance(f'civil_bollard_{i}','pier_furniture',[-4220,10,-3100+i*110],'civil_port')
    # Military basin: two long piers, separated oil yard, large repair roofs and regular barracks.
    for i in range(2):instance(f'naval_repair_{i}','repair_shed',[2800+i*700,12,-4750],'naval_base',2)
    for i in range(3):instance(f'naval_store_{i}','military_warehouse',[2800+i*240,12,-5010],'naval_base')
    for i in range(4):instance(f'naval_barracks_{i}','barracks',[2800+i*170,12,-5150],'naval_base')
    instance('naval_control','control_tower',[3250,12,-4900],'naval_base')
    for row in range(2):
        for col in range(4):instance(f'naval_tank_{row}_{col}','fuel_tank',[4240+col*55,18,-5750+row*65],'fuel_yard')
    for x in [2600,3900]:
        instance(f'naval_crane_{x}','dock_crane',[x,12,-3860],'naval_base',0 if x==2600 else 2)
        for i in range(6):instance(f'naval_bollard_{x}_{i}','pier_furniture',[x+24,12,-4410+i*145],'naval_base')
    # Airfield: reuses the existing prototype's runway/taxi/parking organisation, not its flight loop.
    for i in range(2):instance(f'air_hangar_{i}','air_hangar',[6340,8.04,-2640+i*240],'airfield',1)
    instance('airfield_control','control_tower',[6300,8,-2050],'airfield')
    for i in range(2):instance(f'airfield_barrack_{i}','barracks',[6370+i*80,8,-1940],'airfield')
    for i in range(2):instance(f'airfield_tank_{i}','fuel_tank',[6250+i*55,8,-1850],'airfield')
    objects=source['objects']
    for entry in instances:
        for p in modules[entry['module_id']]['parts']:
            q=entry['yaw_quarters']%4;x,y,z=p['position_m'];sx,sy,sz=p['size_m']
            for _ in range(q):x,z=-z,x;sx,sz=sz,sx
            anchor=entry['position_m'];position=[anchor[0]+x,anchor[1]+y,anchor[2]+z]
            kind='quay' if p['quay'] else ('map02_structure' if p['solid'] else 'crane')
            objects.append(dict(id=entry['id']+'_'+p['id'],kind=kind,position_m=position,size_m=[sx,sy,sz],color=p['color'],map02_shape=p['shape'],map02_yaw_quarters=q,map02_facility_id=entry['id'],map02_module=entry['module_id'],map02_region_id=entry['region_id'],map02_collision=p['solid']))
    def solid(id,p,size,region,color='88948c',kind='quay'):
        objects.append(dict(id=id,kind=kind,position_m=p,size_m=size,color=color,map02_shape='box',map02_region_id=region,map02_facility_id=id,map02_collision=True))
    # Solid caisson piers have no floating deck illusion and exact box support/contact.
    solid('civil_apron_edge',[-4400,-14,-3310],[150,24,370],'civil_port')
    solid('civil_access',[-4300,-14,-3170],[240,24,50],'civil_port')
    solid('civil_finger',[-4200,-14,-2860],[50,24,620],'civil_port')
    solid('civil_pier_head',[-4200,-14,-2560],[300,24,45],'civil_port')
    solid('civil_breakwater',[-4250,-14,-2160],[720,20,42],'civil_port','7f8d86')
    solid('naval_quay',[3250,-16,-4490],[1500,28,100],'naval_base')
    for x in [2600,3900]:solid(f'naval_pier_{x}',[x,-16,-4050],[75,28,900],'naval_base')
    solid('naval_breakwater_w',[2200,-16,-3100],[650,22,50],'naval_base','7c8983')
    solid('naval_breakwater_e',[4400,-16,-3100],[650,22,50],'naval_base','7c8983')
    # Airfield hardstands share the compiled support/contact top at y=8.04.
    solid('runway_surface',[6900,7.5,-2400],[58,.54,1400],'airfield','8a8f7d')
    solid('taxiway_surface',[6650,7.5,-2400],[16,.54,760],'airfield','949681')
    solid('apron_surface',[6450,7.5,-2460],[300,.54,520],'airfield','9b9d8a')
    for z in [-2780,-2020]:solid(f'taxi_connector_{-z}',[6775,7.5,z],[250,.54,16],'airfield','949681')
    # Runway paint is appearance-only over the existing physical strip.
    for i in range(18):
        objects.append(dict(id=f'runway_mark_{i}',kind='crane',position_m=[6900,8.045,-3020+i*72],size_m=[2,.015,30],color='d6d5b7',map02_shape='box',map02_region_id='airfield',map02_facility_id='runway_marks',map02_collision=False))
    roads=[('town_north',[[-5600,0,-3770],[-4910,0,-3770]],12),('town_south',[[-5580,0,-3110],[-4770,0,-3110]],12),('town_west',[[-5570,0,-3770],[-5570,0,-3110]],10),('town_main',[[-5150,0,-3770],[-5150,0,-3110]],13),('port_link',[[-4910,0,-3460],[-4710,0,-3460],[-4550,0,-3380],[-4400,0,-3330]],14),('naval_service',[[2500,0,-4890],[4320,0,-4890],[4320,0,-4580]],16),('oil_service',[[3900,0,-4890],[4200,0,-5300],[4350,0,-5580]],12),('airfield_service',[[6200,0,-2750],[6200,0,-1820],[6550,0,-1820]],10)]
    for id,points,w in roads:source['roads'].append(dict(id='map02_'+id,points_m=points,width_m=w))
    sites=[('civil_coast_01','民港入口岸炮',[-3010,32,-3200],32,['coastal_gun'],-2.35,[-70,70],'us'),('town_aa_01','小镇北防空',[-5300,18,-3880],26,['light_aa','heavy_aa'],0,[-180,180],'us'),('main_ridge_aa','主岛高地防空',[-5200,590,-4630],30,['light_aa','heavy_aa'],0,[-180,180],'us'),('naval_coast_01','军港西岸炮',[2150,42,-5050],34,['coastal_gun'],math.pi,[-75,75],'jp'),('naval_aa_01','军港勤务区防空',[3250,12,-5260],25,['light_aa','heavy_aa'],math.pi,[-180,180],'jp'),('naval_ridge_aa','军港高地防空',[2950,478,-5700],30,['light_aa','heavy_aa'],math.pi,[-180,180],'jp'),('airfield_aa_01','机场东防空',[7400,8,-2450],26,['light_aa','heavy_aa'],0,[-180,180],'jp')]
    for id,label,p,r,roles,yaw,arc,faction in sites:
        source['deployment_sites'].append(dict(id='map02_'+id,label=label,position_m=p,yaw_rad=yaw,radius_m=r,roles=roles,suggested_faction=faction,train_limits_deg=arc,elevation_limits_deg=[-5,45] if roles==['coastal_gun'] else [-5,85],clearance_m=0.0,support_surface='land',overhead_clearance_m=90,placement_state='reserved_empty'))
    views=[('overview','扩展群岛总览',[800,0,-700],21000,.15,1.22),('civil','民港与小镇',[-4850,20,-3330],2000,.9,.65),('civil_low','民港进出航道',[-4050,12,-2750],900,1.15,.14),('naval','军港与油库',[3350,20,-4600],2400,.8,.8),('naval_low','军港泊位与维修棚',[3250,20,-4370],1450,.1,.2),('fuel','军港油库',[4350,18,-5700],650,.8,.6),('airfield','陆基机场预留',[6750,8,-2400],1800,1.0,1.0),('ridge','高地防空空阵地',[2950,480,-5700],420,1.2,.4),('outer_sea','航母外海操作水域',[0,0,9300],11000,.1,1.15)]
    for id,label,p,dist,yaw,pitch in views:source['viewpoints'].append(dict(id='map02_'+id,label=label,focus_m=p,distance_m=dist,yaw_rad=yaw,pitch_rad=pitch))
    regions=[('civil_town','沿岸小镇',[-5570,-3820,760,790],[-5200,18,-3510],'us'),('civil_port','民用港口',[-4700,-3650,1100,1700],[-4250,10,-2950],'us'),('naval_base','军港维修基地',[1900,-5300,2800,2400],[3250,12,-4500],'jp'),('fuel_yard','军港油库',[4140,-5870,400,320],[4350,18,-5700],'jp'),('airfield','陆基机场预留',[6100,-3300,1550,1900],[6800,8,-2400],'jp'),('main_defence','主岛岸防/高地',[-5650,-4950,2850,1950],[-5200,590,-4630],'us'),('naval_defence','军港岸防/高地',[1700,-6000,1800,1700],[2950,478,-5700],'jp')]
    region_data=dict(schema_version=1,map_id=source['id'],coordinate_system='metres; +Y up; -Z north',regions=[dict(id=id,label=label,bounds_xz_m=b,focus_m=p,suggested_faction=f) for id,label,b,p,f in regions],shipping_channels=[dict(id='civil_entry',label='民港进出航道',waypoints_m=[[-3300,0,-1400],[-3600,0,-2350],[-3850,0,-2790]],clearance_radius_m=120,max_length_m=130,max_beam_m=22),dict(id='naval_entry',label='军港主航道',waypoints_m=[[3250,0,-1900],[3250,0,-3250],[3250,0,-4100]],clearance_radius_m=220,max_length_m=280,max_beam_m=42)],service_anchors=[dict(id='civil_water_service',position_m=[-4200,10,-2790],support_surface='ground_deck',roles=['service_anchor'],not_ground_deployable=True),dict(id='naval_water_service',position_m=[2600,12,-3850],support_surface='ground_deck',roles=['service_anchor'],not_ground_deployable=True)],carrier_operation_areas=[dict(id='carrier_jp',suggested_faction='jp',bounds_xz_m=[-9000,8000,7000,3000],heading_rad=-math.pi/2,launch_lane_m=[[-8200,0,9500],[-2800,0,9500]],approach_centerline_m=[[-9000,280,9500],[-4000,20,9500]],hull_clearance_m=350),dict(id='carrier_us',suggested_faction='us',bounds_xz_m=[2000,8000,7000,3000],heading_rad=-math.pi/2,launch_lane_m=[[2800,0,9500],[8200,0,9500]],approach_centerline_m=[[2000,280,9500],[7000,20,9500]],hull_clearance_m=350)],airfield=dict(id='map02_east_airfield',status='geometry_and_static_clearance_only',prototype='island_airfield/scenes/woleai_1944.tscn',surface_height_m=8.04,runway=dict(id='rwy_18_36',center_m=[6900,8.04,-2400],length_m=1400,width_m=58,heading_rad=0,thresholds_m=[[6900,8.04,-3100],[6900,8.04,-1700]],clear_bounds_xz_m=[6835,-3250,130,1700]),taxiway=dict(centerline_m=[[6650,8.04,-2780],[6650,8.04,-2020]],width_m=16,connectors_m=[[[6650,8.04,-2780],[6900,8.04,-2780]],[[6650,8.04,-2020],[6900,8.04,-2020]]]),parking_stands=[dict(id=f'park_{i+1}',position_m=[6420+(i%2)*80,8.04,-2600+(i//2)*90],heading_rad=-math.pi/2,radius_m=16) for i in range(8)],approach_corridors=[dict(id='north',centerline_m=[[6900,190,-6500],[6900,8.04,-3100]],half_width_m=80),dict(id='south',centerline_m=[[6900,190,1700],[6900,8.04,-1700]],half_width_m=80)],obstacle_facility_ids=[x['id'] for x in instances if x['region_id']=='airfield']))
    write('data/map02/facility_modules.json',dict(schema_version=1,modules=modules))
    write('data/map02/facility_instances.json',dict(schema_version=1,instances=instances))
    write('data/map02/regions.json',region_data)
    write('data/maps/island_harbor_expanded.json',source)
    print(f'MAP02: {len(instances)} facility instances / {len(objects)} component records / {len(sites)} empty deployment sites')
if __name__=='__main__':main()
