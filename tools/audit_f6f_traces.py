#!/usr/bin/env python3
"""Audit observed F6F trajectories and native capture provenance, without replay."""
import bisect
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/showcase/evidence/S04-spatial'


def norm(v):
    length = math.sqrt(sum(x*x for x in v))
    return [x/length for x in v]


def main():
    trace = json.loads((OUT/'four-after.json').read_text())
    starts = [e for e in trace['timeline'] if e['mode'] == 'split_s_roll']
    completed = []
    for entry in starts:
        timeline = [e for e in trace['timeline'] if e['id'] == entry['id'] and e['time_s'] > entry['time_s']]
        pull = next((e for e in timeline if e['mode'] == 'split_s_pull'), None)
        if pull is None: continue
        end = next((e for e in timeline if e['time_s'] > pull['time_s'] and e['mode'] != 'split_s_pull'), None)
        if end is None: continue
        rows = [r for r in trace['samples'] if r['id'] == entry['id']]
        before = min(rows, key=lambda r: abs(r['time_s']-entry['time_s']))
        after = min(rows, key=lambda r: abs(r['time_s']-end['time_s']))
        active = [r for r in rows if entry['time_s'] <= r['time_s'] <= end['time_s']]
        a, b = norm(before['velocity_mps']), norm(after['velocity_mps'])
        reversed_angle = math.degrees(math.acos(max(-1,min(1,sum(x*y for x,y in zip(a,b))))))
        inverted_loaded = [r for r in active if r['mode'] == 'split_s_pull' and math.cos(r['rotation_rad'][0])*math.cos(r['rotation_rad'][2]) < -.6 and r['load_g'] > 2]
        row = {'id':entry['id'], 'roll_start_s':entry['time_s'], 'pull_start_s':pull['time_s'],
               'end_s':end['time_s'], 'real_direction_change_deg':reversed_angle,
               'minimum_path_pitch_deg':min(r['pitch_deg'] for r in active),
               'max_body_roll_degps':max(abs(r['body_roll_rate_degps']) for r in active),
               'max_path_curvature_degps':max(r['path_curvature_degps'] for r in active),
               'loaded_inverted_samples':len(inverted_loaded), 'exit_path_pitch_deg':after['pitch_deg']}
        row['passed'] = (reversed_angle > 145 and row['minimum_path_pitch_deg'] < -70 and
                         row['max_body_roll_degps'] <= 60.01 and len(inverted_loaded) > 0 and after['pitch_deg'] > -15)
        completed.append(row)
    assert any(r['passed'] for r in completed), completed
    matches = []
    for name, directory, kind in [
        ('f6f-v3-split-final','.local/S04-f6f-v3-split-final-frames','four'),
        ('f6f-v3-reversal','.local/S04-f6f-v3-reversal-frames','four'),
        ('f6f-v3-current','.local/S04-f6f-v3-current-frames','current'),
        ('f6f-v3-observer','.local/S04-f6f-observer-frames','current'),
    ]:
        capture = json.loads((ROOT/directory/'capture.json').read_text())
        current = json.loads((OUT/(kind+'-after.json')).read_text())
        rows = [r for r in current['samples'] if r['id'] == capture['follow']]
        times = [r['time_s'] for r in rows]
        errors = []
        for row in capture['samples']:
            index = bisect.bisect_right(times,row['time_s'])
            a,b = rows[index-1],rows[index]
            t = (row['time_s']-a['time_s'])/(b['time_s']-a['time_s'])
            # Position interpolation only measures capture/replay agreement; it
            # is never used to render poses, modify simulation or generate paths.
            expected = [x+(y-x)*t for x,y in zip(a['position_m'],b['position_m'])]
            errors.append(math.dist(row['position_m'],expected))
        maximum = max(errors)
        assert maximum < .75,(name,maximum)
        matches.append({'capture':name,'case':kind,'id':capture['follow'],
                        'measured_samples':len(errors),'max_position_interpolation_error_m':maximum,'passed':True})
    result = {'passed':True,'completed_natural_split_s':completed,'capture_matches':matches,
              'near_vertical_note':'Horizontal heading/world-bank coordinates may wrap at vertical; body roll and actual path curvature remain finite.'}
    (OUT/'f6f-trajectory-audit.json').write_text(json.dumps(result,indent=2)+'\n')
    print('F6F observed trajectory/capture audit PASS')


if __name__ == '__main__': main()
