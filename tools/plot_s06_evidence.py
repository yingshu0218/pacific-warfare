#!/usr/bin/env python3
"""Plot saved simulation tracks (not rendered-scene or browser evidence)."""
from __future__ import annotations

import json
import math
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/showcase/evidence/S06"


def font(size: int):
    return ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial.ttf", size)


def canvas(title: str, subtitle: str):
    im = Image.new("RGB", (1200, 840), "#f9fafb")
    draw = ImageDraw.Draw(im)
    draw.text((40, 25), title, font=font(26), fill="#152536")
    draw.text((40, 66), subtitle, font=font(16), fill="#516273")
    return im, draw


def axes(draw, bounds, box=(95, 125, 925, 740)):
    xmin, xmax, zmin, zmax = bounds
    left, top, right, bottom = box
    scale = min((right-left)/(xmax-xmin), (bottom-top)/(zmax-zmin))
    left += ((right-left)-(xmax-xmin)*scale)/2
    def point(x, z):
        return left+(x-xmin)*scale, top+(z-zmin)*scale
    for i in range(6):
        x = xmin+(xmax-xmin)*i/5
        z = zmin+(zmax-zmin)*i/5
        px, _ = point(x, zmin)
        _, pz = point(xmin, z)
        draw.line((px, top, px, point(xmin,zmax)[1]), fill="#d8e0e7", width=1)
        draw.line((left,pz,point(xmax,zmin)[0],pz), fill="#d8e0e7", width=1)
        draw.text((px-15,point(xmin,zmax)[1]+10), f"{x/1000:.1f}", font=font(14), fill="#516273")
        draw.text((left-48,pz-8), f"{z/1000:.1f}", font=font(14), fill="#516273")
    draw.text((left, 95), "+Z km (down on this top-view chart)", font=font(14), fill="#516273")
    draw.text((left, 800), "+X km  |  all paths use saved fixed-tick simulation coordinates", font=font(16), fill="#516273")
    return point


def combined():
    data = json.loads((OUT/"combined_witness.json").read_text())
    im, draw = canvas("S06 | Combined-arms tracks", "4 ships / 8 aircraft; default formal combat parameters; 120 simulation seconds; samples every 5 seconds")
    all_positions = [u["position_m"] for sample in data["tracks_5s"] for u in sample["units"].values()]
    xmin = math.floor(min(p[0] for p in all_positions)/1000)*1000-500
    xmax = math.ceil(max(p[0] for p in all_positions)/1000)*1000+500
    zmin = math.floor(min(p[2] for p in all_positions)/1000)*1000-500
    zmax = math.ceil(max(p[2] for p in all_positions)/1000)*1000+500
    point = axes(draw, (xmin, xmax, zmin, zmax))
    for id in data["tracks_5s"][0]["units"]:
        aircraft = "fighter" in id
        color = ("#ed9b97" if aircraft else "#bb3c39") if id.startswith("jp") else ("#9dbcf4" if aircraft else "#285aa1")
        positions = [sample["units"][id]["position_m"] for sample in data["tracks_5s"]]
        pixels = [point(p[0],p[2]) for p in positions]
        draw.line(pixels, fill=color, width=2 if aircraft else 4)
        for pixel in [pixels[0],pixels[-1]]:
            x,z = pixel
            draw.ellipse((x-4,z-4,x+4,z+4), fill=color)
    for y, color, label in [(140,"#bb3c39","JP ships"),(175,"#285aa1","US ships"),(210,"#ed9b97","JP aircraft"),(245,"#9dbcf4","US aircraft")]:
        draw.line((965,y+9,995,y+9),fill=color,width=4)
        draw.text((1005,y),label,font=font(16),fill="#152536")
    lines = [f"{data['counts']['fired']} fired", f"{data['counts']['hit']} first hits", f"{data['counts']['airburst']} AA bursts", f"{len(data['orders'])} high-level orders", "No forced results", "No rendering claim"]
    for index,line in enumerate(lines):
        draw.text((965,320+index*32),line,font=font(16),fill="#516273")
    im.save(OUT/"combined_tracks.png")


def shoreline():
    data = json.loads((OUT/"ship_motion.json").read_text())["shore"]
    im, draw = canvas("S06 | Real shoreline detour", "Same hull motion, finite turn radius and braking; static island box; saved track every 10 seconds")
    point = axes(draw, (-1400, 1400, -4600, 200))
    a,b = point(-350,-1850),point(350,-1150)
    draw.rectangle((*a,*b),fill="#dbd5b7",outline="#776e48",width=2)
    draw.text((a[0]+10,a[1]+20),"Island",font=font(16),fill="#514b33")
    pixels = [point(p[0],p[2]) for p in data["track_10s"]]
    draw.line(pixels,fill="#285aa1",width=4)
    for xy, color in [(pixels[0],"#238658"),(pixels[-1],"#bb3c39")]:
        x,z=xy
        draw.ellipse((x-5,z-5,x+5,z+5),fill=color)
    for y,label in [(140,"Blue: actual path"),(175,"Green: start"),(210,"Red: last sample"),(275,"No position snapping"),(310,"No coast intersection")]:
        draw.text((965,y),label,font=font(16),fill="#516273")
    im.save(OUT/"shore_track.png")


if __name__ == "__main__":
    combined()
    shoreline()
    print("Saved combined_tracks.png and shore_track.png from simulation evidence")
