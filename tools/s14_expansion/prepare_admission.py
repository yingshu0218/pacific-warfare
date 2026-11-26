#!/usr/bin/env python3
"""Prepare a reviewable public admission proposal; never apply it."""
from pathlib import Path
import ast
import hashlib
import json
import re
import shutil

ROOT = Path(__file__).resolve().parents[2]
CAND = ROOT / 'candidates/s14-expansion'
sha = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
manifest_path = CAND / 'evidence/inputs-autonomous-b25-r8.json'
manifest = json.loads(manifest_path.read_text())
source = Path(manifest['frozen_inputs'])
web = json.loads((CAND / 'evidence/web-build-autonomous-final.json').read_text())
assert web['source_manifest']['files'] == manifest['files']
files = sorted(set(web['runtime_files']) - {'project.godot', 'export_presets.cfg'})
assert not any(p.startswith(('tests/', 'docs/', 'candidates/', '.')) for p in files)
assert all(sha(source / p) == manifest['files'][p] for p in files)

proposal = CAND / 'proposed'
(proposal / 'tools').mkdir(parents=True, exist_ok=True)
before = CAND / 'evidence/public-before'
baseline = json.loads((CAND / 'baseline-hashes.json').read_text())
assert all(sha(ROOT / p) == h for p, h in baseline.items())
config = json.loads((ROOT / 'tools/showcase_runtime.json').read_text())
old_names = set(config['files'])
config.update(baseline='S14 expansion R8 candidate; not admitted', files=files)
config['entries']['expanded'] = 'res://showcase/carrier_harbor.tscn'
config['baseline_hashes'] = {p: manifest['files'][p] for p in files}
config['candidate_source_manifest'] = str(manifest_path.relative_to(ROOT))
(proposal / 'tools/showcase_runtime.json').write_text(json.dumps(config, ensure_ascii=False, indent=2) + '\n')

# The normal builder must explicitly export raw JSON outside data/, including
# deck, airframe and interface metadata. Keep root project/entry settings intact.
builder = (ROOT / 'tools/build_first_playable.py').read_text()
needle = "    presets += '\\nhtml/custom_html_shell=\"res://shell.html\"\\n'"
addition = '''    raw_files = sorted(name for name in sources if name.endswith(('.json', '.txt')))
    presets = re.sub(r'^include_filter=".*"$', 'include_filter="' + ','.join(raw_files) + '"', presets, flags=re.M)
'''
assert builder.count(needle) == 1
builder = builder.replace(needle, addition + needle)
ast.parse(builder)
(proposal / 'tools/build_first_playable.py').write_text(builder)

patches = []
for name in files:
    public = ROOT / name
    after_hash = manifest['files'][name]
    before_hash = sha(public) if public.exists() else None
    if before_hash == after_hash:
        continue
    if public.exists():
        backup = before / name
        backup.parent.mkdir(parents=True, exist_ok=True)
        if backup.exists():
            assert sha(backup) == before_hash
        else:
            shutil.copy2(public, backup)
    patches.append({'path': name, 'before_sha256': before_hash,
                    'candidate_sha256': after_hash,
                    'candidate': str((source / name).relative_to(ROOT)),
                    'operation': 'replace' if public.exists() else 'add'})
for name in ['tools/showcase_runtime.json', 'tools/build_first_playable.py']:
    backup = before / name
    backup.parent.mkdir(parents=True, exist_ok=True)
    if backup.exists():
        assert sha(backup) == sha(ROOT / name)
    else:
        shutil.copy2(ROOT / name, backup)
    patches.append({'path': name, 'before_sha256': sha(ROOT / name),
                    'candidate_sha256': sha(proposal / name),
                    'candidate': str((proposal / name).relative_to(ROOT)),
                    'operation': 'replace', 'proposal_not_executed': True})

ordinary = json.loads((ROOT / 'build/first-playable/build_manifest.json').read_text())
output_checks = {name: sha(ROOT / 'build/first-playable' / name) == item['sha256']
                 for name, item in ordinary['outputs'].items()}
assert all(output_checks.values())
record = {
    'candidate_only': True, 'not_applied': True,
    'source_manifest': str(manifest_path.relative_to(ROOT)),
    'source_manifest_sha256': sha(manifest_path),
    'public_baseline_files': len(baseline), 'public_baseline_unchanged': True,
    'ordinary_build_matches_previous_manifest': True,
    'ordinary_build_checks': output_checks,
    'runtime_admission_count': len(files),
    'new_whitelist_admissions': sorted(set(files) - old_names),
    'candidate_patches': patches,
    'public_before_backup': str(before.relative_to(ROOT)),
    'root_project_settings_overwrite': False,
    'root_export_presets_overwrite': False,
    'root_run_helper_change_required': False,
    'after_review_only': 'Apply explicit paths, then build/test normal --scene expanded; BOMB remains separate.',
}
(CAND / 'evidence/public-change-plan.json').write_text(json.dumps(record, ensure_ascii=False, indent=2) + '\n')
print(json.dumps({'runtime_files': len(files), 'new_admissions': len(record['new_whitelist_admissions']),
                  'proposed_patches': len(patches), 'public_unchanged': True}))
