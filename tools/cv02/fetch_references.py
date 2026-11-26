#!/usr/bin/env python3
"""Download unchanged CV02 public references; records hashes and retrieval URLs.

These are research inputs, never runtime textures. Run with network permission.
"""
from pathlib import Path
import hashlib
import html
import json
import re
import urllib.request

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "docs/references/ships/shokaku_1941_08_23/original"
COMMONS = {
    "S01": "Japanese_aircraft_carrier_shokaku_1941.jpg",
    "S02": "Aircraft_carrier_shokaku_h73066.jpg",
    "S03": "Shokaku_under_attack_8_May_1942.jpg",
    "S04": "Shokaku_under_attack_8_May_1942B.jpg",
    "S05": "NH_111729_World_War_II_Japanese_aircraft_carriers_of_SHOKAKU_Class_(SKOKAU,_ZUIKAKU).jpg",
    "S06": "Carrier_shokaku.jpg",
    "S07": "Shokaku_attacked_in_Coral_sea.jpg",
    "S08": "Shokaku-19430318-1.png",
    "S09": "BattleCoralSea_Shokaku_g17031.jpg",
    "S10": "Japanese_carrier_Shokaku_under_attack_at_Coral_Sea_1942.jpg",
    "S11": "Japanese.aircraft.carrier.zuikaku.jpg",
    "S14": "Japanese_aircraft_carrier_Zuikaku_and_two_destroyers_under_attack_on_20_June_1944_(80-G-238025).jpg",
    "S15": "Japanese_carrier_under_attack_during_Battle_off_Cape_Engaño_1944.jpg",
}
DIRECT = {
    "P01": "https://navgunschl2.sakura.ne.jp/tenji/zoukou/shipsdata_ijn_cv_orig.pdf",
    "M01": "https://d37tikmwcb2tc.cloudfront.net/plastic_models/file_attachment/Tamiya%2031213.pdf",
    "S12": "https://www.ibiblio.org/hyperwar/OnlineLibrary/photos/images/g10000/g17027.jpg",
    "S13": "https://www.ibiblio.org/hyperwar/OnlineLibrary/photos/images/g10000/g17030.jpg",
    "P02": "https://www.fischer-tropsch.org/primary_documents/gvt_reports/USNAVY/USNTMJ%20Reports/USNTMJ-200A-0560-0608%20Report%20A-11.pdf",
}

def get(url):
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 CV02 historical-model research"})
    with urllib.request.urlopen(req, timeout=45) as response:
        return response.read()

def main():
    OUT.mkdir(parents=True, exist_ok=True)
    manifest = []
    for key, name in COMMONS.items():
        page = "https://commons.wikimedia.org/wiki/File:" + urllib.parse.quote(name)
        page_path = OUT / (key + "-page.html")
        page_bytes = page_path.read_bytes() if page_path.exists() else get(page)
        page_path.write_bytes(page_bytes)
        match = re.search(r'class="fullImageLink"[^>]*>\s*<a href="([^"]+)"', page_bytes.decode())
        if not match:
            raise RuntimeError("No original link " + key)
        url = html.unescape(match.group(1))
        path = OUT / (key + (".png" if name.endswith(".png") else ".jpg"))
        if not path.exists():
            path.write_bytes(get(url))
        manifest.append({"id": key, "page_url": page, "original_url": url,
                         "file": str(path.relative_to(ROOT)), "sha256": hashlib.sha256(path.read_bytes()).hexdigest()})
        print(key, path.stat().st_size, flush=True)
    for key, url in DIRECT.items():
        path = OUT / (key + (".jpg" if url.endswith(".jpg") else ".pdf"))
        if not path.exists():
            path.write_bytes(get(url))
        manifest.append({"id": key, "original_url": url, "file": str(path.relative_to(ROOT)),
                         "sha256": hashlib.sha256(path.read_bytes()).hexdigest()})
        print(key, path.stat().st_size, flush=True)
    (OUT.parent / "download-manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2)+"\n")

if __name__ == "__main__":
    main()
