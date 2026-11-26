#!/usr/bin/env python3
"""Package and verify S04 source/evidence hashes and bounded validation reports."""
import argparse
import datetime
import hashlib
import json
import re
import shutil
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/showcase/evidence/S04-spatial'
RUNS=ROOT/'.local/validation/runs'
DELIVERY=ROOT/'docs/showcase/deliveries/S04-spatial-combat.md'
CONTRACT=ROOT/'docs/aircraft-contracts.md'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def verify_manifest(name):
    data=json.loads((OUT/name).read_text())
    failures=[path for path,info in data['files'].items()
              if not (ROOT/path).is_file() or digest(ROOT/path)!=(info['sha256'] if isinstance(info,dict) else info)]
    assert not failures,(name,failures)
    return len(data['files'])


def reports():
    result={}
    for path in RUNS.glob('*/report.json'):
        data=json.loads(path.read_text())
        if data.get('owner')=='S04':result[data['run_id']]=(path,data)
    return result


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--verify',action='store_true')
    args=parser.parse_args()
    freeze=json.loads((OUT/'production-inputs.json').read_text())
    changed=[p for p,h in freeze['files'].items() if digest(ROOT/p)!=h]
    assert not changed,changed
    if args.verify:
        print('S04 final manifests PASS source=',verify_manifest('source-hashes.json'),
              'evidence=',verify_manifest('evidence-hashes.json'))
        return
    cleanup=json.loads((OUT/'cleanup.json').read_text())
    assert cleanup['passed'],cleanup['remaining_or_unknown']
    assert json.loads((OUT/'final-natural-consistency.json').read_text())['passed']
    assert json.loads((OUT/'replay.json').read_text())['four']['seconds']>=110
    all_reports=reports()
    selected={
        '20261109T235720-60d89a44', '20261110T140606-447e1408',
        '20261110T141238-8cd72f8a', '20261110T141432-dd9192f6',
        '20261110T141447-032c3afc', '20261110T141458-5fc144d7',
        '20261110T141541-6270ea5f', '20261110T142003-cdd75c6d',
        '20261110T142139-f860c9a6', '20261110T142211-263d6bad',
        '20261110T142433-57c8fe8c', '20261110T142439-9282d6a6',
        '20261110T142914-ad8d10df', '20261110T143247-ef96f6c9',
        '20261110T144027-09b2b950',
    }
    # Include the latest frozen-source full combat and final cleanup invocations.
    for needle in ['res://tests/test_aircraft_spatial_combat.gd','tools/audit_aircraft_spatial_cleanup.py']:
        candidates=[key for key,(_,r) in all_reports.items() if any(needle in c['command'] for c in r['checks'])]
        assert candidates,needle
        selected.add(max(candidates))
    packaged=[]
    for key in sorted(selected):
        path,report=all_reports[key]
        assert report['passed'],key
        assert all(c['returncode']==0 and not c['diagnostic_error'] and c['cleanup_ok'] for c in report['checks']),key
        target=OUT/'validation'/key
        target.mkdir(parents=True,exist_ok=True)
        shutil.copyfile(path,target/'report.json')
        logs=[]
        for c in report['checks']:
            log=Path(c['output'])
            shutil.copyfile(log,target/log.name)
            logs.append(str((target/log.name).relative_to(ROOT)))
        packaged.append({'run_id':key,'action':report['action'],'passed':True,
                         'report':str((target/'report.json').relative_to(ROOT)),
                         'original_report_sha256':digest(path),'logs':logs})
    failed=[{'run_id':key,'error':r.get('error','check_failed'),
             'failed_commands':[c['command'] for c in r['checks'] if not c['passed']]}
            for key,(_,r) in sorted(all_reports.items()) if not r['passed']]
    (OUT/'validation-runs.json').write_text(json.dumps({'passed':True,'packaged_terminal_checks':packaged,
        'historical_failed_or_lock_wait_runs_retained_in_local':failed,
        'note':'Historical failed reports are not promoted to passing; cleanup independently checks all completed S04 groups.'},indent=2)+'\n')
    files=dict(freeze['files'])
    extra=[]
    for pattern in ['tests/*aircraft*.gd*','tests/*f6f*.gd*','tests/fixtures/aircraft*.gd*',
                    'tests/fixtures/aircraft_spatial_baseline/*.gd*']:
        extra.extend(ROOT.glob(pattern))
    for name in ['tools/verify.py','tools/plot_aircraft_spatial.py','tools/plot_f6f_quality.py',
                 'tools/assemble_aircraft_spatial_evidence.py','tools/audit_f6f_traces.py',
                 'tools/audit_aircraft_spatial_cleanup.py','tools/finalize_aircraft_spatial_delivery.py',
                 'tests/test_simulation_commands.gd','tests/test_gunnery.gd']:
        extra.append(ROOT/name)
    extra.extend([DELIVERY,CONTRACT])
    for path in extra:
        if path.is_file():files[str(path.relative_to(ROOT))]=digest(path)
    (OUT/'source-hashes.json').write_text(json.dumps({'frozen_utc':freeze['frozen_utc'],
        'engine':freeze['engine'],'production_file_count':len(freeze['files']),
        'historical_base_performance_unchanged':True,'files':dict(sorted(files.items()))},indent=2)+'\n')
    evidence={}
    for path in sorted(OUT.rglob('*')):
        if path.is_file() and path.name!='evidence-hashes.json' and path.suffix!='.import':
            evidence[str(path.relative_to(ROOT))]={'sha256':digest(path),'bytes':path.stat().st_size}
    for path in [DELIVERY,CONTRACT]:evidence[str(path.relative_to(ROOT))]={'sha256':digest(path),'bytes':path.stat().st_size}
    (OUT/'evidence-hashes.json').write_text(json.dumps({'sealed_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),
        'excluded':['evidence-hashes.json itself','Godot .import sidecars','ignored .local raw frames and caches'],
        'files':evidence},indent=2)+'\n')
    for link in re.findall(r'\]\(([^)]+)\)',DELIVERY.read_text()):
        if '://' not in link and not link.startswith('#'):
            assert (DELIVERY.parent/link.split('#')[0]).exists(),link
    print('S04 delivery sealed source=',verify_manifest('source-hashes.json'),
          'evidence=',verify_manifest('evidence-hashes.json'),'validation_runs=',len(packaged))


if __name__=='__main__':main()
