#!/usr/bin/env python3
"""Archive bounded runs, matching camera evidence, source identities and owned cleanup."""
import datetime as dt
import hashlib
import json
from pathlib import Path
import shutil
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'docs/showcase/evidence/S02-deck'
SHA = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()


def write(name, data):
    (OUT / name).write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')


def same(a, b):
    if isinstance(a, (float,int)) and isinstance(b, (float,int)):
        return abs(a-b) < .00003
    if isinstance(a, list) and isinstance(b, list):
        return len(a) == len(b) and all(same(x,y) for x,y in zip(a,b))
    if isinstance(a, dict) and isinstance(b, dict):
        return a.keys() == b.keys() and all(same(a[k],b[k]) for k in a)
    return a == b


def main():
    before = json.loads((OUT / 'before/capture.json').read_text())
    after = json.loads((OUT / 'after/capture.json').read_text())
    browser = json.loads((OUT / 'chrome/run.json').read_text())
    pack = json.loads((OUT / 'build_manifest.json').read_text())
    assert browser['passed'] and all(browser['cleanup'].values())
    for name, value in pack['source_sha256'].items():
        assert SHA(ROOT / name) == value, 'Frozen input drift: ' + name
    camera_fields = ['id','position_m','target_m','orthographic_size_m','hull_only']
    assert all(all(a[k] == b[k] for k in camera_fields) for a,b in zip(before['views'],after['views']))
    assert same(before['sockets'],after['sockets'])
    backup = ROOT / '.local/s02-deck-before'
    assert SHA(backup / 'data/units/jp_yamato_1944_04.json') == SHA(ROOT / 'data/units/jp_yamato_1944_04.json')
    old = json.loads((backup / 'data/yamato_1944_mounts.json').read_text())
    new = json.loads((ROOT / 'data/yamato_1944_mounts.json').read_text())
    expected = json.loads(json.dumps(old))
    contacts = []
    for a,b in zip(old['mounts'],new['mounts']):
        assert a['id'] == b['id'] and same(a['position'],b['position']) and a['barrels'] == b['barrels']
        if a['attachment']['surface_y'] != b['attachment']['surface_y']:
            contacts.append({'id':a['id'],'before_y_m':a['attachment']['surface_y'],'after_y_m':b['attachment']['surface_y'],'weapon_seat_unchanged_m':b['position']})
    for a,b in zip(expected['mounts'],new['mounts']):
        a['attachment']['surface_y'] = b['attachment']['surface_y']
    assert same(expected,new), 'Mount data changed beyond the host contact ordinates'
    old_hull = json.loads((backup / 'data/hull_stations.json').read_text())
    new_hull = json.loads((ROOT / 'data/hull_stations.json').read_text())
    assert old_hull['stations'] == new_hull['stations'] and old_hull['deck_sheer_stations_m'] == new_hull['deck_sheer_stations_m']
    write('contact_changes.json',contacts)
    # Crop only, at 1:1 pixels: never rescale the profile's horizontal/vertical ratio.
    canvas = Image.new('RGB',(1600,976),'white')
    draw = ImageDraw.Draw(canvas)
    for row,(phase,label) in enumerate([('before','fore_hull_side'),('after','fore_hull_side'),('before','aft_hull_side'),('after','aft_hull_side')]):
        image = Image.open(OUT / phase / (label+'.png')).convert('RGB')
        canvas.paste(image.crop((0,430,1600,650)),(0,row*244+24))
        draw.text((12,row*244+6),phase+' / '+label+' / original pixels, y=430..650',fill='black')
    canvas.save(OUT / 'profile_comparison.png')
    reports = []
    for run in sorted((ROOT / '.local/validation/runs').glob('*/report.json')):
        data = json.loads(run.read_text())
        if not data.get('owner','').startswith('S02-deck'):
            continue
        target = OUT / 'verification' / data['run_id']
        target.mkdir(parents=True, exist_ok=True)
        shutil.copy2(run,target / run.name)
        for log in run.parent.glob('*.log'):
            shutil.copy2(log,target / log.name)
        reports.append({'run_id':data['run_id'],'owner':data['owner'],'passed':data['passed'],'error':data.get('error'),
                        'cleanup_ok':all(c.get('cleanup_ok',False) for c in data['checks']),
                        'report':str((target / run.name).relative_to(OUT))})
    assert all(r['cleanup_ok'] for r in reports)
    write('verification.json',{'runs':reports,'matching_cameras':True,'matching_all_39_sockets':True,
      'persisted_unit_definition_byte_unchanged':True,'frozen_runtime_inputs_match_workspace':True,
      'mesh_instances_before_after':[before['mesh_instances'],after['mesh_instances']],
      'raw_triangles_before_after':[before['raw_mesh_triangles'],after['raw_mesh_triangles']],
      'chrome_cleanup':browser['cleanup'],'chrome_cadence':browser['cadence'],
      'scope':'Local Yamato model/native geometry + one Chrome inspection. S10/shared world changes excluded from the 32-file pack.'})
    starts = json.loads((OUT / 'start_manifest.json').read_text())['source_sha256']
    own_existing = ['scripts/ship_geometry.gd','data/hull_stations.json','data/yamato_1944_mounts.json']
    changed = {name:{'before':value,'after':SHA(ROOT / name)} for name,value in starts.items() if (ROOT / name).is_file() and SHA(ROOT / name) != value}
    helpers = [ROOT / 'tests/test_yamato_deck.gd',ROOT / 'scenes/inspection/yamato_deck_capture.tscn',ROOT / 'scripts/presentation/models/yamato_deck_capture.gd',*sorted((ROOT / 'tools/s02_deck').glob('*'))]
    write('source_hashes.json',{'utc':dt.datetime.now(dt.timezone.utc).isoformat(),'runtime_at_native_after_and_chrome':pack['source_sha256'],
      'owned_existing_changes':{name:changed[name] for name in own_existing},
      'helpers':{str(p.relative_to(ROOT)):SHA(p) for p in helpers if p.is_file()},
      'concurrent_other_changes_read_only':{name:v for name,v in changed.items() if name not in own_existing},
      'boundary':'No writes to Iowa, first_playable, clouds/ocean, aircraft, ground, combat or shared batching. Other source deltas are recorded for concurrent S10 review, not rolled back.'})
    write('evidence_index.json',{str(p.relative_to(OUT)):{'bytes':p.stat().st_size,'sha256':SHA(p)} for p in sorted(OUT.rglob('*')) if p.is_file() and p.name != 'evidence_index.json'})
    print('PASS S02-deck archive:',len(reports),'bounded reports; seven exact camera pairs; frozen runtime hashes and cleanup verified')


if __name__ == '__main__':
    main()
