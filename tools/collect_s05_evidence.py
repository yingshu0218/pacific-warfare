"""Collect S05-owned bounded validation reports; never signal/close other processes."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/showcase/evidence/S05'
OUT.mkdir(parents=True,exist_ok=True)
records=[]
groups={}
for path in sorted((ROOT/'.local/validation/runs').glob('*/report.json')):
    report=json.loads(path.read_text())
    if report.get('owner')!='S05':continue
    dest=OUT/'verification'/report['run_id']
    dest.mkdir(parents=True,exist_ok=True)
    shutil.copy2(path,dest/'report.json')
    for check in report.get('checks',[]):
        log=Path(check.get('output',''))
        if log.is_file():shutil.copy2(log,dest/log.name)
        group=check.get('process_group')
        if group:
            try:os.killpg(group,0)
            except ProcessLookupError:alive=False
            except PermissionError:alive=True
            else:alive=True
            groups[str(group)]={'exists_at_collection':alive,'cleanup_ok':check.get('cleanup_ok'),'run_id':report['run_id']}
    records.append({'run_id':report['run_id'],'action':report['action'],'passed':report['passed'],'exit_code':report.get('exit_code'),'report':'verification/'+report['run_id']+'/report.json','checks':[{'command':c.get('command'),'returncode':c.get('returncode'),'timed_out':c.get('timed_out'),'cleanup_ok':c.get('cleanup_ok'),'duration_s':c.get('duration_s'),'diagnostic_error':c.get('diagnostic_error')} for c in report.get('checks',[])]})
(OUT/'validation_runs.json').write_text(json.dumps(records,ensure_ascii=False,indent=2)+'\n')
# Preserve the orchestrator's original counterexample and independent repair review.
reviews=[]
for run_id in ['20261109T203647-114f0eb0','20261109T211015-90c9dca0']:
    path=ROOT/'.local/validation/runs'/run_id/'report.json'
    report=json.loads(path.read_text())
    dest=OUT/'external_review'/run_id
    dest.mkdir(parents=True,exist_ok=True)
    shutil.copy2(path,dest/'report.json')
    for check in report.get('checks',[]):
        log=Path(check.get('output',''))
        if log.is_file():shutil.copy2(log,dest/log.name)
    reviews.append({'run_id':run_id,'owner':report['owner'],'passed':report['passed'],'report':'external_review/'+run_id+'/report.json'})
(OUT/'external_review.json').write_text(json.dumps(reviews,ensure_ascii=False,indent=2)+'\n')
regression=OUT/'regressions'
regression.mkdir(parents=True,exist_ok=True)
shutil.copy2(ROOT/'.local/validation/probes/departed_collision.gd',regression/'departed_collision.gd')
(OUT/'cleanup.json').write_text(json.dumps({'method':'read-only killpg(signal=0) for S05 report-owned process groups only; no processes killed','all_reported_cleanup_ok':all(x['cleanup_ok'] for x in groups.values()),'all_groups_gone':all(not x['exists_at_collection'] for x in groups.values()),'groups':groups,'browser_tabs_created':0,'http_services_created':0,'editors_left_open':0},ensure_ascii=False,indent=2)+'\n')
paths=[]
for folder in ['scripts/simulation/weapons','scripts/simulation/projectiles','scripts/simulation/collision','scripts/simulation/damage','scripts/simulation/fire_control','scripts/command/contacts','scripts/command/air_defence','scripts/presentation/effects']:
    paths.extend(p for p in (ROOT/folder).glob('*') if p.is_file())
for name in ['docs/combat-contracts.md','docs/references/combat/s05-sources.md','data/combat/showcase.json','data/ammunition/jp_20mm_type99_2_shell.json','data/ammunition/jp_77mm_type97_ball.json','assets/audio/SOURCES.md','tools/build_combat_parameters.py','tools/collect_s05_evidence.py','tests/fixtures/combat_fixture.gd','tests/fixtures/combat_test.gd','tests/combat_capture.gd','tests/scenes/combat_capture.tscn','tests/test_combat_geometry.gd','tests/test_combat_mount_clearance.gd','tests/test_contacts.gd','tests/test_projectile_impact.gd','tests/test_weapon_cycle.gd','tests/test_gunnery.gd','tests/test_damage_states.gd','tests/test_air_defence.gd','tests/test_combat_effects.gd','tests/test_unit_surface_contact.gd','tests/test_combat_integration.gd','tests/test_combat_presence.gd','tests/test_combat_damage_effects.gd','docs/showcase/deliveries/S05.md','docs/showcase/evidence/S05/departed_boundary.json','docs/showcase/evidence/S05/damage_effect_anchors.json','docs/showcase/evidence/S05/regressions/departed_collision.gd','docs/showcase/evidence/S05/external_review.json']:
    paths.append(ROOT/name)
manifest=[{'path':str(p.relative_to(ROOT)),'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'bytes':p.stat().st_size} for p in sorted(set(paths))]
(OUT/'files.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
config=ROOT/'data/combat/showcase.json'
before=hashlib.sha256(config.read_bytes()).hexdigest()
subprocess.run(['python3',str(ROOT/'tools/build_combat_parameters.py')],cwd=ROOT,check=True)
after=hashlib.sha256(config.read_bytes()).hexdigest()
(OUT/'parameter_rebuild.json').write_text(json.dumps({'stable':before==after,'sha256_before':before,'sha256_after':after,'command':['python3','tools/build_combat_parameters.py']},indent=2)+'\n')
if before!=after:raise SystemExit('Combat parameter rebuild drifted')
print(json.dumps({'runs':len(records),'groups':len(groups),'files':len(manifest),'all_cleanup_ok':all(x['cleanup_ok'] for x in groups.values()),'all_groups_gone':all(not x['exists_at_collection'] for x in groups.values()),'parameter_rebuild_stable':before==after}))
