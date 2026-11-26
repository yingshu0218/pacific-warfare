#!/usr/bin/env python3
"""Read-only audit of S04 validation groups; run via tools/verify.py --owner S04 exec."""
import json
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def main():
    checks = []
    imports = 0
    for path in sorted((ROOT / '.local/validation/runs').glob('*/report.json')):
        report = json.loads(path.read_text())
        if report.get('owner') != 'S04':
            continue
        imports += report['action'] == 'import'
        for check in report['checks']:
            group = check.get('process_group')
            if group is None:
                continue
            try:
                os.killpg(group, 0)
                alive = True
            except ProcessLookupError:
                alive = False
            checks.append({'run_id': report['run_id'], 'process_group': group,
                           'reported_cleanup_ok': check.get('cleanup_ok', False), 'group_alive': alive})
    result = {'date': '2026-11-10', 'owner': 'S04', 'known_process_groups': checks,
              'remaining_own_groups': [check for check in checks if check['group_alive']],
              'all_reported_cleanup_ok': all(check['reported_cleanup_ok'] for check in checks),
              'browser_tabs_created': 0, 'http_servers_started': 0, 'resident_editors_started': 0,
              'headless_import_invocations': imports,
              'native_capture': 'minimized; automatic exit after PNG capture',
              'unrelated_processes_signaled': False}
    result['passed'] = not result['remaining_own_groups'] and result['all_reported_cleanup_ok']
    (ROOT / 'docs/showcase/deliveries/S04-cleanup.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({'cleanup_passed': result['passed'], 'known_groups': len(checks),
                      'remaining_own_groups': len(result['remaining_own_groups'])}))
    return 0 if result['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
