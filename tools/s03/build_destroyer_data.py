#!/usr/bin/env python3
"""Reproducible S03 configuration authoring. Never changes shared simulation files."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
WEAPONS = {
    "us_5in38_mk30": ("s03_us_5in38_mk30_single", 1, [0,1.32,-0.38], [[0,0,-3.82]], 0.16,1.60,[-150,150],[-15,85],4.0,300,25.0,15.0,"s03_us_127mm_mk32_common"),
    "us_11in_quad": ("s03_us_11in_mk2_quad",4,[0,1.20,0],[[-0.54,0,-2.55],[-0.18,0,-2.55],[0.18,0,-2.55],[0.54,0,-2.55]],0.15,1.10,[-180,180],[-10,90],0.40,800,20.0,20.0,"s03_us_28mm_mk1_he"),
    "us_oerlikon_single": ("s03_us_oerlikon_20mm_single",1,[0,1.05,0],[[0,0,-1.20]],0.12,0.38,[-90,90],[-5,85],0.1333333,1200,60.0,45.0,"s03_us_20mm_mk3_he"),
    "jp_127mm_type_c": ("s03_jp_127mm_type3_c_twin",2,[0,1.44,-0.32],[[-0.70,0,-5.06],[0.70,0,-5.06]],0.18,1.96,[-140,140],[-7,55],6.0,150,6.0,6.0,"s03_jp_127mm_type1_common"),
    "jp_type96_twin": ("s03_jp_type96_25mm_twin",2,[0,1.12,0],[[-0.18,0,-1.85],[0.18,0,-1.85]],0.12,0.84,[-90,90],[-5,85],0.24,1500,18.0,12.0,"s03_jp_25mm_type96_he"),
}


def write(path, data):
    p = ROOT / path
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(data,ensure_ascii=False,indent=2)+"\n" if not isinstance(data,str) else data)


def host(id, position, width, length, height, source, shape="round_front", **kw):
    return dict(id=id,position_m=position,shape=shape,width_m=width,length_m=length,height_m=height,source_ids=source,**kw)


def surface(id, position, radius):
    return dict(id=id,position_m=position,radius_m=radius)


def build_fletcher():
    folder="fletcher_dd445"
    uid="us_fletcher_dd445_1942_07_18"
    assembly_path=f"res://data/ships/{folder}/assembly.json"
    source=["F01","F02","F03","F04","F05","F06","F07"]
    c=dict(id=uid,country_id="us",unit_definition=f"res://data/units/{uid}.json")
    c["hull"]={"source_ids":["F01","F02","F05"],"stations":[
        [-57.3786,.015,5.6,-.05],[-56.0,.65,5.35,-1.35],[-53,1.75,5.05,-2.75],[-49,3.0,4.65,-3.7],[-44,4.1,4.24,-3.96],[-40,4.72,4.0,-3.96],[-34,5.42,3.55,-3.96],[-27,5.85,3.4,-3.96],[-18,6.0325,3.4,-3.96],[-5,6.0325,3.4,-3.96],[10,5.95,3.4,-3.96],[23,5.70,3.4,-3.96],[35,5.10,3.4,-3.96],[44,4.30,3.4,-3.7],[50,3.65,3.4,-3.2],[54.5,2.85,3.4,-2.3],[56.5,1.65,3.4,-1.3],[57.3786,.015,3.4,-.05]],
        "surfaces":[surface("main_51_deck",[0,3.946,-38.0],2.3),surface("main_55_deck",[0,3.496,39.5],2.4),surface("waist_port",[-4.8,3.422,10.2],.6),surface("waist_starboard",[4.8,3.422,10.2],.6)]}
    for station in c["hull"]["stations"]:
        station.append(round(max(0,(-station[0]-44)/13.3786)*2.4 if station[0]<0 else -max(0,(station[0]-50)/7.3786)*.7,4))
    windows=[]
    for angle in [-160,-140,-120,-100,-80,-60,-40,-20]:
        import math
        a=math.radians(angle)
        windows.append([[math.cos(a)*3.22,0.65,-.55+math.sin(a)*3.22],[.68,.55,.06],-angle-90])
    c["structures"]={"bridge":[
        host("forward_deckhouse",[0,3.496,-21.6],7.4,23.6,2.35,["F01","F05"],surfaces=[surface("roof",[0,2.41,0],3.7)]),
        host("bridge_lower",[0,5.906,-19.25],6.7,7.6,3.15,["F01","F05"]),
        host("pilot_house",[0,9.056,-19.25],6.4,6.9,1.65,["F01","F05"],windows=windows),
        host("director_platform",[0,10.766,-19.25],7.25,7.8,.14,["F01","F05"],shape="ellipse"),
        host("director_pedestal",[0,10.966,-19.25],2.1,2.1,1.35,["F01","F05"],shape="ellipse"),
    ],"funnels":[
        host("forward_funnel",[0,5.906,-9.6],3.1,4.7,7.0,["F01","F02"],shape="ellipse",funnel=True,rake_m=1.10),
        host("aft_funnel",[0,5.906,5.0],3.1,4.5,7.0,["F01","F02","F04"],shape="ellipse",funnel=True,rake_m=1.10),
    ],"platforms":[
        host("central_deckhouse",[0,3.496,2.4],5.4,24.4,2.35,["F01","F02","F04"],shape="beveled"),
        host("forward_torpedo_seat",[0,5.846,-2.2],3.9,8.0,.06,["F01","F02"],surfaces=[surface("roof",[0,.12,0],1.3)]),
        host("aft_deckhouse",[0,3.496,24.7],6.8,19.6,2.35,["F01","F02","F03"],shape="beveled",surfaces=[surface("roof",[0,2.41,0],3.3)]),
        host("aft_aa_tower",[0,5.906,26.0],2.8,3.8,2.72,["F01","F02"],shape="round_front"),
        host("aft_aa_tub",[0,8.686,26.0],4.15,4.15,.15,["F01","F02"],shape="ellipse",surfaces=[surface("floor",[0,.21,0],2.075)]),
        host("searchlight_wing",[2.35,8.686,26.0],1.4,1.7,.15,["F01","F02"],shape="ellipse"),
    ]}
    # (station, weapon, actual host, named surface, host-surface offset, base yaw, role)
    stations=[("main_51","us_5in38_mk30","hull","main_51_deck",[0,0,0],0,"main"),
        ("main_52","us_5in38_mk30","forward_deckhouse","roof",[0,0,-9.3],0,"main"),
        ("main_53","us_5in38_mk30","aft_deckhouse","roof",[0,0,-6.0],0,"main"),
        ("main_54","us_5in38_mk30","aft_deckhouse","roof",[0,0,6.4],180,"main"),
        ("main_55","us_5in38_mk30","hull","main_55_deck",[0,0,0],180,"main"),
        ("aa_11_quad","us_11in_quad","aft_aa_tub","floor",[0,0,0],180,"dedicated_aa"),
        ("aa_20_forward_port","us_oerlikon_single","forward_deckhouse","roof",[-3.15,0,-5.0],90,"dedicated_aa"),
        ("aa_20_forward_starboard","us_oerlikon_single","forward_deckhouse","roof",[3.15,0,-5.0],-90,"dedicated_aa"),
        ("aa_20_waist_port","us_oerlikon_single","hull","waist_port",[0,0,0],90,"dedicated_aa"),
        ("aa_20_waist_starboard","us_oerlikon_single","hull","waist_starboard",[0,0,0],-90,"dedicated_aa")]
    c["equipment"]=[
        dict(id="foremast",kind="mast",position_m=[0,5.906,-14.8],height_m=19.6,tripod=False,radar=True,source_ids=["F01","F02"]),
        dict(id="mk37",kind="director",position_m=[0,12.316,-19.25],usn=True,source_ids=["F01","F05"]),
        dict(id="torpedo_01",kind="torpedo",position_m=[0,5.966,-2.2],tube_count=5,source_ids=["F01","F02"]),
        dict(id="torpedo_02",kind="torpedo",position_m=[0,5.906,12.0],tube_count=5,source_ids=["F01","F02"]),
        dict(id="motor_boat_port",kind="boat",position_m=[-4.1,5.0,-13.5],length_m=6.6,source_ids=["F01","F04"]),
        dict(id="motor_boat_starboard",kind="boat",position_m=[4.1,5.0,-13.5],length_m=6.6,source_ids=["F01","F04"]),
        dict(id="searchlight",kind="searchlight",position_m=[2.35,8.896,26.0],source_ids=["F01","F02"]),
        dict(id="depth_rack_port",kind="depth_rack",position_m=[-1.25,3.5,53.5],source_ids=["F01","F02","F03"]),
        dict(id="depth_rack_starboard",kind="depth_rack",position_m=[1.25,3.5,53.5],source_ids=["F01","F02","F03"]),
    ]
    for record in c["equipment"]:
        if record["kind"]=="boat":record["deck_y_m"]=3.45
    for x in [-3.53,3.53]:c["equipment"].append(dict(id="anchor_"+str(x).replace('.','_'),kind="anchor",position_m=[x,2.75,-46.4],yaw_deg=90,source_ids=["F01","F05"]))
    for z in [-51.5,50.5]:c["equipment"].append(dict(id="bollard_"+str(z).replace('.','_'),kind="bollard",position_m=[0,4.8 if z<0 else 3.5,z],source_ids=["F01","F03"]))
    finish(folder,uid,"USS Fletcher DD-445 · 1942-07-18",1942,"1942-07-18",[12.065,29.466,114.7572],c,stations,source,
        [("us_5in38_mk30",5)],[("us_11in_quad",1),("us_oerlikon_single",4)],
        [dict(description="1.1 inch/75 quadruple Mk2",mount_count=1,barrels_per_mount=4),dict(description="20 mm Oerlikon single (early wartime baseline)",mount_count=6,barrels_per_mount=1)],
        "Four rather than six single Oerlikons in Showcase: forward pair and one outboard waist pair retained. No late-war Bofors platforms. Main 5-inch dual-purpose mounts remain fixed historical armament.")


def build_yukikaze():
    folder="yukikaze"
    uid="jp_yukikaze_1942_06"
    source=["Y01","Y02","Y04","Y05","Y07","T01","T02","T03","T04","T05","J01","J02","J03"]
    c=dict(id=uid,country_id="jp",unit_definition=f"res://data/units/{uid}.json")
    c["hull"]={"source_ids":["Y01","Y02","Y07","T05"],"linoleum_spans_m":[[-45,-24],[18,44]],"stations":[
        [-59.25,.015,5.8,-.03,2.8],[-57.0,.75,5.55,-1.6,2.0],[-53.0,1.95,5.35,-2.8,1.2],[-48.0,3.0,5.2,-3.5,.45],[-40.9,4.05,5.10,-3.76,0],[-33,4.78,5.10,-3.76,0],[-26,5.18,5.10,-3.76,0],[-20.5,5.32,5.10,-3.76,0],[-20.49,5.32,3.0,-3.76,0],[-10,5.4,3.0,-3.76,0],[0,5.4,3.0,-3.76,0],[10,5.35,3.0,-3.76,0],[20,5.12,3.0,-3.76,0],[30,4.70,3.0,-3.76,0],[40,4.1,3.0,-3.5,0],[49,3.6,3.0,-2.8,-.15],[55,2.85,3.0,-1.7,-.35],[58,1.7,3.0,-.7,-.5],[59.25,.015,3.0,-.03,-.5]],
        "surfaces":[surface("main_a_deck",[0,5.196,-40.9],2.8),surface("main_y_deck",[0,3.096,35.75],2.8)]}
    import math
    windows=[]
    for angle in [-165,-140,-115,-90,-65,-40,-15]:
        a=math.radians(angle)
        windows.append([[math.cos(a)*3.00,.68,-.48+math.sin(a)*3.0],[.70,.60,.065],-angle-90])
    c["structures"]={"bridge":[
        host("bridge_lower",[0,5.196,-27.05],5.1,6.25,3.50,["Y01","Y02","Y05"],top_scale=.96),
        host("pilot_house",[0,8.756,-27.05],6.0,6.6,1.75,["Y01","Y02","Y04","Y05"],windows=windows),
        host("bridge_roof",[0,10.566,-27.05],6.1,6.6,.12,["Y01","Y02","Y05"]),
        host("director_pedestal",[0,10.746,-27.05],2.4,2.4,.35,["Y01","Y02","Y05"],shape="ellipse"),
    ],"funnels":[
        host("forward_funnel",[0,5.256,-14.6],3.50,5.20,6.95,["Y01","Y02","T03"],shape="ellipse",funnel=True,rake_m=.65),
        host("aft_funnel",[0,5.256,2.0],2.70,3.80,5.60,["Y01","Y02","T01"],shape="ellipse",funnel=True,rake_m=.35),
    ],"platforms":[
        host("forward_boiler_house",[0,3.096,-14.55],6.30,10.5,2.10,["Y01","Y02","T03"],shape="beveled"),
        host("aft_boiler_house",[0,3.096,2.40],3.8,5.0,2.10,["Y01","Y02","T01"],shape="beveled"),
        host("aa_platform_port",[-2.55,5.196,2.0],2.15,2.65,.14,["Y01","Y02","T01"],shape="ellipse",surfaces=[surface("floor",[0,.20,0],1.075)]),
        host("aa_platform_starboard",[2.55,5.196,2.0],2.15,2.65,.14,["Y01","Y02","T01"],shape="ellipse",surfaces=[surface("floor",[0,.20,0],1.075)]),
        host("aft_deckhouse",[0,3.096,25.7],5.70,13.8,2.10,["Y01","Y02","T02","T04"],shape="beveled",surfaces=[surface("roof",[0,2.16,0],2.85)]),
        host("searchlight_stand",[0,3.096,6.8],1.8,1.8,2.10,["Y02","T01"],shape="ellipse"),
    ]}
    stations=[("main_a","jp_127mm_type_c","hull","main_a_deck",[0,0,0],0,"main"),
        ("main_x","jp_127mm_type_c","aft_deckhouse","roof",[0,0,1.85],180,"main"),
        ("main_y","jp_127mm_type_c","hull","main_y_deck",[0,0,0],180,"main"),
        ("aa_25_port","jp_type96_twin","aa_platform_port","floor",[0,0,0],90,"dedicated_aa"),
        ("aa_25_starboard","jp_type96_twin","aa_platform_starboard","floor",[0,0,0],-90,"dedicated_aa")]
    c["equipment"]=[
        dict(id="foremast",kind="mast",position_m=[0,3.096,-21.4],height_m=19.5,tripod=True,radar=False,source_ids=["Y01","Y02"]),
        dict(id="aft_mast",kind="mast",position_m=[0,5.256,20.8],height_m=12.6,tripod=True,radar=False,source_ids=["Y01","Y02","T02"]),
        dict(id="type94_director",kind="director",position_m=[0,11.156,-27.05],usn=False,source_ids=["Y01","Y02","Y05"]),
        dict(id="torpedo_01",kind="torpedo",position_m=[0,3.096,-4.6],tube_count=4,source_ids=["Y01","Y02","T01","T05"]),
        dict(id="torpedo_02",kind="torpedo",position_m=[0,3.096,12.7],tube_count=4,source_ids=["Y01","Y02","T02","T05"]),
        dict(id="fore_boat_port",kind="boat",position_m=[-4.0,5.12,-26.0],length_m=6.2,source_ids=["Y01","Y02","T03"]),
        dict(id="fore_boat_starboard",kind="boat",position_m=[4.0,5.12,-26.0],length_m=6.2,source_ids=["Y01","Y02","T03"]),
        dict(id="waist_boat_port",kind="boat",position_m=[-4.05,3.11,5.9],length_m=6.5,source_ids=["Y01","Y02","T01","T02"]),
        dict(id="waist_boat_starboard",kind="boat",position_m=[4.05,3.11,5.9],length_m=6.5,source_ids=["Y01","Y02","T01","T02"]),
        dict(id="depth_rack_port",kind="depth_rack",position_m=[-1.0,3.1,52.7],source_ids=["Y02","T02"]),
        dict(id="depth_rack_starboard",kind="depth_rack",position_m=[1.0,3.1,52.7],source_ids=["Y02","T02"]),
        dict(id="searchlight",kind="searchlight",position_m=[0,5.256,6.8],source_ids=["Y02","T01"]),
    ]
    # Reload containers are independent equipment, never fake bridges to cannon seats.
    for side,x in [("port",-2.30),("starboard",2.30)]:
        c["equipment"].append(dict(id="fore_reload_"+side,kind="reload",position_m=[x,3.1,-14.7],size_m=[1.1,1.5,8.6],source_ids=["Y01","Y02","T03"]))
        c["equipment"].append(dict(id="aft_reload_"+side,kind="reload",position_m=[x,3.1,7.3],size_m=[1.1,.95,7.2],source_ids=["Y01","Y02","T01"]))
    for record in c["equipment"]:
        if record["kind"]=="boat":record["deck_y_m"]=5.15 if "fore_boat" in record["id"] else 3.1
    for x in [-3.12,3.12]:c["equipment"].append(dict(id="anchor_"+str(x).replace('.','_'),kind="anchor",position_m=[x,3.5,-47.0],yaw_deg=90,source_ids=["Y01","Y02","Y07"]))
    finish(folder,uid,"IJN Yukikaze 雪風 · 1942-06-04",1940,"1942-06-04",[10.8,26.356,118.5],c,stations,source,
        [("jp_127mm_type_c",3)],[("jp_type96_twin",2)],
        [dict(description="25 mm Type96 twin, early configuration at aft funnel",mount_count=2,barrels_per_mount=2)],
        "Two twin Type96 AA mounts retained, matching early baseline. All three twin TypeC main mounts are fixed historical armament. June 1942 configuration is reconstructed from same-ship 1939/1940 photographs and the documented 1943 refit chronology; no Type22/13 radar or post-removal X-turret platform is transplanted.")


def finish(folder,uid,label,year,date,dimensions,c,stations,sources,fixed,game,historical,aa_note):
    assembly_path=f"res://data/ships/{folder}/assembly.json"
    scene_dir=f"scenes/ships/{folder}"
    c["module_scenes"]=[dict(id=name,scene=f"res://{scene_dir}/{file}.tscn") for name,file in [("Hull","hull"),("Bridge","bridge"),("Funnels","funnels"),("Platforms","platforms"),("Equipment","equipment")]]
    c["installations"]={}
    mounts=[]; definitions=[]
    hosts={r["id"]:r for group in c["structures"].values() for r in group}
    for station,kind,host_id,sid,offset,yaw,role in stations:
        w=WEAPONS[kind]; height,radius=w[4:6]
        if host_id=="hull":
            s=next(s for s in c["hull"]["surfaces"] if s["id"]==sid); origin=s["position_m"]
        else:
            h=hosts[host_id];s=next(s for s in h["surfaces"] if s["id"]==sid);origin=[a+b for a,b in zip(h["position_m"],s["position_m"])]
        seat=[round(origin[0]+offset[0],6),round(origin[1]+offset[1]+height,6),round(origin[2]+offset[2],6)]
        c["installations"][station]=dict(surface_id=sid,surface_offset_m=offset,foundation_height_m=height,foundation_radius_m=radius,interface_id=kind,weapon_scene=f"res://scenes/ships/destroyer_modules/{kind}.tscn")
        mounts.append(dict(id=station,host_id=host_id,weapon_definition_id=w[0],role=role,position_m=seat,base_yaw_deg=yaw,elevation_pivot_m=w[2],muzzle_positions_m=w[3],source=dict(status="provisional",reference_ids=sources,geometry_status="photo_proportions_matched",note="Named deck/roof and centreline/side relationship checked against original photographs. Coordinates reconstructed in metres, not surveyed shipyard offsets; see modeling-brief.md.")))
        if any(d["id"]==w[0] for d in definitions):continue
        definitions.append(dict(id=w[0],ammo_id=w[12],barrel_count=w[1],cycle_s=w[8],initial_rounds_per_barrel=w[9],train_limits_deg=w[6],elevation_limits_deg=w[7],train_rate_degps=w[10],elevation_rate_degps=w[11],source=dict(status="provisional",paths=["docs/references/ships/"+folder+("_1942_07_18" if folder=="fletcher_dd445" else "_1942_06")+"/modeling-brief.md"],note="Historical gun/mount identity; basic limits and exterior geometry checked. Cycles, rates and inventory are explicit integration estimates pending S05 ammunition/fire-control calibration. Mechanical limits are not permission to fire through own ship.")))
    unit=dict(id=uid,display_name=label,country_id=c["country_id"],domain="ship",service_entry_year=year,configuration_date=date,dimensions_m=dimensions,model_scene=f"res://{scene_dir}/{folder}.tscn",weapon_definitions=definitions,mounts=mounts,
        historical_fixed_armament=[dict(weapon_definition_id=WEAPONS[k][0],mount_count=n,barrels_per_mount=WEAPONS[k][1]) for k,n in fixed],
        dedicated_aa_historical=historical,dedicated_aa_game=[dict(weapon_definition_id=WEAPONS[k][0],mount_count=n,barrels_per_mount=WEAPONS[k][1]) for k,n in game],
        source=dict(status="provisional",reference_ids=sources,paths=[f"docs/references/ships/{folder}"+("_1942_07_18" if folder=="fletcher_dd445" else "_1942_06")+"/modeling-brief.md"],note=aa_note+" dimensions_m is [beam, keel-to-mast height, length overall]. Full outline is reconstructed from documented photographs; performance/fuel/damage parameters remain S05/S06 work. Torpedo equipment is visual only."))
    write(f"data/ships/{folder}/assembly.json",c)
    write(f"data/units/{uid}.json",unit)
    root_scene='[gd_scene load_steps=2 format=3]\n\n[ext_resource type="Script" path="res://scripts/naval/destroyers/destroyer_adapter.gd" id="1"]\n\n[node name="'+folder+'" type="Node3D"]\nscript = ExtResource("1")\nassembly_path = "'+assembly_path+'"\n'
    write(f"{scene_dir}/{folder}.tscn",root_scene)
    for module in ["hull","bridge","funnels","platforms","equipment"]:
        script="hull_module" if module=="hull" else ("equipment_module" if module=="equipment" else "structure_module")
        scene='[gd_scene load_steps=2 format=3]\n\n[ext_resource type="Script" path="res://scripts/naval/destroyers/'+script+'.gd" id="1"]\n\n[node name="'+module+'" type="Node3D"]\nscript = ExtResource("1")\nassembly_path = "'+assembly_path+'"\n'
        if script=="structure_module":scene+='group_id = "'+module+'"\n'
        write(f"{scene_dir}/{module}.tscn",scene)


def common():
    for kind in WEAPONS:
        write(f"scenes/ships/destroyer_modules/{kind}.tscn",'[gd_scene load_steps=2 format=3]\n\n[ext_resource type="Script" path="res://scripts/naval/destroyers/weapon_module.gd" id="1"]\n\n[node name="'+kind+'" type="Node3D"]\nscript = ExtResource("1")\nmount_kind = "'+kind+'"\n')
    for id,caliber,mass,speed in [("s03_us_127mm_mk32_common",.127,24.5,792.0),("s03_us_28mm_mk1_he",.02794,.416,823.0),("s03_us_20mm_mk3_he",.020,.123,835.0),("s03_jp_127mm_type1_common",.127,23.0,915.0),("s03_jp_25mm_type96_he",.025,.250,900.0)]:
        write(f"data/ammunition/{id}.json",dict(id=id,caliber_m=caliber,projectile_mass_kg=mass,muzzle_speed_mps=speed,gravity_mps2=9.80665,max_lifetime_s=45.0 if caliber>.1 else 6.0,source=dict(status="provisional",paths=["docs/references/ships/fletcher_dd445_1942_07_18/modeling-brief.md","docs/references/ships/yukikaze_1942_06/modeling-brief.md"],note="S03 namespaced integration values, not final ballistic/fuze/damage approval. Nominal caliber/representative mass/speed only; S05 must choose specific service projectile and fuze, confirm data, then calibrate effective burst/stock/cycle. max_lifetime is a safety bound.")))


if __name__=="__main__":
    common()
    build_fletcher()
    build_yukikaze()
