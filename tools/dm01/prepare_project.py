#!/usr/bin/env python3
"""Freeze current DM01 runtime and the published FX01 revision for serial validation."""
import argparse,datetime,hashlib,json,shutil
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def digest(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--stage',default='.local/dm01-project-v1')
    args=parser.parse_args()
    stage=(ROOT/args.stage).resolve()
    assert stage.is_relative_to(ROOT/'.local') and not stage.exists(), 'Use a fresh isolated .local destination.'
    freeze_path=ROOT/'docs/showcase/evidence/FX01/implementation_freeze.json'
    fx=json.loads(freeze_path.read_text())
    for name,expected in fx['sources'].items(): assert digest(ROOT/name)==expected, 'Published FX source changed: '+name
    stage.mkdir(parents=True)
    extensions={'.gd','.gdshader','.tscn','.tres','.json','.otf','.uid','.png','.import','.wav','.ogg','.svg','.glb','.webp'}
    def ignore(directory,names):
        return [name for name in names if (Path(directory,name).is_dir() and name in {'.godot','screenshots','evidence','backups','reference','references','docs'}) or (Path(directory,name).is_file() and Path(name).suffix not in extensions and name!='LICENSE.txt')]
    for name in ['scripts','scenes','data','assets','aircraft','ui','showcase']:
        shutil.copytree(ROOT/name,stage/name,ignore=ignore)
    for name in ['project.godot','export_presets.cfg']: shutil.copyfile(ROOT/name,stage/name)
    selected=['tests/aircraft_damage_capture.gd','tests/fixtures/dm01_review_stage.gd','tests/fixtures/aircraft_damage_fixture.gd','tests/fixtures/combat_fixture.gd']
    for relative in selected:
        target=stage/relative;target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(ROOT/relative,target)
    (stage/'docs/showcase/evidence/DM01').mkdir(parents=True)
    for name,expected in fx['sources'].items():
        copied=stage/name
        if copied.is_file(): assert digest(copied)==expected, 'FX changed during copy; quarantine this stage: '+name
    manifest={'prepared_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'stage':str(stage),'fx01_freeze':fx,'sources':{str(p.relative_to(stage)):digest(p) for p in sorted(stage.rglob('*')) if p.is_file()}}
    (stage/'freeze_manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
    out=ROOT/'docs/showcase/evidence/DM01/frozen-input.json'
    out.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
    print('Frozen',len(manifest['sources']),'inputs including FX01 revision',fx['revision'],'at',stage)
if __name__=='__main__':main()
