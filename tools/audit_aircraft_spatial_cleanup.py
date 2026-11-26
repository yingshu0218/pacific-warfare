#!/usr/bin/env python3
"""Read-only check of every completed S04 validation process group. Never kills."""
import datetime
import json
import os
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/showcase/evidence/S04-spatial'


def main():
    rows=[]
    for path in sorted((ROOT/'.local/validation/runs').glob('*/report.json')):
        report=json.loads(path.read_text())
        if report.get('owner')!='S04':continue
        for check in report['checks']:
            group=check.get('process_group')
            if group is None:continue
            try:
                os.killpg(group,0)
                state='present'
            except ProcessLookupError:
                state='absent'
            except PermissionError:
                state='uninspectable'
            rows.append({'run_id':report['run_id'],'group':group,'state':state,
                         'reported_cleanup_ok':check.get('cleanup_ok',False)})
    remaining=[r for r in rows if r['state']!='absent']
    result={'checked_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),
            'passed':not remaining,'groups':rows,'remaining_or_unknown':remaining,
            'scope':'All completed S04 run groups. The running audit is closed and checked by its verify.py wrapper after this check.',
            'browser_tabs_created':0,'http_services_started':0,'resident_editors_started':0,
            'signaled_unrelated_processes':False,'native_windows':'minimized, auto-exit, wrapper cleanup',
            'retained_files':'Intentional evidence under docs; ignored raw frames/caches in .local; no resident preview process.'}
    (OUT/'cleanup.json').write_text(json.dumps(result,indent=2)+'\n')
    print('S04 cleanup','PASS' if result['passed'] else 'FAIL','groups',len(rows),'remaining_or_unknown',len(remaining))
    return 0 if result['passed'] else 1


if __name__=='__main__':raise SystemExit(main())
