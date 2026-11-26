#!/usr/bin/env python3
"""Isolated S13 Chrome pack. Does not alter the root entry or S08 build."""
import hashlib
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[2]
STAGE = ROOT / '.local/s13-web-project'
OUTPUT = ROOT / 'build/s13-web'

def main():
    global STAGE, OUTPUT
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--variant', choices=['base', 'fog-fix'], default='base')
    args = parser.parse_args()
    if args.variant == 'fog-fix':
        STAGE = ROOT / '.local/s13-fog-web-project'
        OUTPUT = ROOT / 'build/s13-fog-web'
    owner = 'S13-fog-build' if args.variant == 'fog-fix' else 'S13-web-build'
    STAGE.mkdir(parents=True, exist_ok=True)
    OUTPUT.mkdir(parents=True, exist_ok=True)
    extensions = {'.gd', '.gdshader', '.tscn', '.tres', '.json', '.otf', '.uid'}
    def ignore(directory, names):
        ignored = []
        for name in names:
            path = Path(directory) / name
            if path.is_dir():
                if name in {'.godot', 'screenshots', 'evidence', 'backups', 'reference', 'references'}:
                    ignored.append(name)
            elif path.suffix not in extensions and name != 'LICENSE.txt':
                if not ('presentation/environment' in str(path) and path.suffix in {'.png', '.import'}):
                    ignored.append(name)
        return ignored
    for directory in ['scripts', 'scenes', 'data', 'assets', 'aircraft', 'ui', 'showcase']:
        target = STAGE / directory
        if target.exists(): shutil.rmtree(target)
        shutil.copytree(ROOT / directory, target, ignore=ignore)
    for path in (STAGE / 'showcase').iterdir():
        if path.name not in {'island_harbor.tscn', 'open_sea.tscn', 'first_playable.tscn'}: path.unlink()
    for relative in ['tests/cloud_sea_web_probe.gd', 'tests/scenes/cloud_sea_web.tscn', 'tests/fixtures/s13_original_ocean.gdshader']:
        target = STAGE / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(ROOT / relative, target)
    project = (ROOT / 'project.godot').read_text()
    project = project.replace('config/name="Yamato · 1944 study"', 'config/name="S13 云海实际验证"')
    project = project.replace('run/main_scene="res://scenes/main.tscn"', 'run/main_scene="res://tests/scenes/cloud_sea_web.tscn"')
    project = project.replace('viewport_width=1440', 'viewport_width=1280').replace('viewport_height=900', 'viewport_height=720')
    (STAGE / 'project.godot').write_text(project)
    template_dir = Path.home() / 'Library/Application Support/Godot/export_templates/4.7.2.stable'
    assert (template_dir / 'version.txt').read_text().strip() == '4.7.2.stable'
    templates = {}
    for name in ['web_nothreads_release.zip', 'web_nothreads_debug.zip']:
        path = template_dir / name
        with zipfile.ZipFile(path) as archive: assert archive.testzip() is None
        templates[name] = hashlib.sha256(path.read_bytes()).hexdigest()
    with zipfile.ZipFile(template_dir / 'web_nothreads_release.zip') as archive:
        shell = archive.read('godot.html').decode()
    shell = shell.replace('<html lang="en">', '<html lang="zh-CN">')
    shell = shell.replace('<canvas id="canvas">', '<canvas id="canvas" width="1280" height="720">')
    shell = shell.replace('$GODOT_HEAD_INCLUDE', '''$GODOT_HEAD_INCLUDE
<style>body{display:flex;justify-content:center;align-items:center;height:100vh;background:#102331}#canvas{width:min(100vw,calc(100vh * 16 / 9));height:auto;aspect-ratio:16/9}</style>
<script src="measure_s13.js"></script>''')
    shell = shell.replace('const engine = new Engine(GODOT_CONFIG);', 'const engine = new Engine(GODOT_CONFIG);\nwindow.showcaseEngine = engine;')
    (STAGE / 'shell.html').write_text(shell)
    presets = (ROOT / 'export_presets.cfg').read_text().replace('html/canvas_resize_policy=2', 'html/canvas_resize_policy=0')
    presets = presets.replace('docs/*,tests/*,tools/*', 'docs/*,tools/*')
    (STAGE / 'export_presets.cfg').write_text(presets + '\nhtml/custom_html_shell="res://shell.html"\n')
    reports = []
    for action in [['import'], ['godot', '--', '--export-release', 'Web', str(OUTPUT / 'index.html')]]:
        result = subprocess.run([sys.executable, str(ROOT / 'tools/verify.py'), '--owner', owner, '--timeout', '180', '--lock-timeout', '60', '--project', str(STAGE), *action], cwd=ROOT, capture_output=True, text=True, timeout=250)
        print(result.stdout, end='', flush=True)
        if result.stderr: print(result.stderr, file=sys.stderr)
        if result.returncode: raise SystemExit(result.returncode)
        reports.append(json.loads(result.stdout.splitlines()[-1])['report'])
    shutil.copyfile(ROOT / 'tools/s13/measure_s13.js', OUTPUT / 'measure_s13.js')
    sources = {str(p.relative_to(STAGE)): hashlib.sha256(p.read_bytes()).hexdigest() for p in STAGE.rglob('*') if p.is_file() and '.godot' not in p.parts}
    outputs = {p.name: {'bytes': p.stat().st_size, 'sha256': hashlib.sha256(p.read_bytes()).hexdigest()} for p in OUTPUT.iterdir() if p.is_file() and p.name != 'build_manifest.json'}
    manifest = {'engine': '4.7.2.stable.official.ed1daf0bf', 'variant': args.variant, 'templates': templates, 'reports': reports, 'sources': sources, 'outputs': outputs, 'entry': 'res://tests/scenes/cloud_sea_web.tscn'}
    (OUTPUT / 'build_manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')
    print('S13 isolated Web build:', OUTPUT)

if __name__ == '__main__': main()
