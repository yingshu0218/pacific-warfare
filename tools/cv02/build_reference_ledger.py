#!/usr/bin/env python3
"""Attach CV02's manually inspected roles/limitations to downloaded originals."""
import hashlib
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
REF=ROOT/"docs/references/ships/shokaku_1941_08_23"
ROLES={
 "S01":("Shokaku, 1941-08-23, Yamato Museum collection; unknown photographer", "starboard broadside, complete hull", "main photograph", "Whole silhouette, low forward island, separate downturned funnels, fore/aft grouped DP batteries, open end supports", "No hidden port positions, elevator planform or 1944 changes", "Historic Japanese photo; Commons page marks PD-Japan-oldphoto. Reference only, never runtime texture"),
 "S02":("Shokaku, same date, NH73066", "same starboard broadside as S01", "duplicate auxiliary", "NHHC identity/date cross-check and alternate tonal scan", "Not a second angle and not an independent photograph", "NHHC donor reproduction; Commons file-page rights retained; no new rights asserted"),
 "S03":("Shokaku, 1942-05-08, USN 80-G-17422", "distant low oblique under attack", "excluded from precise geometry", "Only gross contemporary low silhouette", "Small ship, smoke and splashes obscure most equipment; not high-angle gun-position evidence", "Official US Navy photograph, public domain in US"),
 "S04":("Shokaku, 1942-05-08, USN", "distant low oblique, with aircraft edge", "excluded from precise geometry", "Cross-check general ship silhouette", "Heavy obscuration; not full top view, not 1941 fit proof", "Official US Navy photograph, public domain in US"),
 "S05":("NH111729 USN recognition sheet, class labeled Shokaku/Zuikaku; 1939-1945", "photos of recognition models: high starboard bow and stern; side/plan diagrams", "class recognition model auxiliary", "Three-dimensional gross ship/hangar/island/funnel relationships", "MODEL, not an actual ship photograph; mixed simplified recognition drawings cannot establish exact AA count, elevator or hull dimensions", "Naval History and Heritage Command; US government work / Commons public-domain record"),
 "S06":("Captured Japanese carrier photo, reportedly Shokaku, 1941-12-07; USN/NARA holding", "on-deck looking over parked aircraft", "local deck surface auxiliary", "Relative aircraft/deck scale, clear broad deck and operations context", "Identity/date qualified in source; deck largely occupied; not a whole-ship angle or A6M5a identity", "Commons PD-Japan-oldphoto record; source caption retains 'reportedly'"),
 "S07":("Shokaku, 1942-05-08, USN", "distant low side under attack", "excluded from precise geometry", "Gross silhouette only", "Not a high deck image; spray hides ship equipment", "Official US Navy photograph, public domain in US"),
 "S08":("Photographed FROM Shokaku by Hanzo Mori, 1943-03-17; Arashi in background", "local aft deck-edge support, framing heavily cropped", "later local structure auxiliary", "Support beam/edge appearance only", "Filename 19430318 differs from page caption March17; not whole ship and not 1941 equipment fit", "Historic Japanese photograph; file-page rights retained; no use as runtime texture"),
 "S09":("Shokaku, 1942-05-08, USN 80-G-17031", "distant port-side attack view", "excluded from precise geometry", "Gross contemporary silhouette only", "Bow fire and spray hide details; not a usable top plan", "Official US Navy photograph, public domain in US"),
 "S10":("Shokaku attack sequence, 1942-05-08, USN", "three distant low oblique photos in montage", "excluded from angle coverage", "Sequence context only", "Not three independent full ship angles; equipment remains unreadable", "Official US Navy photographs, public domain in US"),
 "S11":("ZUIKAKU, 1941-09-25 at Kobe, NH73067", "complete starboard bow oblique", "explicit sister-ship proxy", "Common flared/raked bow, open forward underdeck, broad hangar/flight deck relationship", "Different ship/yard/date; do not copy island equipment, exact platform positions, markings or detailed shape without S01/M01 cross-check", "Historic Japanese photograph / NHHC reproduction; Commons PD-Japan-oldphoto record"),
 "S12":("Shokaku, 1942-05-08, USN 80-G-17027; NHC archive mirror", "distant side view during starboard turn", "excluded from precise geometry", "Verified USN archive identity and gross silhouette", "Small subject and splashes; cannot supply missing high-view geometry", "Official US Navy photograph, public domain in US"),
 "S13":("Shokaku, 1942-05-08, USN 80-G-17030; NHC archive mirror", "distant side / spray", "excluded from precise geometry", "Attack context only", "Not a plan or exact station reference", "Official US Navy photograph, public domain in US"),
 "S14":("ZUIKAKU and two destroyers, 1944-06-20, USN 80-G-238025", "distant higher oblique during turn", "explicit later sister-ship proxy, low usefulness", "Common deck/hull relationship only where visible", "Smoke hides deck; no 1941 armament, camouflage, platform or exact layout inference", "Official US Navy photograph, public domain in US"),
 "S15":("ZUIKAKU, 1944-10-25, NH95785 / All Hands Dec1944 p4", "high aft oblique; stern deck clear, forward part smoke-covered", "explicit later sister-ship proxy", "Aft flight-deck taper, visible elevator aperture/surface and deck-edge relationship", "Front obscured; later widened platforms/AA/camouflage not transferred; not complete 1941 Shokaku top photography", "Official US Navy photograph, public domain in US"),
 "P01":("航空母艦一般計画要領書附現状調査, historic plan-particulars scan", "tables: PDF p3 dimensions and p7 ordnance; p11 inspected but not used", "primary numerical constraints", "257.5m overall, 250m waterline, 26m trial beam, 8.87m trial draught, flight-deck plan height 14.15m, eight twin 127mm and twelve triple 25mm", "Plan column is not surveyed as-built layout. 247.2m deck length / 29.5m width differs from as-completed reconstruction 242.2m / 29.0m; exact hidden forms and stations not established", "Historic Japanese naval document hosted by 海軍砲術学校; scanned research source, no runtime redistribution"),
 "M01":("Tamiya 31213 Shokaku 1941 kit instruction, 1993", "all four original PDF pages inspected: side/top and exploded assemblies", "model-manufacturer reconstruction auxiliary", "Major platform groupings, forward deck taper, three elevators, 2 aft starboard smoke hoods versus 6 open DP mounts, downturned funnels", "Not a shipyard plan or primary historical proof; flattened/model simplifications and exact station/height precision remain limited", "Copyright Tamiya 1993; private research reference only, no game texture/asset or public-pack inclusion"),
 "P02":("US Naval Technical Mission to Japan A-11, Jan1946 / transmittal Feb4", "original PDF pp20-22 (printed18-20) read; pp23-24 seen but not used", "primary period-equipment semantics", "IJN cross-deck arresting wires and barriers, early electric Kure versus later hydraulic gear, 160mm wire height description; Table II consulted for SUISEI-12 dimension cage", "Not a Shokaku1941 station plan. Table III omits Shokaku. Do not infer exact wire count, Type4 fit, performance or 1944 configuration. Table particulars contain legacy inconsistencies", "Official US government report; public domain in US; historical 'restricted' marking is source context, not a current classification claim"),
}

def main():
    rows=json.loads((REF/"download-manifest.json").read_text())
    for row in rows:
        identity,angle,status,use,limits,rights=ROLES[row["id"]]
        row.update(identity=identity,view=angle,status=status,can_use=use,cannot_use=limits,rights=rights,
                   inspected_original=True,inspection_date="2026-11-11",runtime_asset=False)
    data={"task":"CV02","configuration_date":"1941-08-23","ship":"Shokaku, not Zuikaku", "sources":rows,
          "coverage_gap":"No selected actual Shokaku 1941 complete high/strict top photo or unobscured stern-quarter original was obtained. Those geometry judgements combine dated broadside, numerical constraints and explicitly limited manufacturer/recognition/sister-ship references. This gap is NOT marked verified.",
          "sha256_algorithm":"SHA-256; unchanged original downloads listed individually; no AI target is historical evidence"}
    (REF/"sources.json").write_text(json.dumps(data,ensure_ascii=False,indent=2)+"\n")
    print("CV02 ledger:",len(rows),"inspected originals, with excluded and proxy roles retained")

if __name__=="__main__": main()
