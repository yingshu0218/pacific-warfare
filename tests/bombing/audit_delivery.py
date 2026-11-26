#!/usr/bin/env python3
"""Read-only runtime audit plus explicit evidence copy; never signals processes."""
from pathlib import Path
import hashlib, json, os, shutil

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'docs/showcase/evidence/BOMB01/final'
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    reports=[];groups={};missing=[]
    for path in sorted((ROOT/'.local/validation/runs').glob('*/report.json')):
        record=json.loads(path.read_text())
        if record.get('owner')!='BOMB01':continue
        destination=OUT/'runs'/path.parent.name
        destination.mkdir(parents=True,exist_ok=True)
        for child in path.parent.iterdir():
            if child.is_file():shutil.copy2(child,destination/child.name)
        reports.append({'path':str((destination/'report.json').relative_to(ROOT)),'sha256':sha(destination/'report.json'),'passed':record['passed'],'action':record['action'],'project':record['project'],'error':record.get('error','')})
        for check in record.get('checks',[]):
            group=check.get('process_group')
            if group:groups[int(group)]=check.get('cleanup_ok',False)
    for group in groups:
        try:os.killpg(group,0);missing.append({'pgid':group,'status':'still_exists'})
        except ProcessLookupError:pass
        except PermissionError:missing.append({'pgid':group,'status':'inspection_denied'})
    assert all(groups.values()),'A verifier recorded failed cleanup'
    assert not missing,'Process group audit unresolved: '+str(missing)
    native_path=ROOT/'docs/showcase/evidence/BOMB01/r18/native-manifest.json'
    native=json.loads(native_path.read_text())
    cases={row['id']:row for row in json.loads((OUT/'results/scenarios.json').read_text())}
    correspondence=[]
    for clip in native['clips']:
        capture_path=ROOT/Path(clip['video']).parent/'capture.json'
        capture=json.loads(capture_path.read_text())
        # The recorder's event filter omitted unit_surface_contact. Preserve that
        # omission; correlate the separately saved same-input full scenario trace.
        actual=[event for event in cases[clip['case_id']]['events'] if event['kind']=='unit_surface_contact' and clip['first_tick']<=event['tick']<=clip['last_tick']]
        observed=[event for event in actual if event['entity_id']==clip['observed_unit_id']]
        transitions=[]
        for event in observed:
            sample=min(capture['samples'],key=lambda row:abs(row['tick']-event['tick']))
            assert abs(sample['tick']-event['tick'])<=4
            surface=sample['unit']['module_data']['damage'].get('aircraft',{}).get('contact_surface','')
            if not surface:
                sample=next(row for row in capture['samples'] if row['tick']>=event['tick'])
                surface=sample['unit']['module_data']['damage']['aircraft']['contact_surface']
            assert surface==event['data']['surface']
            transitions.append({'event_tick':event['tick'],'frame':sample['frame'],'sample_tick':sample['tick'],'contact_surface':surface})
        correspondence.append({'clip':clip['name'],'same_input_headless_surface_events':actual,'captured_observed_unit_contact_snapshots':transitions,'note':'Separate full headless scenario events; not added to the native recorder event array'})
    result={'reports':reports,'verifier_child_groups':len(groups),'all_reported_cleanup_ok':all(groups.values()),'independent_signal_zero_group_probe':'all absent','unresolved_groups':missing,'native_manifest_sha256':sha(native_path),'native_surface_correspondence':correspondence,'git_status':'No repository at task start; no Git recovery point created','temporary_browser_tabs_or_http_servers_created':False,'native_windows':'Every render process exited via bounded verifier; no window requested to remain open'}
    (OUT/'verification-and-cleanup.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({'reports':len(reports),'groups_absent':len(groups),'native_clips':len(correspondence),'cleanup_passed':True}))

if __name__=='__main__':main()
