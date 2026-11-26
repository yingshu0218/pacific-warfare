#!/usr/bin/env python3
"""Build isolated DM01 review from an already frozen native-validation input."""
import argparse,hashlib,json,shutil,subprocess,sys,zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source',required=True)
    parser.add_argument('--output',default='build/dm01-web')
    parser.add_argument('--stage',default='')
    args=parser.parse_args()
    source=(ROOT/args.source).resolve();stage=(ROOT/args.stage).resolve() if args.stage else source.with_name(source.name+'-web');out=(ROOT/args.output).resolve()
    assert (source/'freeze_manifest.json').is_file() and not stage.exists(),'Use frozen source and a fresh web stage.'
    frozen=json.loads((source/'freeze_manifest.json').read_text())
    for name,expected in frozen['sources'].items():assert digest(source/name)==expected,'Frozen input changed: '+name
    shutil.copytree(source,stage,ignore=shutil.ignore_patterns('.godot'))
    # Legacy standalone airfield viewer is outside this frozen battle pack.
    for name in ['showcase.gd','showcase.gd.uid','showcase.tscn']:
        legacy=stage/'showcase'/name
        if legacy.exists(): legacy.unlink()
    out.mkdir(parents=True,exist_ok=True)
    for relative in ['tests/aircraft_damage_web_probe.gd','tests/scenes/aircraft_damage_web.tscn']:
        target=stage/relative;target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(ROOT/relative,target)
    project=(stage/'project.godot').read_text().replace('config/name="Yamato · 1944 study"','config/name="DM01 aircraft damage review"').replace('run/main_scene="res://scenes/main.tscn"','run/main_scene="res://tests/scenes/aircraft_damage_web.tscn"').replace('viewport_width=1440','viewport_width=1280').replace('viewport_height=900','viewport_height=720')
    (stage/'project.godot').write_text(project)
    templates=Path.home()/'Library/Application Support/Godot/export_templates/4.7.2.stable'
    assert (templates/'version.txt').read_text().strip()=='4.7.2.stable'
    with zipfile.ZipFile(templates/'web_nothreads_release.zip') as archive:shell=archive.read('godot.html').decode()
    shell=shell.replace('<canvas id="canvas">','<canvas id="canvas" width="1280" height="720">').replace('$GODOT_HEAD_INCLUDE','$GODOT_HEAD_INCLUDE\n<style>body{display:flex;justify-content:center;align-items:center;height:calc(100vh - 40px);margin:0;background:#102331}#canvas{width:min(100vw,calc((100vh - 40px) * 16 / 9));height:auto;aspect-ratio:16/9}</style>\n<script src="measure.js"></script>')
    (stage/'shell.html').write_text(shell)
    presets=(stage/'export_presets.cfg').read_text().replace('html/canvas_resize_policy=2','html/canvas_resize_policy=0').replace('docs/*,tests/*,tools/*','docs/*,tools/*')
    (stage/'export_presets.cfg').write_text(presets+'\nhtml/custom_html_shell="res://shell.html"\n')
    reports=[]
    for action in [['import'],['godot','--','--export-release','Web',str(out/'index.html')]]:
        result=subprocess.run([sys.executable,str(ROOT/'tools/verify.py'),'--owner','DM01','--timeout','120','--lock-timeout','45','--project',str(stage),*action],cwd=ROOT,capture_output=True,text=True,timeout=180)
        print(result.stdout,end='',flush=True)
        if result.stderr:print(result.stderr,file=sys.stderr)
        if result.returncode:raise SystemExit(result.returncode)
        reports.append(json.loads(result.stdout.splitlines()[-1])['report'])
    shutil.copyfile(ROOT/'tools/dm01/measure.js',out/'measure.js')
    manifest={'source_freeze':frozen,'reports':reports,'engine':'4.7.2.stable.official.ed1daf0bf','entry':'res://tests/scenes/aircraft_damage_web.tscn','sources':{str(p.relative_to(stage)):digest(p) for p in sorted(stage.rglob('*')) if p.is_file() and '.godot' not in p.parts},'outputs':{p.name:{'bytes':p.stat().st_size,'sha256':digest(p)}for p in out.iterdir()if p.is_file()and p.name!='build_manifest.json'}}
    (out/'build_manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
    print('DM01 isolated Web build:',out)
if __name__=='__main__':main()
