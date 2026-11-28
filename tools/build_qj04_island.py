#!/usr/bin/env python3
"""Build the authored QJ04 road network and civilian parcels on the QJ03 coastline."""
from pathlib import Path
from math import hypot, atan2, sin, cos
import json, random

root = Path(__file__).resolve().parents[1]
chart = json.loads((root / "data/maps/qj03_archipelago.json").read_text())
chart["id"] = "qj04_island"
chart["label"] = "青岬 · 岛镇与东港"
def obj(key, kind, x, z, w, h, d, color, y=0, heading=None, style=None):
    row = dict(id=key, kind=kind, position_m=[x,y,z], size_m=[w,h,d], color=color)
    if heading is not None: row["heading_rad"] = round(heading,5)
    if style: row["style"] = style
    return row

# Positive Z is coastward. Major and minor streets share authored junctions:
# not an orthogonal lot grid and not interpolation between building centers.
roads = []
def path(key, width, kind, points):
    roads.append((key,width,kind,points))

path("coast_spine",11,"main",[(385,443),(448,437),(491,448),(560,470),(615,466),(681,447),(741,422),(801,391),(860,353),(921,299),(974,237),(1039,186),(1091,155),(1141,156)])
path("east_quay_apron",10,"quay",[(1141,156),(1138,111),(1139,80),(1160,80),(1251,81),(1310,82)])
path("market_bend",8,"local",[(491,448),(498,499),(529,539),(574,557),(628,553),(687,535),(738,509),(783,460),(801,391)])
path("lower_waterfront",8,"local",[(498,499),(483,576),(509,638),(559,681),(631,709),(703,731),(764,743),(826,764),(868,812),(855,856)])
path("inner_lane",6,"local",[(529,539),(555,593),(579,625),(629,654),(671,670),(728,687),(782,724),(826,764)])
path("upper_lane",6,"local",[(615,466),(635,505),(628,553),(618,598),(629,654),(631,709)])
path("fishing_lane",6,"local",[(687,535),(708,577),(734,627),(728,687),(703,731)])
path("school_lane",5.5,"local",[(738,509),(780,530),(813,570),(809,616),(775,656),(734,627)])
path("harbor_slope",7,"local",[(860,353),(901,366),(938,354),(976,313),(1004,268),(974,237)])
path("orchard_circuit",6,"local",[(560,470),(544,431),(562,393),(601,376),(646,386),(681,409),(681,447)])
path("upland_road",6.5,"hill",[(601,376),(637,349),(684,325),(718,291),(740,247),(727,213),(688,202),(644,218),(609,250),(558,263),(509,248),(475,214),(458,174),(457,127),(467,80),(495,20),(529,-33),(568,-73),(607,-102),(647,-140),(644,-168),(615,-174),(572,-157),(532,-138),(505,-152),(510,-190),(544,-225)])
path("shrine_approach",4,"foot",[(688,202),(677,170),(655,149),(645,119),(653,89),(676,60),(684,33)])
path("orchard_lane",4.5,"local",[(646,386),(669,366),(701,361),(733,376),(741,422)])
path("clinic_drive",6,"local",[(631,709),(632,740),(654,763),(691,773),(717,766),(703,731)])
path("fire_square",7.5,"local",[(813,570),(844,563),(862,581),(854,614),(833,626),(809,616)])
path("supply_lane",5,"local",[(509,638),(476,643),(456,633),(447,608),(461,595),(483,576)])
path("terrace_walk",3.5,"foot",[(609,250),(581,208),(551,173),(519,157),(493,155),(458,174)])
path("market_arcade",3.4,"foot",[(574,557),(567,580),(569,610),(579,625)])
path("upper_orchards",4,"foot",[(475,214),(434,214),(405,193),(389,161),(398,132),(428,119),(457,127)])
path("lookout_path",3.5,"foot",[(505,-152),(473,-169),(440,-186),(416,-213)])
path("cottages_path",4,"foot",[(718,291),(752,307),(775,329),(810,341),(860,353)])
path("fish_promenade",5,"local",[(764,743),(765,779),(794,804),(834,812),(868,812)])

chart["roads"] = [dict(id=k,width_m=w,style=kind,points_m=[[x,0,z] for x,z in ps]) for k,w,kind,ps in roads]
chart["objects"] = [p for p in chart["objects"] if not p["id"].startswith("civil_") and p["id"] not in ["shrine","quay_wall","berth_north","berth_link"]]
chart["objects"] += [
    obj("east_reclamation","quay",1131,148,166,11.12,179,"989990",-5),
    obj("outer_service_apron","quay",1224,143,31,10,158,"979387",-4.1),
    obj("quay_extension_n","quay",1245,82,234,10,37,"8f948f",-4),
    obj("east_cargo_annex","warehouse",1110,133,36,9,25,"a2a99e"),
    obj("shrine_honden","house",685,9,16,7,12,"c0a585",style="shrine"),
    obj("shrine_haiden","house",684,26,23,7,13,"a48060",style="shrine"),
    obj("shrine_office","house",703,24,11,4,10,"b9a78c",style="shrine_office"),
    obj("shrine_store","house",704,3,9,4,8,"b8b09b",style="shrine_office"),
    obj("upland_weather","house",553,-249,12,5,9,"d4c7ab",style="upland"),
    obj("upland_keeper","house",567,-232,11,5,9,"b3a57e",style="upland",heading=.55),
    obj("upland_water_house","house",471,86,11,5,9,"bab4a3",style="upland",heading=-.6),
    obj("upland_rest","house",423,-216,11,5,7,"b79875",style="upland",heading=.24)]
chart["pads"] += [
    dict(id="shrine_court",position_m=[688,49,17],radius_m=31,blend_m=39),
    dict(id="meteorology_ledge",position_m=[556,101,-238],radius_m=18,blend_m=34),
    dict(id="lookout_ledge",position_m=[423,90,-214],radius_m=13,blend_m=29)]
def dist_segment(p,a,b):
    x,z=p; dx=b[0]-a[0]; dz=b[1]-a[1]
    t=max(0,min(1,((x-a[0])*dx+(z-a[1])*dz)/(dx*dx+dz*dz or 1)))
    return hypot(x-a[0]-t*dx,z-a[1]-t*dz)
segments=[(a,b,w) for _,w,_,pts in roads for a,b in zip(pts,pts[1:])]
def walks(pts, gap, start):
    left=start
    for a,b in zip(pts,pts[1:]):
        dx,dz=b[0]-a[0],b[1]-a[1]; size=hypot(dx,dz)
        while left<size:
            yield (a[0]+dx*left/size,a[1]+dz*left/size,dx/size,dz/size)
            left+=gap
        left-=size

rng=random.Random(20312)
palette=["d2b48e","b9ac93","c6ba9e","d7cca8","b3926d","a59b84","c8ad8d"]
for street, gap, start in [
    ("market_bend",26,19),("lower_waterfront",29,28),("inner_lane",25,17),
    ("upper_lane",27,13),("fishing_lane",29,19),("school_lane",32,12),
    ("orchard_circuit",33,23),("orchard_lane",26,13),("harbor_slope",31,17),("cottages_path",31,12)]:
    key,road_width,_,points=next(row for row in roads if row[0]==street)
    serial=0
    for sample,(x,z,dx,dz) in enumerate(walks(points,gap,start)):
        for side in (1,-1):
            if (sample + side*2)%9==0 and rng.random()<.75: continue
            w,d,h=rng.uniform(10,17.5),rng.uniform(8,13.5),rng.uniform(4.7,8.2)
            ox,oz=side*-dz,side*dx
            step=road_width/2+d/2+rng.uniform(5,9)
            cx,cz=x+ox*step,z+oz*step
            pad=hypot(w,d)/2
            if any(dist_segment((cx,cz),a,b)<rw/2+pad+1 for a,b,rw in segments): continue
            if any(hypot(cx-p["position_m"][0],cz-p["position_m"][2])<pad+hypot(p["size_m"][0],p["size_m"][2])/2+3
                   for p in chart["objects"]): continue
            if cz>794 or cx<410 or (cx>825 and cz>754) or (cx>970 and cz>450): continue
            # +Z of the house faces its own street frontage.
            heading=atan2(-ox,-oz)
            row=obj(f"civil_{street}_{serial:02d}","house",round(cx,2),round(cz,2),round(w,2),round(h,2),round(d,2),rng.choice(palette),heading=heading)
            row["frontage_m"]=[round(x,2),0,round(z,2)]
            chart["objects"].append(row);serial+=1

# Preserve the original procedural town sequence: add authored scenery only after
# the 84 street parcels are generated. These are not combat or support actors.
chart["roads"] += [
    dict(id="canvas_court_walk",width_m=5.5,style="local",points_m=[[x,0,z] for x,z in [(448,437),(443,412),(438,389),(429,365),(408,350),(385,350),(372,340),(353,332)]]),
    dict(id="wood_court_walk",width_m=4.6,style="foot",points_m=[[x,0,z] for x,z in [(783,460),(808,464),(818,478),(829,492),(846,497),(882,495)]]),
]
chart["pads"] += [
    dict(id="canvas_court_w",position_m=[351,25,327],radius_m=29,blend_m=29),
    dict(id="canvas_court_e",position_m=[392,29,321],radius_m=28,blend_m=39),
    dict(id="wood_hall_court",position_m=[856,11,491],radius_m=50,blend_m=31),
]
for i,(x,z,w,h,d,axis) in enumerate([
    (332,316,9.4,3.15,6.8,.2),(347,319,8.6,3.0,6.9,.13),
    (361,318,8.9,3.1,6.9,.08),(332,335,9.2,2.8,6.3,-.16),
    (349,341,9.3,3.0,7.1,-.28),(373,329,10,3.3,7.2,.44),
    (391,309,11,3.5,7.7,-.36),(407,318,9.3,3.0,6.5,.26)]):
    chart["objects"].append(obj(f"canvas_tent_{i+1:02d}","house",x,z,w,h,d,
                                ["aaa486","b7a988","8e9577","a39a79"][i%4],heading=axis,style="canvas_tent"))
chart["objects"] += [
    obj("camp_small_store","house",362,354,15,4.6,8.5,"bcb197",heading=.22,style="camp_one"),
    obj("camp_small_lodge","house",404,337,15.2,6.3,9.5,"a49b84",heading=-.31,style="camp_two"),
    obj("camp_small_laundry","house",415,357,10.8,4.2,7.9,"b8b49a",heading=.06,style="camp_one"),
    obj("town_wood_main","house",855,472,35,8.2,18.5,"9d7856",heading=.03,style="wood_hall"),
    obj("town_wood_east","house",885,516,24,6.1,13.6,"8c6d52",heading=-.52,style="wood_hall"),
    obj("town_wood_west","house",837,517,21.3,5.6,13,"a48060",heading=.48,style="wood_hall"),
]
views = {v["id"]:v for v in chart["viewpoints"]}
views["overview"].update(eye_m=[1715,1590,2540],focus_m=[260,21,75])
views["harbor"].update(label="东港 · 混凝土扩建区",eye_m=[1550,155,334],focus_m=[1110,9,146])
views["town"].update(label="镇区 · 弯街和成片街屋",eye_m=[829,140,886],focus_m=[639,17,575])
views["public_street"].update(eye_m=[722,42,756],focus_m=[590,11,554])
views["shrine"].update(label="山间神社 · 参道与院落",eye_m=[762,99,111],focus_m=[685,50,21])
chart["viewpoints"] += [
    dict(id="upland",label="山路 · 气象站与远眺",eye_m=[703,177,-128],focus_m=[527,90,-209]),
    dict(id="shrine_walk",label="神社参道 · 鸟居石阶",eye_m=[670,61,68],focus_m=[684,51,14]),
    dict(id="camp_court",label="帐篷驻扎场与小楼",eye_m=[439,72,392],focus_m=[374,28,330]),
    dict(id="camp_canvas",label="驻扎场 · 帆布与木屋",eye_m=[360,34,345],focus_m=[347,27,322]),
    dict(id="wood_court",label="岛镇 · 日式木构院落",eye_m=[932,57,569],focus_m=[855,14,495]),
    dict(id="wood_gate",label="木构主厅 · 廊檐与瓦顶",eye_m=[859,22,542],focus_m=[855,16,476])]
# Conservative rotated bounds feed the existing terrain / overlap test API, while
# the exterior uses the uninflated authored footprint. The latter stays in the same chart.
for row in chart["objects"]:
    if "heading_rad" not in row: continue
    w,h,d = row["size_m"]
    angle=row["heading_rad"]
    ca,sa=abs(cos(angle)),abs(sin(angle))
    row["visual_size_m"]=[w,h,d]
    row["size_m"]=[round(w*ca+d*sa,3),h,round(w*sa+d*ca,3)]
(root/"data/maps/qj04_island.json").write_text(json.dumps(chart,ensure_ascii=False,separators=(",",":"))+"\n")
print("QJ04 roads",len(chart["roads"]),"civil frontage",sum(p["id"].startswith("civil_") for p in chart["objects"]))
