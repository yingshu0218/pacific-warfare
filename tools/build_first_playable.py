#!/usr/bin/env python3
"""Build the admitted Showcase runtime with a normal, selectable scene entry."""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
from godot_paths import web_template_dir
import re
import shutil
import subprocess
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[1]
STAGE = ROOT / '.local/showcase-user-project'
OUTPUT = ROOT / 'build/first-playable'
RUNTIME = ROOT / 'tools/showcase_runtime.json'
VERSION = '4.7.2.stable.official.ed1daf0bf'

def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()

def admitted_sources():
    config = json.loads(RUNTIME.read_text())
    sources = {}
    for name in config['files']:
        path = ROOT / name
        if not path.is_file(): raise RuntimeError('Missing admitted resource: ' + name)
        for parent in path.parents:
            if parent == ROOT: break
            if (parent / '.gdignore').exists(): raise RuntimeError('Admitted resource is now ignored: ' + name)
        sources[name] = sha(path)
    return config, sources

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--owner', default='S08')
    parser.add_argument('--scene', default='all', choices=json.loads(RUNTIME.read_text())['entries'])
    args = parser.parse_args()
    config, sources = admitted_sources()
    if STAGE.exists(): shutil.rmtree(STAGE)
    STAGE.mkdir(parents=True)
    (STAGE.parent / '.gdignore').touch()
    for name in sources:
        target = STAGE / name; target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(ROOT / name, target)
    entry = config['entries'][args.scene]
    project = (ROOT / 'project.godot').read_text()
    project = re.sub(r'^config/name=.*$', 'config/name="海空交锋 · 全单位 Showcase"', project, flags=re.M)
    project = re.sub(r'^run/main_scene=.*$', 'run/main_scene="' + entry + '"', project, flags=re.M)
    project = re.sub(r'viewport_width=\d+', 'viewport_width=1280', project)
    project = re.sub(r'viewport_height=\d+', 'viewport_height=720', project)
    (STAGE / 'project.godot').write_text(project)
    templates = web_template_dir('4.7.2.stable')
    if (templates / 'version.txt').read_text().strip() != '4.7.2.stable': raise RuntimeError('Template version mismatch')
    template_hashes = {}
    for name in ['web_nothreads_release.zip', 'web_nothreads_debug.zip']:
        with zipfile.ZipFile(templates / name) as archive:
            if archive.testzip(): raise RuntimeError('Corrupt template: ' + name)
        template_hashes[name] = sha(templates / name)
    with zipfile.ZipFile(templates / 'web_nothreads_release.zip') as archive: shell = archive.read('godot.html').decode()
    shell = shell.replace('<html lang="en">', '<html lang="zh-CN">')
    shell = shell.replace('<canvas id="canvas">', '<canvas id="canvas" width="1280" height="720">')
    shell = shell.replace('$GODOT_HEAD_INCLUDE', '$GODOT_HEAD_INCLUDE\n<style>body{display:flex;align-items:center;justify-content:center;height:100vh;background:#102331}#canvas{width:min(100vw,calc(100vh * 16 / 9));height:auto;aspect-ratio:16/9}</style>')
    (STAGE / 'shell.html').write_text(shell)
    presets = (ROOT / 'export_presets.cfg').read_text().replace('html/canvas_resize_policy=2','html/canvas_resize_policy=0')
    raw_files = sorted(name for name in sources if name.endswith(('.json', '.txt')))
    presets = re.sub(r'^include_filter=".*"$', 'include_filter="' + ','.join(raw_files) + '"', presets, flags=re.M)
    presets += '\nhtml/custom_html_shell="res://shell.html"\n'
    (STAGE / 'export_presets.cfg').write_text(presets)
    OUTPUT.mkdir(parents=True, exist_ok=True)
    for path in OUTPUT.iterdir():
        if path.is_file(): path.unlink()
    reports = []
    for action in [['import'], ['godot','--','--export-release','Web',str(OUTPUT/'index.html')]]:
        command = [sys.executable,str(ROOT/'tools/verify.py'),'--owner',args.owner,'--timeout','240','--lock-timeout','60','--project',str(STAGE),*action]
        result = subprocess.run(command,cwd=ROOT,capture_output=True,text=True,timeout=310)
        print(result.stdout,end='',flush=True)
        if result.stderr: print(result.stderr,file=sys.stderr)
        if result.returncode: raise SystemExit(result.returncode)
        reports.append(json.loads(result.stdout.splitlines()[-1])['report'])
    all_sources = {**sources, 'project.godot':sha(STAGE/'project.godot'),'export_presets.cfg':sha(STAGE/'export_presets.cfg'),'shell.html':sha(STAGE/'shell.html')}
    manifest = {'schema':2,'engine':VERSION,'entry':entry,'scene':args.scene,'admission_manifest_sha256':sha(RUNTIME),
        'root_main_scene_unchanged':True,'templates':template_hashes,'reports':reports,'root_sources':sources,'sources':all_sources,
        'changes_from_S14':{name:{'before':config['baseline_hashes'][name],'after':value} for name,value in sources.items() if value!=config['baseline_hashes'][name]},
        'outputs':{p.name:{'bytes':p.stat().st_size,'sha256':sha(p)} for p in OUTPUT.iterdir() if p.is_file()}}
    (OUTPUT/'build_manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
    print('Showcase Web: ' + str(OUTPUT))

if __name__ == '__main__': main()
