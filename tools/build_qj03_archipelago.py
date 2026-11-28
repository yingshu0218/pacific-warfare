#!/usr/bin/env python3
"""Author a compact fictional island chart. No dependency on an earlier map."""
import json
from math import atan2, cos, exp, pi, sin
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "data/maps/qj03_archipelago.json"


def outline(rx, rz, count, center, phase, main=False):
    points = []
    for i in range(count):
        a = i * 2 * pi / count
        def lobe(at, width):
            return exp(-(atan2(sin(a-at),cos(a-at))/width)**2)
        t = 1 + .065*sin(3*a+.3+phase) + .037*cos(7*a+1.2+phase) + .019*sin(14*a+.8+phase)
        if main:
            t += -.27*lobe(.18,.22)+.16*lobe(-.16,.21)+.12*lobe(.48,.21)+.09*lobe(1.55,.45)-.14*lobe(2.2,.25)
        points.append([round(center[0]+rx*cos(a)*t,2),0,round(center[1]+rz*sin(a)*t,2)])
    return points


def island(key,label,rx,rz,center,phase,ring_count,peaks,main=False):
    return {"id":key,"label":label,"center_m":[center[0],0,center[1]],
            "outline_m":outline(rx,rz,144 if main else 56,center,phase,main),"rings":ring_count,
            "peaks":[{"position_m":[x,0,z],"height_m":h,"radius_m":r} for x,z,h,r in peaks]}


def feature(key,kind,x,y,z,w,h,d,color):
    return {"id":key,"kind":kind,"position_m":[x,y,z],"size_m":[w,h,d],"color":color}


def main():
    islands = [
        island("qingjia_main","青岬主岛",1430,1020,(0,0),0,49,[
            (-540,-350,264,540),(-206,-540,327,470),(242,-463,255,485),
            (682,-318,143,420),(-755,-102,165,392),(-1058,44,112,315),
            (430,270,64,365),(-551,198,51,340)],True),
        island("north_skerry","岬北岛",400,238,(474,-1540),.68,21,[
            (353,-1570,79,249),(593,-1509,48,166)]),
        island("lantern_islet","灯屿",240,170,(2050,600),1.9,17,[(2010,612,44,171)]),
        island("south_islet","南礁岛",314,216,(-635,1533),3.2,17,[
            (-738,1519,57,175),(-574,1540,72,190)]),
    ]
    pads = [{"id":f"airstrip_pad_{i}","position_m":[x,16,525],"radius_m":140,"blend_m":110}
            for i,x in enumerate(range(-790,411,150))]
    pads += [{"id":"harbor_apron","position_m":[1030,9,163],"radius_m":91,"blend_m":95},
             {"id":"airfield_hangars","position_m":[270,16,394],"radius_m":105,"blend_m":85},
             {"id":"town_north","position_m":[636,17,498],"radius_m":118,"blend_m":86},
             {"id":"town_south","position_m":[686,15,655],"radius_m":136,"blend_m":80},
             {"id":"harbor_inland","position_m":[977,12,255],"radius_m":67,"blend_m":70},
             {"id":"shrine_node","position_m":[590,44,225],"radius_m":15,"blend_m":48},
             {"id":"air_cargo","position_m":[125,16,390],"radius_m":65,"blend_m":64}]
    objects = [
        feature("quay_wall","quay",1124,-4,159,99,10,114,"7b9090"),
        feature("berth_north", "quay",1272,-4,82,228,10,31,"7c8783"),
        feature("berth_link", "quay",1160,-4,109,29,10,47,"858f86"),
        feature("service_pier","quay",1228,-3.6,146,139,8.8,29,"a7a195"),
        feature("outer_mooring","quay",1283,-3.7,134,34,8.9,49,"888f8c"),
        feature("floating_walk","quay",1179,-.7,203,54,1.55,8,"786758"),
        feature("marina_float_n","quay",1208,-.7,192,6,1.55,23,"786758"),
        feature("marina_float_s","quay",1195,-.7,214,5,1.55,22,"786758"),
        feature("shed_north","warehouse",1070,9,132,37,11,25,"bcc5bf"),
        feature("shed_south","warehouse",1065,9,183,34,9,22,"d6c4a7"),
        feature("harbor_office","house",1042,9,208,13,6,17,"e5d3b2"),
        feature("hangar_w","warehouse",212,16,392,47,11,28,"a8bab3"),
        feature("hangar_e","warehouse",282,16,392,47,11,28,"a7b0a6"),
        feature("workshop","house",350,16,392,27,6,23,"bda892"),
    ]
    objects += [
        feature("cargo_hall","warehouse",127,16,382,56,10,32,"adb4a5"),
        feature("crew_quarters_w","warehouse",209,16,332,35,7,18,"9ea58e"),
        feature("crew_quarters_e","warehouse",261,16,336,35,7,18,"a2a995"),
        feature("air_workshop","warehouse",317,16,333,40,8,22,"9faca6"),
        feature("harbor_workshop","warehouse",970,12,257,44,10,24,"aca79b"),
        feature("naval_store","warehouse",969,12,295,42,10,26,"a7af9f"),
        feature("port_office","house",1010,12,266,27,8,19,"b6ae99"),
        feature("port_crew","warehouse",1008,12,224,30,8,23,"a6ad96"),
        feature("shrine","house",590,44,225,17,7,12,"b5a187"),
        feature("cargo_store_a","warehouse",996,11,125,53,13,27,"a8af9f"),
        feature("cargo_store_b","warehouse",993,11,154,48,12,24,"aba08a"),
        feature("cargo_store_c","warehouse",948,11,187,48,14,27,"afb5a2"),
        feature("cargo_store_d","warehouse",941,11,224,45,12,26,"a2ab9f"),
        feature("hospital_main","warehouse",615,15,747,42,11,26,"dfd7b6"),
        feature("hospital_wing","warehouse",651,15,745,24,8,20,"d8cdb0"),
        feature("fire_station","warehouse",832,17,591,32,8,26,"d4bdaa"),
        feature("supply_store","warehouse",505,15,646,45,10,24,"b8a58a"),
        feature("waterside_stall","house",882,12,798,18,5,13,"ccbaa2"),
    ]
    for row,z in enumerate([503,546,628,671]):
        for col,x in enumerate([548,583,623,660,700,739,779,814]):
            if (row,col) in ((0,3),(1,5),(2,2),(3,6)):
                continue
            shift = ((row*19+col*11)%7)-3
            tint = ["d8c5aa","c7b28e","a89175","ccc5af","b5a990","d8c9a8"][(row+col*3)%6]
            objects.append(feature(f"civil_{row}_{col}","house",x+shift,16,z+(col%3)*2,16+(col%4)*2,5+(row+col)%3,14+(col+1)%4*2,tint))
    chart = {
        "id":"qj03_archipelago","label":"青岬群岛","sea_level_m":0,
        "bounds_m":[[-3350,0,-2470],[3520,0,2590]],
        "islands":islands,"pads":pads,"objects":objects,"deployment_sites":[],
        "features":{"runway":{"position_m":[-200,16,525],"size_m":[1160,.23,43]},
                    "taxi":{"position_m":[225,16,483],"size_m":[18,.23,58]},
                    "apron":{"position_m":[269,16,435],"size_m":[213,.24,68]}},
        "roads":[{"id":"harbor_airport_link","width_m":9,
                   "points_m":[[386,0,443],[487,0,454],[586,0,463],[686,0,470],[784,0,419],[875,0,343],[952,0,284],[1010,0,228],[1042,0,178]]},
                 {"id":"town_market","width_m":9,"points_m":[[509,0,585],[590,0,588],[688,0,588],[784,0,583],[853,0,580]]},
                 {"id":"town_house_row","width_m":5,"points_m":[[516,0,709],[617,0,709],[695,0,711],[790,0,707],[862,0,714],[881,0,797]]},
                 {"id":"town_cross_w","width_m":6,"points_m":[[565,0,461],[561,0,545],[561,0,591],[563,0,709]]},
                 {"id":"town_cross_e","width_m":7,"points_m":[[759,0,443],[759,0,543],[759,0,584],[759,0,705]]},
                 {"id":"public_hospital_path","width_m":5,"points_m":[[615,0,709],[613,0,744],[614,0,770],[664,0,770]]},
                 {"id":"public_fire_apron","width_m":12,"points_m":[[847,0,582],[850,0,614],[831,0,617],[795,0,617]]},
                 {"id":"public_supply_apron","width_m":7,"points_m":[[510,0,587],[481,0,620],[483,0,663],[522,0,664]]},
                 {"id":"shrine_approach","width_m":4,"points_m":[[759,0,470],[698,0,398],[651,0,340],[622,0,294],[590,0,267],[590,0,230]]}],
        "viewpoints":[
            {"id":"overview","label":"群岛总览","eye_m":[2130,1690,2570],"focus_m":[272,30,-41]},
            {"id":"airport","label":"机场","eye_m":[768,192,1005],"focus_m":[-163,30,500]},
            {"id":"harbor","label":"港口","eye_m":[1545,155,293],"focus_m":[1120,11,152]},
            {"id":"waterline","label":"双码头近景","eye_m":[1567,64,-52],"focus_m":[1207,15,132]},
            {"id":"town","label":"居民街区","eye_m":[1067,157,865],"focus_m":[660,22,625]},
            {"id":"shrine","label":"山腰神社","eye_m":[705,95,338],"focus_m":[588,44,224]},
            {"id":"above_clouds","label":"云层上方","eye_m":[2380,3260,3150],"focus_m":[100,0,-200]},
            {"id":"public_street","label":"民用公共街区","eye_m":[747,70,900],"focus_m":[666,18,664]},
            {"id":"public_hospital","label":"诊疗所与街角","eye_m":[655,30,805],"focus_m":[625,21,744]},
            {"id":"public_fire","label":"消防所","eye_m":[862,28,650],"focus_m":[832,22,594]},
            {"id":"public_supply","label":"民用物资仓","eye_m":[521,26,700],"focus_m":[506,20,648]},
        ],
    }
    OUT.write_text(json.dumps(chart,ensure_ascii=False,separators=(",",":"))+"\n")

if __name__=="__main__":
    main()
