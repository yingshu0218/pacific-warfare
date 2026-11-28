"""Build the deterministic Qingjia geography edition from the existing MAP02 chart."""
import json
from math import cos, pi, sin
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / "data/maps/island_harbor_expanded.json"
OUT = ROOT / "data/maps/qj02_geography.json"
BASE_SCENARIO = ROOT / "data/scenarios/s14_expansion_harbor.json"
OUT_SCENARIO = ROOT / "data/scenarios/qj02_geography.json"


def ridge(id_, label, center_x, center_z, width, half_length, bend, crest, phase):
    """Make a star-shaped island outline for the engine's radial terrain mesher."""
    outline = []
    for k in range(64):
        angle = k * 2 * pi / 64
        s, c = sin(angle), cos(angle)
        waviness = 1 + 0.10*cos(3*angle + phase) + 0.09*sin(5*angle + phase) + 0.045*cos(11*angle)
        x = center_x + width*c*waviness + bend*s
        z = center_z + half_length*s*waviness
        outline.append([round(x, 2), 0, round(z, 2)])
    peaks = []
    for offset, shift, height, radius in [(-990, -100, 0.77, 995), (-270, 55, 1.0, 1030), (850, -70, 0.82, 1040)]:
        pos = [round(center_x + shift + bend*offset/half_length, 2), 0, center_z + offset]
        peaks.append({"position_m": pos, "height_m": round(crest*height, 2), "radius_m": radius})
    return {"id": id_, "label": label, "center_m": [center_x, 0, center_z], "outline_m": outline, "peaks": peaks, "rings": 28}


def camera(id_, label, xyz, distance, yaw, pitch):
    return {"id": id_, "label": label, "focus_m": xyz, "distance_m": distance, "yaw_rad": yaw, "pitch_rad": pitch}


def write_map(source):
    # One entry per item for source diff readability; no duplicated subfield whitespace.
    lines = []
    for key, value in source.items():
        encoder = lambda v: json.dumps(v, ensure_ascii=False, separators=(",", ":"), sort_keys=True)
        if isinstance(value, list) and value and isinstance(value[0], dict):
            lines.append(f"  {encoder(key)}: [\n" + ",\n".join("    " + encoder(v) for v in value) + "\n  ]")
        else:
            lines.append(f"  {encoder(key)}: {encoder(value)}")
    OUT.write_text("{\n" + ",\n".join(lines) + "\n}\n", encoding="utf-8")


def main():
    chart = json.loads(BASE.read_text(encoding="utf-8"))
    chart["id"] = "qj02_geography"
    chart["label"] = "青岬群岛 · 峡湾港城"
    chart["authorship"] = "Fictional geography edition derived from project MAP02. The same chart feeds Godot visuals and simulation."
    # Build a connected, irregular west headland into the north shore. Keep
    # the harbor frontage and existing roads/island identity; the changed
    # radial center keeps both the inlet's concave corner and apron in view.
    north = next(island for island in chart["islands"] if island["id"] == "north_east")
    assert north["outline_m"][18][0] == 1962.59
    west_headland = [
        (1930,-4410),(1890,-4180),(1860,-3850),(1825,-3450),
        (1770,-3000),(1685,-2540),(1570,-2000),(1405,-1410),
        (1220,-850),(1000,-645),(805,-740),(720,-1080),
        (640,-1510),(610,-1950),(615,-2450),(690,-2950),
        (810,-3500),(1010,-4060),(1210,-4490),(1425,-4830),(1570,-5150),
    ]
    north["center_m"] = [2000, 0, -5725]
    north["rings"] = 58
    north["outline_m"] = north["outline_m"][:19] + [[x, 0, z] for x,z in west_headland] + north["outline_m"][22:]
    for x, z, height, radius in [(1080,-1720,615,975),(1300,-2580,690,1060),(1250,-3650,520,920),(1380,-4200,215,700)]:
        north["peaks"].append({"position_m": [x,0,z], "height_m": height, "radius_m": radius})
    # Across the water, a shorter diagonal island creates an uneven opening.
    chart["islands"].append(ridge("fjord_east", "东翼双峰岛", 4780, -2410, 720, 1420, 330, 684, 2.3))
    chart["viewpoints"] = [
        camera("qj02_overview", "群岛全景", [620, 10, -300], 20700, -.06, 1.27),
        camera("qj02_fjord", "峡湾入口", [3150, 110, -3150], 5720, -.14, .26),
        camera("qj02_harbor", "军港与驻泊舰", [3250, 13, -4230], 1280, .10, .49),
        camera("qj02_airfield", "东岬机场", [6680, 9, -2470], 1490, .63, .43),
        camera("qj02_town", "小镇与渡口", [2220, 30, -4870], 610, .93, .43),
        camera("qj02_market", "主街与居民", [2230, 49, -4918], 82, 1.49, .14),
        camera("qj02_berth", "驻泊舰近景", [2650, 15, -3980], 460, .73, .19),
    ] + chart["viewpoints"]
    write_map(chart)

    scenario = json.loads(BASE_SCENARIO.read_text(encoding="utf-8"))
    scenario["id"] = "qj02_geography"
    scenario["environment"]["terrain_path"] = "res://data/maps/qj02_geography.json"
    scenario["environment"]["view_script"] = "res://scripts/qingjia/geography_view.gd"
    scenario["presentation"]["title"] = "青岬群岛 · 海陆空试玩"
    scenario["presentation"]["subtitle"] = "虚构的太平洋群岛。军港藏在峡湾深处，东岬机场与沿岸居民小镇同图呈现。"
    OUT_SCENARIO.write_text(json.dumps(scenario, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
