#!/usr/bin/env python3
"""Audit the frozen S14 phase, public baseline and task-owned cleanup."""
from pathlib import Path
import datetime
import hashlib
import json
import subprocess

ROOT = Path(__file__).resolve().parents[2]
CAND = ROOT / 'candidates/s14-expansion'
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
read = lambda p: json.loads(p.read_text())
source_path = CAND / 'evidence/inputs-autonomous-b25-r8.json'
source = read(source_path)
assert all(sha(CAND / 'stage' / p) == h for p, h in source['files'].items())
assert all(sha(p) == source['files'][str(p.relative_to(CAND / 'overrides'))]
           for p in (CAND / 'overrides').rglob('*') if p.is_file())
baseline = read(CAND / 'baseline-hashes.json')
assert all(sha(ROOT / p) == h for p, h in baseline.items())
ordinary = read(ROOT / 'build/first-playable/build_manifest.json')
assert all(sha(ROOT / 'build/first-playable' / p) == v['sha256']
           for p, v in ordinary['outputs'].items())
web_path = CAND / 'evidence/web-build-autonomous-final.json'
web = read(web_path)
assert web['source_manifest']['files'] == source['files']
assert all(sha(ROOT / 'build/s14-expansion-autonomous-final' / p) == v['sha256']
           for p, v in web['outputs'].items())
checks = {}
for name in ['assembly-final.json', 'autonomy-final.json', 'cycle-single-final.json']:
    d = read(CAND / name)
    assert d['failed'] == 0
    checks[name] = {'checks': len(d['checks']), 'failed': 0, 'sha256': sha(CAND / name)}
chrome = read(CAND / 'chrome-autonomous-final/run.json')
assert chrome['passed'] and all(c['passed'] for c in chrome['checks'])
assert not chrome['pageErrors'] and not chrome['console']
assert all(chrome['cleanup'].values())
checks['chrome-autonomous-final/run.json'] = {
    'checks': len(chrome['checks']), 'failed': 0,
    'sha256': sha(CAND / 'chrome-autonomous-final/run.json'),
}
movies = read(CAND / 'evidence/native-movies.json')
for movie in movies:
    assert sha(ROOT / movie['movie']) == movie['movie_sha256']
    assert sha(ROOT / movie['source_capture']) == movie['source_capture_sha256']

plan = read(CAND / 'evidence/public-change-plan.json')
for patch in plan['candidate_patches']:
    public = ROOT / patch['path']
    assert (sha(public) if public.exists() else None) == patch['before_sha256']
    assert sha(ROOT / patch['candidate']) == patch['candidate_sha256']
    if patch['before_sha256']:
        assert sha(CAND / 'evidence/public-before' / patch['path']) == patch['before_sha256']

reports = []
for path in sorted((ROOT / '.local/validation/runs').glob('*/report.json')):
    d = read(path)
    if not d.get('owner', '').startswith('S14-exp'):
        continue
    reports.append({'report': str(path.relative_to(ROOT)), 'sha256': sha(path),
                    'owner': d['owner'], 'passed': d['passed'],
                    'checks': [{k: v.get(k) for k in ['pid', 'process_group', 'passed', 'timed_out', 'cleanup_ok', 'cleanup_error']}
                               for v in d['checks']]})
(CAND / 'evidence/validation-audit.json').write_text(json.dumps(reports, indent=2) + '\n')

processes = subprocess.check_output(['/bin/ps', '-axo', 'pid=,ppid=,pgid=,stat=,command='], text=True)
remaining = []
for line in processes.splitlines():
    parts = line.strip().split(None, 4)
    if len(parts) != 5:
        continue
    command = parts[4]
    owned_godot = 'Godot.app/Contents/MacOS/Godot' in command and '/candidates/s14-expansion/' in command
    owned_chrome = 'Google Chrome' in command and 's14-exp-chrome-' in command
    owned_runner = command.split(None, 1)[0].rsplit('/', 1)[-1] == 'node' and 'tools/s14_expansion/chrome_check.mjs' in command
    if owned_godot or owned_chrome or owned_runner:
        remaining.append(line)
assert not remaining, remaining
assert not list((ROOT / '.local').glob('s14-exp-chrome-*'))
cleanup = {'utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
           'owned_godot_chrome_node_remaining': [], 'owned_temporary_profiles_remaining': [],
           'old_failed_cleanup_supplement': 'evidence/chrome-autonomous-r2-cleanup.json',
           'unrelated_processes_untouched': True}
(CAND / 'evidence/final-cleanup.json').write_text(json.dumps(cleanup, indent=2) + '\n')

evidence = [CAND / p for p in ['assembly-final.json', 'autonomy-final.json',
            'cycle-single-final.json', 'cycle-pair-final-status.json']]
for folder in ['chrome-autonomous-final', 'native/inventory-autonomous-r1',
               'native/launch-autonomous-r2', 'native/recovery-autonomous-r2']:
    evidence.extend(p for p in (CAND / folder).iterdir() if p.is_file())
hashes = {str(p.relative_to(ROOT)): sha(p) for p in sorted(evidence)}
(CAND / 'evidence/final-evidence-hashes.json').write_text(json.dumps(hashes, indent=2) + '\n')
summary = {
    'status': 'phase_candidate_ready_for_parent_review', 'full_latest_request_complete': False,
    'public_admitted': False, 'public_runtime_unchanged': True,
    'ordinary_build_unchanged': True, 'engine': source['engine'], 'renderer': 'Compatibility',
    'entry': 'res://showcase/carrier_harbor.tscn', 'frozen_inputs': source['frozen_inputs'],
    'source_manifest': str(source_path.relative_to(ROOT)), 'source_manifest_sha256': sha(source_path),
    'frozen_input_count': len(source['files']), 'web_runtime_with_settings': len(web['runtime_files']),
    'normal_resource_whitelist_count': plan['runtime_admission_count'],
    'web_candidate': 'build/s14-expansion-autonomous-final', 'checks': checks,
    'incomplete_pair_cycle': read(CAND / 'cycle-pair-final-status.json'),
    'pending': ['Final BOMB admission, autonomous B-25 bombing and fighter interception',
                'Complete paired2-wave integrated acceptance', 'Parent review/public admission and S08 long/performance checks'],
    'native_movies': [{k: r[k] for k in ['sequence', 'fps', 'frames', 'movie', 'movie_sha256', 'frozen_inputs']} for r in movies],
    'cleanup': cleanup,
    'support_tools_sha256': {str(p.relative_to(ROOT)): sha(p) for p in sorted((ROOT / 'tools/s14_expansion').glob('*')) if p.is_file()},
    'delivery_sha256': {str(p.relative_to(ROOT)): sha(p) for p in [ROOT / 'docs/showcase/deliveries/S14-carrier-harbor.md', ROOT / 'docs/showcase/S14-BOMB-integration-inputs.md', ROOT / 'docs/deliveries/S14-carrier-harbor.md']},
}
(CAND / 'evidence/phase-review.json').write_text(json.dumps(summary, ensure_ascii=False, indent=2) + '\n')
print(json.dumps({'status': summary['status'], 'checks': {k: v['checks'] for k, v in checks.items()},
                  'public_unchanged': True, 'owned_processes_remaining': 0, 'evidence_files': len(hashes)}))
