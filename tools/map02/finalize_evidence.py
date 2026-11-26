#!/usr/bin/env python3
"""Archive MAP02-owned validation and bind native evidence to unchanged sources.

No engine launch, process termination or shared runtime mutation. The start
snapshot is captured before implementation and is never regenerated here.
"""
import datetime as dt
import hashlib
import json
import os
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'docs/showcase/evidence/MAP02'
BASELINE = ROOT / 'docs/maps/MAP02/frozen_boundary_start.json'


def read(path):
    return json.loads(path.read_text())


def write(path, data):
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def group_alive(pgid):
    try:
        os.killpg(pgid, 0)  # Read-only existence query; never signals a process.
        return True
    except ProcessLookupError:
        return False


def main():
    baseline = read(BASELINE)
    frozen = {p: {'before': expected, 'after': sha(ROOT / p),
                  'unchanged': sha(ROOT / p) == expected}
              for p, expected in baseline.items()}
    assert all(x['unchanged'] for x in frozen.values()), 'Frozen boundary changed; inspect ownership before delivery'
    write(OUT / 'frozen_boundary.json', frozen)

    mechanisms = read(OUT / 'terrain_checks.json')
    assert mechanisms['checks'] == 1015 and not mechanisms['failures']
    assert mechanisms['map_sha256'] == sha(ROOT / 'data/maps/island_harbor_expanded.json')
    captures = {}
    for name in ['module_capture', 'map_capture']:
        record = read(OUT / (name + '.json'))
        assert not record['failures'] and record['reclaimed_on_exit']
        assert record['source_hashes_before'] == record['source_hashes_after']
        for p, expected in record['source_hashes_after'].items():
            assert sha(ROOT / p) == expected, f'{name}: source changed after capture: {p}'
        captures[name] = {'report': name + '.json', 'views': len(record['views']),
                          'frames': len(record['frames']), 'sources_match': True,
                          'reclaimed_on_exit': record['reclaimed_on_exit']}

    archive = OUT / 'validation'
    archive.mkdir(exist_ok=True)
    runs = []
    groups = {}
    for report in sorted((ROOT / '.local/validation/runs').glob('*/report.json')):
        record = read(report)
        if record.get('owner') != 'MAP02':
            continue
        target = archive / record['run_id']
        target.mkdir(exist_ok=True)
        shutil.copyfile(report, target / 'report.json')
        for check in record['checks']:
            assert check['cleanup_ok'], f'Unresolved cleanup: {report}'
            output = Path(check['output'])
            if output.exists():
                shutil.copyfile(output, target / output.name)
            if check.get('process_group'):
                pgid = int(check['process_group'])
                groups[str(pgid)] = {'run_id': record['run_id'],
                                     'cleanup_ok': check['cleanup_ok'],
                                     'alive_at_audit': group_alive(pgid)}
        runs.append({'run_id': record['run_id'], 'action': record['action'],
                     'passed': record['passed'],
                     'report': 'validation/' + record['run_id'] + '/report.json'})
    assert runs and all(not g['alive_at_audit'] for g in groups.values()), 'Owned process group remains alive'
    write(OUT / 'validation_runs.json', {'owner': 'MAP02', 'runs': runs})
    write(OUT / 'cleanup.json', {
        'checked_utc': dt.datetime.now(dt.timezone.utc).isoformat(),
        'scope': 'Only MAP02 groups recorded by tools/verify.py; never terminates or inspects unrelated windows',
        'all_wrapper_cleanups_ok': True, 'all_owned_groups_absent': True,
        'groups': groups, 'no_http_service_started': True,
        'no_browser_or_editor_started': True, 'native_scene_reclaimed': captures,
        'shared_lock_status_at_audit': read(ROOT / '.local/validation/godot-render.lock')})

    source_paths = [ROOT / 'data/maps/island_harbor_expanded.json']
    for directory in ['data/map02', 'scripts/map02', 'scenes/map02', 'tests/map02',
                      'tools/map02', 'docs/maps/MAP02', 'docs/references/maps/MAP02']:
        source_paths.extend(p for p in (ROOT / directory).rglob('*')
                            if p.is_file() and '__pycache__' not in p.parts)
    source_paths.extend(ROOT / p for p in ['docs/showcase/deliveries/MAP02.md', 'docs/deliveries/MAP02.md'])
    write(OUT / 'source_hashes.json', {str(p.relative_to(ROOT)): sha(p)
                                     for p in sorted(set(source_paths))})
    index = {'scope': 'MAP02 independent native static map; S14 integration and Chrome pending',
             'layout': '../../maps/MAP02/layout.png', 'interfaces': '../../maps/MAP02/interfaces.md',
             'mechanisms': 'terrain_checks.json', 'captures': captures,
             'video': 'inspection.mp4', 'video_metadata': 'video_probe.json',
             'contact_sheet': 'sequence_contact_sheet.png', 'source_hashes': 'source_hashes.json',
             'frozen_boundary': 'frozen_boundary.json', 'validation_runs': 'validation_runs.json',
             'cleanup': 'cleanup.json'}
    write(OUT / 'evidence_index.json', index)
    # Index itself, hashes and cleanup are included. Only this manifest excludes itself.
    files = {str(p.relative_to(OUT)): sha(p) for p in sorted(OUT.rglob('*'))
             if p.is_file() and p.name != 'evidence_hashes.json'}
    write(OUT / 'evidence_hashes.json', files)
    print(f'MAP02 evidence: {len(source_paths)} sources, {len(files)} evidence files, '
          f'{len(runs)} runs, {len(groups)} reclaimed groups; frozen {len(frozen)} files unchanged')


if __name__ == '__main__':
    main()
