"""Export the existing FX01 frozen input project, never refresh parallel DM01 sources."""
from pathlib import Path
import json,hashlib,shutil,subprocess,sys,zipfile
ROOT=Path(__file__).resolve().parents[2]
BASE=ROOT/'.local/fx01-project'
STAGE=ROOT/'.local/fx01-web-project'
OUT=ROOT/'build/fx01-web'
OUT.mkdir(parents=True,exist_ok=True)
native=json.loads((ROOT/'docs/showcase/evidence/FX01/runtime_inputs.json').read_text())
# Undo the first export attempt's validation-only project settings in native stage.
for name in ['project.godot','export_presets.cfg']:
    if hashlib.sha256((BASE/name).read_bytes()).hexdigest()!=native['sources'][name]:
        assert hashlib.sha256((ROOT/name).read_bytes()).hexdigest()==native['sources'][name]
        shutil.copy2(ROOT/name,BASE/name)
for directory in ['scripts','scenes','data','assets','aircraft','ui','showcase']:
    target=STAGE/directory
    if target.exists():shutil.rmtree(target)
    shutil.copytree(BASE/directory,target)
for p in (STAGE/'showcase').iterdir():
    if p.name not in ['first_playable.tscn','island_harbor.tscn','open_sea.tscn']:p.unlink()
# Unreferenced AU01 candidates are not part of this visual validation pack.
if (STAGE/'assets/audio/au01').exists():shutil.rmtree(STAGE/'assets/audio/au01')
for name in ['tests/fx01_web_probe.gd','tests/scenes/fx01_web.tscn','tests/fixtures/fx01_demo.gd','tests/fixtures/fx01_runtime_fixture.gd','tests/fixtures/fx01_legacy_effects.gd','tests/fixtures/combat_fixture.gd','project.godot','export_presets.cfg']:
    target=STAGE/name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(BASE/name,target)
project=(STAGE/'project.godot').read_text().replace('config/name="Yamato · 1944 study"','config/name="FX01 战斗效果验证"').replace('run/main_scene="res://scenes/main.tscn"','run/main_scene="res://tests/scenes/fx01_web.tscn"').replace('viewport_width=1440','viewport_width=1280').replace('viewport_height=900','viewport_height=720')
(STAGE/'project.godot').write_text(project)
templates=Path.home()/'Library/Application Support/Godot/export_templates/4.7.2.stable'
assert (templates/'version.txt').read_text().strip()=='4.7.2.stable'
with zipfile.ZipFile(templates/'web_nothreads_release.zip') as z:shell=z.read('godot.html').decode()
shell=shell.replace('<html lang="en">','<html lang="zh-CN">').replace('<canvas id="canvas">','<canvas id="canvas" width="1280" height="720">').replace('$GODOT_HEAD_INCLUDE','$GODOT_HEAD_INCLUDE\n<style>body{display:flex;justify-content:center;align-items:center;height:100vh}#canvas{width:1280px;height:720px}</style>\n<script src="measure.js"></script>')
(STAGE/'shell.html').write_text(shell)
presets=(STAGE/'export_presets.cfg').read_text().replace('html/canvas_resize_policy=2','html/canvas_resize_policy=0').replace('docs/*,tests/*,tools/*','docs/*,tools/*')
if 'html/custom_html_shell=' not in presets:presets+='\nhtml/custom_html_shell="res://shell.html"\n'
(STAGE/'export_presets.cfg').write_text(presets)
reports=[]
for action in [['import'],['godot','--','--export-release','Web',str(OUT/'index.html')]]:
 r=subprocess.run([sys.executable,str(ROOT/'tools/verify.py'),'--owner','FX01-web-build','--timeout','180','--lock-timeout','30','--project',str(STAGE),*action],cwd=ROOT,text=True,capture_output=True,timeout=235)
 print(r.stdout,end='',flush=True)
 if r.stderr:print(r.stderr,file=sys.stderr)
 if r.returncode:raise SystemExit(r.returncode)
 reports.append(json.loads(r.stdout.splitlines()[-1])['report'])
shutil.copy2(ROOT/'tools/fx01/measure.js',OUT/'measure.js')
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
manifest={'entry':'res://tests/scenes/fx01_web.tscn','engine':'4.7.2.stable.official.ed1daf0bf','reports':reports,'scope':'Frozen S10/S13 stage with FX01 overlay; no live DM01 sources copied','templates':{p.name:sha(p) for p in templates.glob('web_nothreads_*.zip')},'sources':{str(p.relative_to(STAGE)):sha(p) for p in STAGE.rglob('*') if p.is_file() and '.godot' not in p.parts and 'docs' not in p.relative_to(STAGE).parts},'outputs':{p.name:{'sha256':sha(p),'bytes':p.stat().st_size} for p in OUT.iterdir() if p.is_file() and p.name!='build_manifest.json'}}
(OUT/'build_manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
print('FX01 isolated Web export ready',OUT)
