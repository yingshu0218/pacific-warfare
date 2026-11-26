#!/usr/bin/env python3
"""Freeze only the model inspection's dependency closure; use the shared validator."""
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[2]
STAGE = ROOT / '.local/s02-deck-web-project'
OUT = ROOT / 'build/s02-deck-web'
EVIDENCE = ROOT / 'docs/showcase/evidence/S02-deck'
ENTRY = 'scenes/inspection/yamato_deck_capture.tscn'
SHA = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()


def main():
    classes = {}
    for folder in ['scripts', 'assets']:
        for p in (ROOT / folder).rglob('*.gd'):
            match = re.search(r'^class_name\s+(\w+)', p.read_text(), re.M)
            if match:
                classes[match[1]] = p
    pending, sources = [ROOT / ENTRY], {}
    while pending:
        # Preserve resource aliases through the existing Iowa directory symlinks.
        # Canonicalizing them would remove the paths preloaded by the adapter.
        p = Path(os.path.abspath(pending.pop()))
        name = str(p.relative_to(ROOT))
        if name in sources:
            continue
        sources[name] = SHA(p)
        if p.suffix not in {'.gd','.gdshader','.tscn','.tres','.json'}:
            continue
        text = p.read_text()
        for value in re.findall(r'["\']([^"\'\n]+)["\']', text):
            if Path(value).suffix not in {'.gd','.gdshader','.tscn','.tres','.json','.png','.otf'} or '://' in value and not value.startswith('res://'):
                continue
            target = ROOT / value[6:] if value.startswith('res://') else p.parent / value
            if target.is_file() and target.resolve().is_relative_to(ROOT):
                pending.append(target)
        code = re.sub(r'#.*', '', text)
        for cls, target in classes.items():
            if re.search(r'\b' + re.escape(cls) + r'\b', code):
                pending.append(target)
    assert not any('ground' in name or 'first_playable' in name or 'environment/' in name for name in sources)
    if STAGE.exists():
        shutil.rmtree(STAGE)
    STAGE.mkdir(parents=True)
    OUT.mkdir(parents=True, exist_ok=True)
    for name in sources:
        target = STAGE / name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ROOT / name, target)
        uid = (ROOT / name).with_suffix((ROOT / name).suffix + '.uid')
        if uid.is_file():
            shutil.copy2(uid, target.with_suffix(target.suffix + '.uid'))
    project = (ROOT / 'project.godot').read_text()
    project = project.replace('res://scenes/main.tscn', 'res://' + ENTRY)
    project = project.replace('viewport_width=1440', 'viewport_width=1600').replace('viewport_height=900', 'viewport_height=1000')
    (STAGE / 'project.godot').write_text(project)
    templates = Path.home() / 'Library/Application Support/Godot/export_templates/4.7.2.stable'
    assert (templates / 'version.txt').read_text().strip() == '4.7.2.stable'
    hashes = {name: SHA(templates / name) for name in ['web_nothreads_release.zip', 'web_nothreads_debug.zip']}
    with zipfile.ZipFile(templates / 'web_nothreads_release.zip') as archive:
        assert archive.testzip() is None
        shell = archive.read('godot.html').decode()
    shell = shell.replace('<canvas id="canvas">', '<canvas id="canvas" width="1600" height="1000">')
    shell = shell.replace('$GODOT_HEAD_INCLUDE', '$GODOT_HEAD_INCLUDE\n<style>html,body{margin:0;width:100%;height:100%;overflow:hidden}#canvas{width:1600px;height:1000px}</style>')
    (STAGE / 'shell.html').write_text(shell)
    presets = (ROOT / 'export_presets.cfg').read_text().replace('html/canvas_resize_policy=2', 'html/canvas_resize_policy=0')
    (STAGE / 'export_presets.cfg').write_text(presets + '\nhtml/custom_html_shell="res://shell.html"\n')
    reports = []
    for action in [['import'], ['godot', '--', '--export-release', 'Web', str(OUT / 'index.html')]]:
        command = [sys.executable, str(ROOT / 'tools/verify.py'), '--owner', 'S02-deck-web-build', '--timeout', '180', '--lock-timeout', '50', '--project', str(STAGE), *action]
        result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=240)
        print(result.stdout, end='', flush=True)
        if result.stderr:
            print(result.stderr, file=sys.stderr)
        report = json.loads(result.stdout.splitlines()[-1])['report']
        reports.append(report)
        if result.returncode:
            raise SystemExit(result.returncode)
    assert all(SHA(ROOT / name) == value for name, value in sources.items()), 'Model input changed during freeze/build'
    manifest = {'engine':'4.7.2.stable.official.ed1daf0bf','entry':ENTRY,'scope':'Yamato inspection only; no first_playable, environment, ground or combat','source_sha256':sources,'template_sha256':hashes,'reports':reports,
                'output_sha256':{p.name:SHA(p) for p in OUT.iterdir() if p.is_file() and p.name != 'build_manifest.json'}}
    (OUT / 'build_manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    (EVIDENCE / 'build_manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print('S02-deck isolated pack:', len(sources), 'frozen source files')


if __name__ == '__main__':
    main()
