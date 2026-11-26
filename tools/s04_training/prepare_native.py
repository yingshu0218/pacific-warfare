#!/usr/bin/env python3
"""Freeze only the existing runtime and training review inputs, without changing DM evidence."""
from pathlib import Path
import json,hashlib,shutil,datetime
ROOT=Path(__file__).resolve().parents[2]
STAGE=ROOT/'.local/s04-training-final'
assert not STAGE.exists(),'Use a fresh native validation snapshot.'
extensions={'.gd','.gdshader','.tscn','.tres','.json','.otf','.uid','.png','.import','.wav','.ogg','.svg','.glb','.webp'}
def ignore(directory,names):
 return [name for name in names if (Path(directory,name).is_dir() and name in {'.godot','screenshots','evidence','backups','reference','references','docs'})or(Path(directory,name).is_file()and Path(name).suffix not in extensions and name!='LICENSE.txt')]
for folder in ['scripts','scenes','data','assets','aircraft','ui','showcase']:shutil.copytree(ROOT/folder,STAGE/folder,ignore=ignore)
shutil.copyfile(ROOT/'project.godot',STAGE/'project.godot')
for name in ['tests/aircraft_training_capture.gd','tests/fixtures/aircraft_training_fixture.gd','tests/fixtures/aircraft_fixture.gd','tests/fixtures/combat_fixture.gd','tests/fixtures/aircraft_damage_fixture.gd']:
 target=STAGE/name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(ROOT/name,target)
manifest={'created_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'stage':str(STAGE),'sources':{str(p.relative_to(STAGE)):hashlib.sha256(p.read_bytes()).hexdigest()for p in sorted(STAGE.rglob('*'))if p.is_file()}}
(STAGE/'freeze_manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
(ROOT/'docs/showcase/evidence/S04-training/frozen-input.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
print('Frozen training runtime',len(manifest['sources']),'files; DM01 manifests untouched.')
