#!/usr/bin/env python3
"""Collect real S13 reports, frame cadence, source identities and owned cleanup."""
import hashlib
import json
import math
import os
from pathlib import Path
import shutil
import signal
import statistics
import subprocess

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'docs/showcase/evidence/S13'

def write(name, value):
    (OUT / name).write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n')

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def quantile(values, fraction):
    values = sorted(values)
    position = (len(values) - 1) * fraction
    lo = math.floor(position)
    hi = math.ceil(position)
    return values[lo] * (hi - position) + values[hi] * (position - lo) if hi != lo else values[lo]

def describe(values):
    return {key: round(quantile(values, q), 4) for key, q in [('p50', .5), ('p95', .95), ('p99', .99)]}

def main():
    native = json.loads((OUT / 'native_capture.json').read_text())
    assert native['source_hashes_start'] == native['source_hashes_end']
    assert not native['failures'] and native['pause_pixels_identical']
    for name, value in native['source_hashes_end'].items():
        assert sha(ROOT / name.replace('res://', '', 1)) == value, name
    perf = json.loads((OUT / 'chrome-attempt2/run.json').read_text())
    controls = json.loads((OUT / 'chrome/run.json').read_text())
    assert controls['passed'] and not controls['console'] and not controls['pageErrors']
    assert not perf['console'] and not perf['pageErrors']
    phases = []
    for measurement in perf['measurements']:
        label = measurement['label']
        raf = [f for f in perf['data']['raf'] if f['phase'] == label]
        values = [f['ms'] for f in raf]
        # First probe batch can straddle warmup/measurement; discard it.
        samples = [s for s in perf['data']['samples'] if s['phase'] == label][1:]
        frames = [f for s in samples for f in s['game']['frames']]
        item = {'label': label, 'requested_seconds': measurement['requestedSeconds'],
                'raf_frames': len(values), 'raf_ms': describe(values),
                'fps_from_mean_interval': round(1000 / statistics.mean(values), 3),
                'visible_fraction': statistics.mean(f['visible'] == 'visible' for f in raf),
                'focused_fraction': statistics.mean(f['focused'] for f in raf),
                'camera_m': measurement['begin']['camera']}
        if frames:
            item.update({'engine_frame_ms': describe([f[0] for f in frames]),
                         'cpu_stage_p95_ms': {name: round(quantile([f[index] for f in frames], .95), 4)
                                              for name, index in [('advance', 2), ('presentation', 3), ('camera', 4), ('hud', 5)]},
                         'pending_time_max_s': max(f[6] for f in frames),
                         'median_draw_calls': statistics.median(s['game']['draw_calls'] for s in samples)})
        phases.append(item)
    summary = {'scope': '4 ships + 8 aircraft, 1280x720, short desktop Chrome test; not S08 ten-minute/final-scale acceptance',
               'hardware': perf['hardware'], 'identity': perf['identity'], 'flags': perf['launchFlags'],
               'performance_run': 'chrome-attempt2/run.json', 'control_run': 'chrome/run.json',
               'measured_windows_s': sum(m['requestedSeconds'] for m in perf['measurements']),
               'phases': phases, 'control_checks': controls['checks'],
               'no_runtime_console_shader_errors': True,
               'comparison_limit': 'RAF cadence includes browser/display/CPU jitter; not GPU timer-query cost. Cloud-off p95 is slightly slower, so cloud-only increment is below this short sample precision.'}
    write('chrome_summary.json', summary)
    shutil.copyfile(ROOT / 'build/s13-web/build_manifest.json', OUT / 'build_manifest.json')
    pack = json.loads((OUT / 'build_manifest.json').read_text())
    differences = []
    for name, value in pack['sources'].items():
        path = ROOT / name
        if name in {'project.godot', 'export_presets.cfg', 'shell.html'} or path.suffix in {'.uid', '.import'}: continue
        if path.is_file() and sha(path) != value: differences.append(name)
    assert set(differences).issubset({'assets/audio/au01/source/recipe.json'}), differences
    sources = dict(native['source_hashes_end'])
    paths = [ROOT / 'tests/cloud_sea_capture.gd', ROOT / 'tests/test_cloud_sea_environment.gd',
             ROOT / 'tests/cloud_sea_web_probe.gd', ROOT / 'tests/scenes/cloud_sea_web.tscn',
             ROOT / 'tests/fixtures/s13_original_ocean.gdshader']
    paths += [p for folder in [ROOT / 'tools/s13', ROOT / 'scripts/presentation/environment']
              for p in folder.rglob('*') if p.is_file() and '__pycache__' not in p.parts]
    for path in paths: sources['res://' + str(path.relative_to(ROOT))] = sha(path)
    write('source_hashes.json', {'runtime_at_capture': native['source_hashes_end'], 'final_delivery_sources': sources,
                               'pack_vs_workspace_source_differences': differences, 'concurrent_metadata_note': 'AU01 changed its offline audio source recipe during S13 archiving. This recipe is not consumed by the Showcase runtime. S13 production files match all 20 native frozen hashes; the performance/final-control packages differ only in the test probe.',
                               'fixture_note': 'Native normal path captured before adding the legacy replay/open-sea options; production runtime hashes remain identical.'})
    runs = []
    groups = set()
    for report_path in sorted((ROOT / '.local/validation/runs').glob('*/report.json')):
        report = json.loads(report_path.read_text())
        if not report['owner'].startswith('S13'): continue
        target = OUT / 'verification' / report['run_id']
        target.mkdir(parents=True, exist_ok=True)
        for path in report_path.parent.iterdir():
            if path.is_file(): shutil.copyfile(path, target / path.name)
        runs.append({'run_id': report['run_id'], 'owner': report['owner'], 'passed': report['passed'],
                     'exit_code': report['exit_code'], 'error': report.get('error'),
                     'report': str((target / 'report.json').relative_to(OUT))})
        for check in report['checks']:
            if check.get('process_group'): groups.add(check['process_group'])
    write('validation_runs.json', runs)
    process_rows = subprocess.run(['/bin/ps', '-axo', 'pgid=,pid=,command='], capture_output=True, text=True, timeout=5)
    assert process_rows.returncode == 0
    remaining = []
    for line in process_rows.stdout.splitlines():
        pieces = line.strip().split(None, 2)
        if len(pieces) == 3 and int(pieces[0]) in groups: remaining.append(line.strip())
    states = []
    for group in sorted(groups):
        try:
            os.killpg(group, 0)
            state = 'exists'
        except ProcessLookupError: state = 'absent'
        except PermissionError: state = 'permission_denied'
        states.append({'group': group, 'signal_zero': state})
    assert not remaining and all(row['signal_zero'] == 'absent' for row in states)
    browser_cleanup = {name: json.loads((OUT / name / 'run.json').read_text())['cleanup']
                       for name in ['chrome-attempt1', 'chrome-attempt2', 'chrome-attempt3', 'chrome']}
    assert all(all(value.get(key) for key in ['chromeClosed', 'serverClosed', 'profileRemoved']) for value in browser_cleanup.values())
    write('cleanup.json', {'owned_reports': len(runs), 'owned_process_groups': len(groups), 'groups': states,
                           'matching_ps_rows': remaining, 'browser_cleanup': browser_cleanup,
                           'scope': 'Only S13 process groups/profiles/servers; unrelated Godot, AU01 or user browser processes were never terminated.'})
    index = {str(p.relative_to(OUT)): {'bytes': p.stat().st_size, 'sha256': sha(p)}
             for p in OUT.rglob('*') if p.is_file() and p.name != 'evidence_index.json'}
    write('evidence_index.json', index)
    print(json.dumps({'phases': len(phases), 'controls_passed': len(controls['checks']),
                      'reports': len(runs), 'groups_absent': len(groups), 'evidence_files': len(index)}))

if __name__ == '__main__': main()
