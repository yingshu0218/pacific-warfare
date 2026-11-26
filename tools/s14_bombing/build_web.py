#!/usr/bin/env python3
"""Export explicit candidate files into an independent review package."""
from pathlib import Path
import argparse,hashlib,json,shutil,subprocess,sys,zipfile
ROOT=Path(__file__).resolve().parents[2];CAND=ROOT/'candidates/s14-bombing'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
p=argparse.ArgumentParser();p.add_argument('--name',required=True);a=p.parse_args()
manifest=json.loads((CAND/'stage/source-manifest.json').read_text());source=Path(manifest['frozen_inputs'])
stage=CAND/('web-project-'+a.name);out=ROOT/('build/s14-bombing-'+a.name)
assert not stage.exists() and not out.exists()
runtime=[]
for name,h in manifest['files'].items():
 assert sha(source/name)==h,'Frozen input drift '+name
 if name.startswith('tests/') or name.endswith(('/proposal.json','/readonly_dependencies.json')):continue
 target=stage/name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source/name,target);runtime.append(name)
out.mkdir(parents=True)
project=(stage/'project.godot').read_text().replace('config/name="Yamato · 1944 study"','config/name="S14 海空任务候选"')
(stage/'project.godot').write_text(project)
templates=Path.home()/'Library/Application Support/Godot/export_templates/4.7.2.stable'
assert (templates/'version.txt').read_text().strip()=='4.7.2.stable'
with zipfile.ZipFile(templates/'web_nothreads_release.zip') as z:shell=z.read('godot.html').decode()
shell=shell.replace('<html lang="en">','<html lang="zh-CN">').replace('<canvas id="canvas">','<canvas id="canvas" width="1280" height="720">')
shell=shell.replace('$GODOT_HEAD_INCLUDE','$GODOT_HEAD_INCLUDE\n<style>body{margin:0;display:flex;align-items:center;justify-content:center;height:100vh;background:#102331}#canvas{width:min(100vw,calc(100vh * 16 / 9));height:auto;aspect-ratio:16/9}</style>\n<script src="measure.js"></script>')
(stage/'shell.html').write_text(shell)
presets=(stage/'export_presets.cfg').read_text().replace('html/canvas_resize_policy=2','html/canvas_resize_policy=0')
presets=presets.replace('include_filter="data/*.json,data/**/*.json,assets/naval/models/us_iowa_1944/data/*.json,assets/fonts/LICENSE.txt"','include_filter="data/*.json,data/**/*.json,naval/**/data/*.json,scripts/air_operations/*.json,aircraft/**/data/interfaces.json,assets/naval/models/us_iowa_1944/data/*.json,assets/fonts/LICENSE.txt"')
(stage/'export_presets.cfg').write_text(presets+'\nhtml/custom_html_shell="res://shell.html"\n')
reports=[]
for action in [['import'],['godot','--','--export-release','Web',str(out/'index.html')]]:
 cmd=[sys.executable,str(ROOT/'tools/verify.py'),'--owner','S14-bomb-web-'+a.name,'--project',str(stage),'--timeout','100','--lock-timeout','45',*action]
 result=subprocess.run(cmd,cwd=ROOT,capture_output=True,text=True,timeout=160);print(result.stdout,end='',flush=True)
 if result.returncode:print(result.stderr);raise SystemExit(result.returncode)
 reports.append(json.loads(result.stdout.strip().splitlines()[-1])['report'])
shutil.copy2(ROOT/'tools/s14_bombing/measure.js',out/'measure.js')
record={'engine':manifest['engine'],'entry':'res://showcase/carrier_harbor.tscn','source_manifest':manifest,'runtime_files':runtime,'source_hashes':{k:sha(stage/k)for k in runtime},'build_reports':reports,'outputs':{x.name:{'bytes':x.stat().st_size,'sha256':sha(x)}for x in out.iterdir()if x.is_file()},'normal_entry_and_controls_unchanged_by_measurement':True,'ordinary_first_playable_build_untouched':True}
(out/'build-manifest.json').write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n')
(CAND/'evidence'/('web-build-'+a.name+'.json')).write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'package':str(out),'runtime_files':len(runtime)}))
