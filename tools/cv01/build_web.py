#!/usr/bin/env python3
"""Freeze an isolated CV01 dependency closure; never export the live baseline project."""
import hashlib,json,os,re,shutil,subprocess,sys,zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
STAGE=ROOT/'.local/cv01-web-project'
OUT=ROOT/'build/cv01-web'
EVIDENCE=ROOT/'docs/showcase/evidence/CV01'
ENTRY='naval/essex_cv9_1944_04_15/inspection/inspection.tscn'
SHA=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()

def main():
 pending=[p for p in (ROOT/'naval/essex_cv9_1944_04_15').rglob('*') if p.suffix in ['.gd','.gdshader','.json','.tscn'] and p.name!='test_essex.gd']
 sources={}
 while pending:
  p=Path(os.path.abspath(pending.pop()));name=str(p.relative_to(ROOT))
  if name in sources:continue
  sources[name]=SHA(p)
  if p.suffix not in ['.gd','.gdshader','.json','.tscn','.tres']:continue
  for value in re.findall(r'\"(res://[^\"\n]+)\"',p.read_text()):
   q=ROOT/value[6:]
   if q.is_file():pending.append(q)
 assert all(not n.startswith(('data/units/','data/ammunition/','docs/','showcase/','scripts/simulation/')) for n in sources)
 if STAGE.exists():shutil.rmtree(STAGE)
 STAGE.mkdir(parents=True);OUT.mkdir(parents=True,exist_ok=True)
 for name in sources:
  target=STAGE/name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(ROOT/name,target)
 project='''config_version=5
[application]
config/name="CV01 USS Essex · isolated inspection"
run/main_scene="res://'''+ENTRY+'''"
config/features=PackedStringArray("4.7")
[display]
window/size/viewport_width=1440
window/size/viewport_height=900
window/stretch/mode="canvas_items"
[rendering]
renderer/rendering_method="gl_compatibility"
'''
 (STAGE/'project.godot').write_text(project)
 templates=Path.home()/'Library/Application Support/Godot/export_templates/4.7.2.stable'
 assert (templates/'version.txt').read_text().strip()=='4.7.2.stable'
 with zipfile.ZipFile(templates/'web_nothreads_release.zip') as archive:shell=archive.read('godot.html').decode()
 shell=shell.replace('<canvas id="canvas">','<canvas id="canvas" width="1440" height="900">').replace('$GODOT_HEAD_INCLUDE','$GODOT_HEAD_INCLUDE\n<style>html,body{margin:0;width:100%;height:100%;overflow:hidden}#canvas{width:1440px;height:900px}</style>')
 (STAGE/'shell.html').write_text(shell)
 presets='''[preset.0]
name="Web"
platform="Web"
runnable=true
export_filter="all_resources"
include_filter="naval/**/*.json"
exclude_filter=""
export_path="'''+str(OUT/'index.html')+'''"
[preset.0.options]
variant/extensions_support=false
variant/thread_support=false
vram_texture_compression/for_desktop=true
vram_texture_compression/for_mobile=false
html/export_icon=true
html/canvas_resize_policy=0
html/focus_canvas_on_start=true
html/custom_html_shell="res://shell.html"
progressive_web_app/enabled=false
'''
 (STAGE/'export_presets.cfg').write_text(presets)
 reports=[]
 for action in [['import'],['godot','--','--export-release','Web',str(OUT/'index.html')]]:
  command=[sys.executable,str(ROOT/'tools/verify.py'),'--owner','CV01','--timeout','160','--lock-timeout','5','--project',str(STAGE),*action]
  result=subprocess.run(command,cwd=ROOT,capture_output=True,text=True,timeout=190)
  print(result.stdout,end='',flush=True)
  if result.stderr:print(result.stderr,file=sys.stderr)
  report=json.loads(result.stdout.splitlines()[-1])['report'];reports.append(report)
  if result.returncode:raise SystemExit(result.returncode)
 assert all(SHA(ROOT/name)==value for name,value in sources.items()),'Input changed during freeze/build'
 manifest={'engine':'4.7.2.stable.official.ed1daf0bf','entry':ENTRY,'scope':'one carrier + 3 static aircraft; no simulation, S14 or operations','source_sha256':sources,'reports':reports,'template_sha256':{n:SHA(templates/n) for n in ['web_nothreads_release.zip','web_nothreads_debug.zip']},'output_sha256':{p.name:SHA(p) for p in OUT.iterdir() if p.is_file() and p.name!='build_manifest.json'}}
 (OUT/'build_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n');(EVIDENCE/'build_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
 print('CV01 isolated frozen Web build:',len(sources),'source files')
if __name__=='__main__':main()
