#!/usr/bin/env python3
"""Audit/freeze S14 outputs without rerunning or changing the simulation."""
from __future__ import annotations
import datetime
import hashlib
import json
import math
import os
from pathlib import Path
import shutil
import socket
from collections import Counter
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'docs/showcase/evidence/S14/final'
NOW = datetime.datetime.now(datetime.timezone.utc).isoformat()


def sha(path: Path) -> str:
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()


def read(path: Path):
    return json.loads(path.read_text())


def put(name: str, value):
    (OUT / name).write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n')


def differences(before: dict, after: dict) -> dict:
    return {k: {'before': before.get(k), 'after': after.get(k)}
            for k in sorted(before.keys() | after.keys()) if before.get(k) != after.get(k)}


frozen = read(OUT / 'frozen-input.json')
runtime = Path(frozen['stage'])
assert len(frozen['sources']) == 402
assert all(sha(runtime / k) == v for k, v in frozen['sources'].items())
root_diff = {k: {'runtime': v, 'root': sha(ROOT / k) if (ROOT / k).is_file() else None}
             for k, v in frozen['sources'].items()
             if not (ROOT / k).is_file() or sha(ROOT / k) != v}
assert set(root_diff) == {'project.godot'}, root_diff
assert not any('essex' in k.lower() or k.startswith('naval/') for k in frozen['sources'])
definitions = [k for k in frozen['sources'] if Path(k).parent == Path('data/units') and k.endswith('.json')]
assert len(definitions) == 9
assert [k for k in frozen['sources'] if k.startswith('data/maps/')] == ['data/maps/island_harbor.json']
scenarios = sorted((runtime / 'data/scenarios').glob('s14_*.json'))
assert len(scenarios) == 16
stable_ids = None
for path in scenarios:
    data = read(path)
    units = data['spawns'] + data['ground_deployments']
    ids = sorted(u['id'] for u in units)
    assert len(ids) == 19
    if stable_ids is None:
        stable_ids = ids
    assert ids == stable_ids

build = read(OUT / 'build_manifest.json')
assert build['source_freeze'] == frozen
assert all(sha(ROOT / 'build/s14-final-web' / k) == v['sha256'] for k, v in build['outputs'].items())

captures = {}
native_sources = None
for path in sorted((OUT / 'native').glob('*/capture.json')):
    capture = read(path)
    this_sources = capture['source_manifest']['sources']
    if native_sources is None:
        native_sources = this_sources
    assert this_sources == native_sources
    captures[path.parent.name] = capture
    if 'frames' in capture:
        assert capture['passed'] and len(list(path.parent.glob('frame_*.png'))) == capture['frames']
        assert all((path.parent / f'frame_{n:04}.png').exists() for n in range(capture['frames']))

native_diff = differences(native_sources, frozen['sources'])
expected_diff = {'data/units/us_sb2c4_1944.json', 'scripts/showcase/all_units_showcase.gd', 'tests/s14_web_probe.gd'}
assert set(native_diff) == expected_diff, native_diff
early = read(ROOT / '.local/s14-final-dev-1/freeze_manifest.json')
put('capture_provenance.json', {
    'created_utc': NOW,
    'native_source_stage': '.local/s14-final-r3',
    'native_captures_share_source_hashes': True,
    'native_source_files': len(native_sources),
    'final_runtime_stage': str(runtime),
    'native_to_runtime_differences': native_diff,
    'difference_explanations': {
        'data/units/us_sb2c4_1944.json': 'configuration_date historical description only; flight/model values unchanged',
        'scripts/showcase/all_units_showcase.gd': 'show training text only when guide.current is training and guide.active; UI visibility only',
        'tests/s14_web_probe.gd': 'read-only generation/exercise/tooltip/gallery/event fields; no simulation or rendering behavior overrides'
    },
    'all_other_files_identical': True,
    'root_to_runtime_differences': root_diff,
    'root_difference_explanation': 'Isolated runtime explicitly selects S14 and1280x720; root retains Yamato entry and original viewport',
    'early_integration_stage': early['stage'],
    'early_integration_to_runtime_differences': differences(early['sources'], frozen['sources']),
    'early_integration_note': 'Early non-escort mission history has a guarding initialization label from indentation; corrected before final r3 captures. No physical state or training result change. Camera and UI were subsequently improved.',
    'prior_camera52_is_final_evidence': False,
    'original_native_manifests_preserved': True,
})

integration = {}
for path in sorted((OUT / 'integration').glob('*.json')):
    data = read(path)
    assert data['failed'] == 0 and all(x['passed'] for x in data['checks'])
    integration[path.stem] = data
assert len(integration) == 12
training = []
for mode, data in integration.items():
    if not mode.startswith('train_'):
        continue
    result = captures[mode]['final']
    state = result['training']
    assert result['status'] == result['execution']['status'] == state['status'] == 'completed'
    assert result['order_id'] == state['order_id']
    training.append({'mode': mode, 'completed_s': state['elapsed_s'],
                     'peak_roll_deg': math.degrees(state['peak_roll_rad']),
                     'height_change_m': state['height_change_m'], 'min_agl_m': state['min_agl_m'],
                     'min_friendly_m': data['min_training_friend_m'],
                     'frames': captures[mode]['frames'], 'fps': captures[mode]['fps']})
videos = read(OUT / 'videos.json')
assert len(videos) == 12
assert all(sha(ROOT / x['path']) == x['sha256'] for x in videos)
assert sum(x['frames'] for x in videos) == 5154
ui = read(OUT / 'ui_contract.json')
assert len(ui['checks']) == 5 and all(x['passed'] for x in ui['checks'])
aviation_fire = {}
for mode in ['four', 'escort']:
    aviation_fire[mode] = Counter(e['entity_id'] for e in captures[mode]['events']
                                  if e['kind'] == 'fired' and e['entity_id'].startswith(('us_air_', 'jp_air_', 'us_pair_demo_', 'us_sb2c_')))
assert sum(aviation_fire['four'].values()) == 120 and not aviation_fire['escort']
put('integration_summary.json', {
    'cases': 12, 'checks': sum(len(d['checks']) for d in integration.values()), 'all_passed': True,
    'ui_contract_checks': len(ui['checks']), 'training': training,
    'four': {'cycle_status': captures['four']['final']['cycle_status'], 'cycle_completed_s': captures['four']['final']['cycle_completed_s'],
             'aviation_fired_events': sum(aviation_fire['four'].values()), 'aviation_fired_by_id': dict(aviation_fire['four'])},
    'escort': {'cycle_status': captures['escort']['final']['cycle_status'], 'cycle_completed_s': captures['escort']['final']['cycle_completed_s'],
               'aviation_fired_events': sum(aviation_fire['escort'].values()), 'scope': 'Actual threat response, limited pursuit and guard restoration; no escort aircraft gunfire in this seed'},
    'clips': len(videos), 'frames': sum(x['frames'] for x in videos),
    'duration_s': round(sum(x['duration_s'] for x in videos), 6), 'capture_cadence_is_not_performance': True,
})

chrome = read(OUT / 'chrome/run.json')
control = read(OUT / 'chrome-attempt1-same-selection/run.json')
assert chrome['passed'] and len(chrome['checks']) == 74 and all(c['passed'] for c in chrome['checks'])
assert not chrome['console'] and not chrome['pageErrors']
raf = [r for r in control['data']['raf'] if r['phase'] == 'normal_1x']
ms = sorted(r['ms'] for r in raf)
browser_cleanup = []
for path in sorted(OUT.glob('chrome*/run.json')):
    report = read(path)
    assert all(report['cleanup'].get(k) for k in ['chromeClosed', 'serverClosed', 'profileRemoved'])
    port = urlparse(report['url']).port
    with socket.socket() as sock:
        sock.settimeout(.25)
        closed = sock.connect_ex(('127.0.0.1', port)) != 0
    browser_cleanup.append({'run': str(path.relative_to(ROOT)), 'port': port, 'port_closed': closed, 'cleanup': report['cleanup']})
assert all(x['port_closed'] for x in browser_cleanup)
put('browser_summary.json', {
    'final_check_count': len(chrome['checks']), 'all_final_checks_passed': True,
    'successful_control_checks_from_first_attempt': len(control['checks']),
    'first_attempt_as_a_whole_passed': False,
    'hardware': chrome['hardware'], 'browser': chrome['browserVersion'], 'identity': chrome['identity'],
    'normal_1x_short_sample': {'frames': len(ms),
        'p50_raf_ms': ms[int(len(ms) * .5)], 'p95_raf_ms': ms[int(len(ms) * .95)], 'p99_raf_ms': ms[int(len(ms) * .99)],
        'all_visible_focused': all(r['visible'] == 'visible' and r['focused'] for r in raf)},
    'two_x_short_observation': control['speedObservation'],
    'final_selection_frame_summary': chrome['frameSummary'],
    'browser_plugin': 'Browser plugin not available; existing Playwright controls real Google Chrome',
    'viewports': ['1280x720, DPR1, actual canvas1280x720; desktop-only Godot scene'],
    'scope_exclusions': ['S08 ordinary launcher', '10-minute activity', 'three consecutive resets', '4x effective speed/backlog acceptance', 'mobile', 'Safari'],
    'visual_screenshots_opened': ['chrome/train_us_axial_roll_completed.png', 'chrome/train_jp_split_s_completed.png', 'chrome/escort_sb2c_close.png', 'chrome/weapon_3.png', 'chrome/unit_us_bb.png', 'chrome-attempt1-same-selection/real_orders.png'],
})

production = list((ROOT / 'scripts/showcase').glob('*.gd')) + [ROOT / p for p in [
    'scripts/game/first_playable_session.gd', 'data/aircraft/performance.json', 'ui/observer_text.gd',
    'showcase/all_units.tscn', 'scenes/units/aircraft/sb2c4_flight.tscn', 'data/units/us_sb2c4_1944.json', 'data/combat/s14_sb2c.json']]
production += list((ROOT / 'data/scenarios').glob('s14_*.json'))
helpers = [p for p in (ROOT / 'tools/s14').glob('*') if p.suffix in {'.py', '.js', '.mjs'}]
helpers += [ROOT / p for p in ['tests/s14_integration.gd', 'tests/s14_final_capture.gd', 'tests/s14_ui_contract.gd', 'tests/s14_web_probe.gd', 'tests/scenes/s14_web.tscn']]
documents = [ROOT / p for p in ['docs/showcase/deliveries/S14.md', 'docs/showcase/deliveries/S14-phase.md',
    'docs/showcase/all-units-inventory.md', 'docs/showcase/S14-scene-layout.md',
    'docs/showcase/S14-aircraft-integration-handoff.md', 'docs/showcase/S14-S08-handoff.md']]
archive = ROOT / '.local/s14-final-owned'
for path in production + helpers + documents:
    target = archive / path.relative_to(ROOT)
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(path, target)
put('source_hashes.json', {'production': {str(p.relative_to(ROOT)): sha(p) for p in sorted(production)},
                           'tools': {str(p.relative_to(ROOT)): sha(p) for p in sorted(helpers)},
                           'documents': {str(p.relative_to(ROOT)): sha(p) for p in sorted(documents)}})

runs, groups = [], []
for path in sorted((ROOT / '.local/validation/runs').glob('*/report.json')):
    report = read(path)
    if not report.get('owner', '').startswith('S14'):
        continue
    dest = OUT / 'validation' / report['run_id']
    dest.mkdir(parents=True, exist_ok=True)
    shutil.copy2(path, dest / 'report.json')
    for check in report.get('checks', []):
        log = Path(check['output'])
        if log.exists():
            shutil.copy2(log, dest / log.name)
        pgid = check.get('process_group')
        if pgid:
            try:
                os.killpg(pgid, 0)
                status = 'present'
            except ProcessLookupError:
                status = 'absent'
            except PermissionError:
                status = 'permission_denied'
            groups.append({'pgid': pgid, 'owner': report['owner'], 'status': status, 'wrapper_cleanup_ok': check.get('cleanup_ok')})
    runs.append({'owner': report['owner'], 'run_id': report['run_id'], 'passed': report['passed'],
                 'report': str((dest / 'report.json').relative_to(ROOT)), 'error': report.get('error', '')})
assert all(x['status'] == 'absent' for x in groups), groups
profiles = list((ROOT / '.local').glob('s14-chrome-*'))
assert not profiles, profiles
put('validation_runs.json', {'includes_prior_phase_and_failed_attempts': True, 'runs': runs})
put('cleanup.json', {'created_utc': NOW, 'groups': groups, 'all_absent': True,
                     'all_wrapper_cleanup_ok': all(x['wrapper_cleanup_ok'] for x in groups),
                     'chrome_runs': browser_cleanup, 'remaining_s14_chrome_profiles': [],
                     'sandbox_listen_failure_empty_profile_removed': '.local/s14-chrome-pLk0c5',
                     'user_windows_or_unrelated_processes_closed': False,
                     'native_camera52_interruption': 'Only owned outer batch stopped, verify cleaned owned Godot; retained interrupted report and partial recording'})

files = {str(p.relative_to(OUT)): sha(p) for p in sorted(OUT.rglob('*'))
         if p.is_file() and p.name not in {'evidence_hashes.json', 'final_freeze.json'} and p.suffix != '.import'}
put('evidence_hashes.json', files)
put('final_freeze.json', {
    'status': 'implemented_self_validated_ready_for_coordinator_final_review_and_s08',
    'created_utc': NOW, 'engine': frozen['engine'], 'renderer': 'Compatibility',
    'normal_entry': 'res://showcase/all_units.tscn', 'root_entry_changed': False,
    'runtime': str(runtime), 'runtime_source_files': len(frozen['sources']),
    'simulation_units': 19, 'model_types': 9, 'weapon_exhibits': 5, 'selectable_modes': 16,
    'production_files': len(production), 'tool_files': len(helpers),
    'owned_recovery': str(archive), 'prior_recovery': str(ROOT / '.local/s14-final-before'),
    'source_manifest_sha256': sha(OUT / 'source_hashes.json'),
    'runtime_manifest_sha256': sha(OUT / 'frozen-input.json'),
    'evidence_manifest_sha256': sha(OUT / 'evidence_hashes.json'), 'evidence_files': len(files),
    'native_to_runtime_differences': list(native_diff), 'capture_provenance': 'capture_provenance.json',
    'full_clips': 12, 'full_clip_frames': 5154, 'full_clip_duration_s': 431,
    'final_chrome_checks_passed': 74, 'control_checks_passed_in_partial_first_attempt': len(control['checks']),
    'cleanup_all_recorded_groups_absent': True, 'cleanup': 'cleanup.json',
    'subagents_started': False, 'threads_created': False,
    'not_accepted_here': ['S08 ordinary user startup', '10-minute actual activity', 'three consecutive restarts', '4x effective speed and backlog'],
    'known_limit': 'DM01 requested4x only about1.95x achieved; not passed; no simulation tick dropping or battle culling introduced',
    'prior_phase_manifest_untouched': True,
})
print(json.dumps({'production_files': len(production), 'tool_files': len(helpers), 'runtime_files': len(frozen['sources']),
                  'evidence_files': len(files), 'validation_runs': len(runs), 'groups_all_absent': len(groups),
                  'native_runtime_diff': list(native_diff), 'chrome_checks': len(chrome['checks']), 'clips': len(videos)}))
