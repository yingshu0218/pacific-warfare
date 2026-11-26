#!/usr/bin/env python3
"""Rebuild private CV02 layout candidates. Does not register any runtime unit."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "naval/shokaku_1941_08_23/data"

def write(name, value):
    (OUT / (name + ".json")).write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n")

def rectangle(x0, x1, z0, z1):
    return [[x0, z0], [x1, z0], [x1, z1], [x0, z1]]

def main():
    OUT.mkdir(parents=True, exist_ok=True)
    # M01 p2: continuous narrowing ahead of the forward elevator, NOT an
    # equal-width rectangle with clipped bow corners. All users read this one
    # polygon: fixed top mesh, bearing queries, lanes, clearances and tests.
    outline = [[-11.3,-117.0],[9.8,-117.0],[11.1,-97.0],[12.5,-70.0],
               [13.6,-55.0],[14.0,-30.0],[14.0,116.8],[10.0,125.2],
               [-11.2,125.2],[-15.0,117.0],[-15.0,-36.0],[-14.4,-57.0],[-13.2,-85.0]]
    deck = {
        "schema_version": "0.1", "ship_id": "jp_shokaku_1941_08_23",
        "configuration_date": "1941-08-23",
        "source_status": "S01 dated Shokaku photo + M01 model-manufacturer layout; P01 historical plan particulars. Ratios reconstructed, not as-built surveyed coordinates. See modeling-brief.md; 1944 full configuration NOT represented.",
        "axes": {"right":"+X","up":"+Y","forward":"-Z", "origin":"257.5m overall hull midpoint at trial-condition waterline (mean draught 8.87m)","scale":[1,1,1]},
        "flight_deck": {"height_m":14.15,"thickness_m":0.35,"boundary_xz_m":outline,
                        "nominal_length_m":242.2,"nominal_max_width_m":29.0,
                        "height_source_status":"P01 p3 plan 14.15m above trial waterline; cross-checked against S01. Reconstructed visible surface, not precision surveyed as-built height."},
        "obstacles": [
            {"id":"island_fore_mast","polygon_xz_m":rectangle(10.4,19.2,-52.8,-29.5),"bottom_m":14.15,"top_m":32.0,"host_id":"island"},
            {"id":"starboard_exhaust_clearance","polygon_xz_m":rectangle(13.35,22.1,-24.8,3.8),"bottom_m":9.0,"top_m":14.4,"host_id":"funnels"},
        ],
        "reference_lines":[
            {"id":"takeoff_axial","kind":"takeoff","points_m":[[0,14.15,51],[0,14.15,-115]],"half_width_m":6.2,"source_status":"geometric axial reference only; no catapult; OPS selects run/wind/occupancy"},
            {"id":"landing_axial","kind":"landing","points_m":[[0,14.15,123],[0,14.15,54],[0,14.15,-18]],"half_width_m":6.2,"source_status":"axial reference; elevators must be raised; landing and parking are mutually exclusive"},
        ],
        "zones":[
            {"id":"forward_park","kind":"parking","polygon_xz_m":rectangle(-10.5,9.0,-99,-65),"height_m":14.15,"requires_folded_wings":False},
            {"id":"mid_park","kind":"parking","polygon_xz_m":rectangle(-10.5,8.5,-17,9),"height_m":14.15,"requires_folded_wings":False},
            {"id":"aft_park","kind":"parking","polygon_xz_m":rectangle(-10.5,9.5,48,68),"height_m":14.15,"requires_folded_wings":False},
            {"id":"bow_hold","kind":"holding","polygon_xz_m":rectangle(-9,9,-111,-101),"height_m":14.15,"requires_folded_wings":False},
            {"id":"landing_exit","kind":"exit","polygon_xz_m":rectangle(-10,8,-17,9),"height_m":14.15,"requires_folded_wings":False},
        ],
        "elevators":[
            {"id":k,"center_xz_m":[0,z],"size_xz_m":[w,13.0],"upper_height_m":14.15,"lower_height_m":4.0,
             "intermediate_height_m":8.95,"translation_axis":[0,1,0],"node_path":"FlightDeck/Elevators/"+k,
             "opening":"inboard","corner_radius_m":0.0,
             "source_status":"M01 layout-ratio centre; reported platform size, transverse x longitudinal. Travel limits approximate hangar-floor reconstruction; no interior circulation claim."}
            for k,z,w in [("elevator_forward",-43.5,16.0),("elevator_middle",29.0,12.0),("elevator_aft",84.5,12.0)]
        ],
        "paths":[
            {"id":"holding_to_axial","kind":"holding","points_m":[[0,14.15,58],[0,14.15,6],[0,14.15,-95]],"half_width_m":6.2},
            {"id":"axial_exit","kind":"exit","points_m":[[0,14.15,45],[0,14.15,8],[0,14.15,-10]],"half_width_m":6.2},
        ],
        "arresting_wires":[
            {"id":f"reconstructed_wire_{i+1:02d}","points_m":[[-12.0,14.31,z],[11.5,14.31,z]],
             "source_status":"V1 functional reconstruction, NOT verified individual historical station or total. M01 p4 shows transverse wires; A11 pp18-20 explains contemporary IJN gear. Nine visible candidate wires clear all lift openings.",
             "historical_station_verified":False}
            for i,z in enumerate([74.0,66.0,58.0,50.0,42.0,18.0,10.0,2.0,-6.0])
        ],
        "barriers":[
            {"id":"reconstructed_bridge_barrier","points_m":[[-12.0,14.17,-24.0],[10.0,14.17,-24.0]],
             "source_status":"Lowered barrier sill only. M01 p4 and A11 p20 support general installation; exact Shokaku 1941 station remains a functional estimate.","historical_station_verified":False}
        ],"catapults":[],
        "arresting_equipment_status":{"historical_confirmed":"Transverse arresting wires and crash barriers are shown in Shokaku M01 reconstruction; original USNTMJ A11 pp18-20 confirms IJN cross-deck arresting system and early electric Kure versus later hydraulic types.",
            "historical_uncertain":"Selected primary source does not establish Shokaku 1941 exact wire count, Type4 identification or individual station coordinates; published secondary counts disagree (9 / 10). No claim that the game nine are the historical total.",
            "game_fit":"9 visible transverse wire segments at 0.16m above deck, one lowered barrier sill. Functional coordinate reconstruction with no arresting dynamics. OPS01 must validate aircraft hook / wire engagement separately."},
        "unverified_equipment":"Exact historical wire/barrier stations and arresting-engine internals unresolved. Wire geometry is explicitly functional reconstruction; no catapult or completed recovery claim."
    }
    mounts = []
    platforms = []
    for side,sign in [("starboard",1),("port",-1)]:
        for idx,z in enumerate([-76.5,-58.0,50.5,68.5]):
            sid = f"dp_{side}_{idx+1:02d}"
            y = 10.45 if idx<2 else 10.85
            mounts.append({"id":sid,"kind":"type89_smoke" if side=="starboard" and idx>=2 else "type89_open",
                "role":"dual_purpose","interface_id":"cv02_type89_127mm_twin","barrels":2,
                "position_m":[sign*15.15,y,z],"base_yaw_deg":-90*sign,
                "host_id":"sponson_"+sid,"foundation_height_m":0.12,"foundation_radius_m":1.7,
                "placement_status":"S01/M01 p2-p4 group and side established; centres ratio reconstruction ±1.5m longitudinal / ±0.6m vertical; port hidden face approximate"})
            platforms.append({"id":"sponson_"+sid,"station_id":sid,"center_m":[sign*14.5,y,z],
                              "size_xz_m":[9.0,9.2],"thickness_m":0.40,"kind":"dp", "hull_connection_x_m":sign*11.3})
    # Dedicated light AA is an explicitly reduced game fit. Only existing gallery
    # positions are used; historical twelve triples remain a separate record.
    for idx,(side,sign,z) in enumerate([("port",-1,5), ("port",-1,18), ("port",-1,31), ("port",-1,44),
                                      ("starboard",1,15), ("starboard",1,28)]):
        sid = f"aa25_{side}_{idx+1:02d}"
        y = 12.25
        mounts.append({"id":sid,"kind":"type96_smoke" if sign>0 else "type96_open", "role":"light_aa",
            "interface_id":"cv02_type96_25mm_triple","barrels":3,"position_m":[sign*15.45,y,z],
            "base_yaw_deg":-90*sign,"host_id":"gallery_"+sid,"foundation_height_m":0.08,"foundation_radius_m":0.7,
            "placement_status":"M01 gallery geometry; reduced dedicated-AA game fit; exact historical individual station centres not claimed"})
        platforms.append({"id":"gallery_"+sid,"station_id":sid,"center_m":[sign*14.5,y,z],
                          "size_xz_m":[6.6,5.0],"thickness_m":0.25,"kind":"light_aa", "hull_connection_x_m":sign*11.3})
    # Conservatively reserve the full raised-gun envelope, and the source-
    # visible radio masts. These obstacles accompany the existing island/
    # exhaust prisms; no invisible aircraft snapping or path-finding here.
    for mount in mounts:
        x,y,z = mount["position_m"]
        if mount["role"]=="dual_purpose":
            x0,x1 = (11.3,20.2) if x>0 else (-20.2,-11.3)
            half_z,top = 5.4,y+0.12+1.42+3.8
        else:
            x0,x1 = (13.9,18.0) if x>0 else (-18.0,-13.9)
            half_z,top = 2.5,y+0.08+0.95+1.55
        deck["obstacles"].append({"id":"maximum_envelope_"+mount["id"],"polygon_xz_m":rectangle(x0,x1,z-half_z,z+half_z),
            "bottom_m":y,"top_m":round(top,3),"host_id":mount["host_id"],
            "source_status":"Conservative installed weapon-motion envelope; actual yaw/elevation remains independent"})
    for i,(x,z) in enumerate([(-15.1,36.0),(-15.1,61.5),(14.2,88.0)]):
        deck["obstacles"].append({"id":f"radio_mast_{i+1}","polygon_xz_m":rectangle(x-1.4,x+1.4,z-.3,z+.3),
            "bottom_m":14.15,"top_m":22.65,"host_id":"equipment","source_status":"Visible upright mast; folding mechanism is outside CV02 v1"})
    write("deck",deck)
    assembly = {"configuration_date":"1941-08-23", "ship_id":deck["ship_id"],"overall_length_m":257.5,
        "waterline_length_m":250.0,"waterline_beam_m":26.0,"trial_mean_draught_m":8.87,
        "source_ids":["S01","S02","S05","S11-proxy","S15-proxy","P01-p3,p7","M01-p2,p3,p4"],
        "mounts":mounts,"platforms":platforms,
        "historical_dedicated_aa":[{"weapon":"Type96 25mm triple","mounts":12,"barrels_total":36,"source":"P01 p7 original plan table; M01 p1"}],
        "game_dedicated_aa":[{"weapon":"Type96 25mm triple","mounts":6,"barrels_total":18,"reason":"V1 simplified gallery fit uses a subset of source-backed side locations; not a historical complete 1941 AA reconstruction"}],
        "collision_proxies":[{"id":"hull","shape":"box","center_m":[0,3.0,0],"size_m":[26.0,12.0,245.0]},
            {"id":"upper_hangar","shape":"box","center_m":[0,11.2,4],"size_m":[23,5.4,205]},
            {"id":"island","shape":"box","center_m":[14.6,18.4,-40],"size_m":[7,9,17]}],
        "collision_status":"coarse candidate solids only; exact deck is deck.json polygon/elevators/obstacles; S14 must adapt before registration"}
    write("assembly",assembly)
    write("unit_candidate",{"schema_version":1,"id":deck["ship_id"],"display_name":"翔鹤 / Shokaku · 1941-08-23", "country_id":"jp","domain":"ship","service_entry_year":1941,"configuration_date":"1941-08-23", "dimensions_m":[38.0,40.87,257.5],"model_scene":"res://naval/shokaku_1941_08_23/shokaku.tscn", "candidate_only":True,"registration_status":"NOT REGISTERED; S14 owns live integration", "historical_era":"1941 ship; A6M5a 1944 deck-fit fixture is deliberately cross-era", "deck_definition":"res://naval/shokaku_1941_08_23/data/deck.json"})
    print("CV02 private layout rebuilt: 8 fixed twins, 6 dedicated-AA game mounts, 3 elevators")

if __name__ == "__main__":
    main()
