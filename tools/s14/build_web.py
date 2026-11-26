#!/usr/bin/env python3
"""Export a bounded S14 acceptance pack from the frozen admitted runtime."""
import argparse,hashlib,json,shutil,subprocess,sys,zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 p=argparse.ArgumentParser();p.add_argument('--source',default='.local/s14-final-runtime');p.add_argument('--stage',default='.local/s14-final-web-project');p.add_argument('--output',default='build/s14-final-web');a=p.parse_args()
 source=(ROOT/a.source).resolve();stage=(ROOT/a.stage).resolve();out=(ROOT/a.output).resolve()
 assert not stage.exists(),'Use a fresh export stage'
 frozen=json.loads((source/'freeze_manifest.json').read_text())
 for name,h in frozen['sources'].items():assert sha(source/name)==h,'Frozen input changed '+name
 shutil.copytree(source,stage,ignore=shutil.ignore_patterns('.godot'))
 out.mkdir(parents=True,exist_ok=True)
 for name in ['tests/s14_web_probe.gd','tests/scenes/s14_web.tscn']:
  assert (source/name).is_file(),'Web observer must already be frozen with runtime'
 project=(stage/'project.godot').read_text().replace('run/main_scene="res://showcase/all_units.tscn"','run/main_scene="res://tests/scenes/s14_web.tscn"')
 (stage/'project.godot').write_text(project)
 templates=Path.home()/'Library/Application Support/Godot/export_templates/4.7.2.stable'
 assert (templates/'version.txt').read_text().strip()=='4.7.2.stable'
 with zipfile.ZipFile(templates/'web_nothreads_release.zip') as z:shell=z.read('godot.html').decode()
 shell=shell.replace('<html lang="en">','<html lang="zh-CN">').replace('<canvas id="canvas">','<canvas id="canvas" width="1280" height="720">')
 shell=shell.replace('$GODOT_HEAD_INCLUDE','$GODOT_HEAD_INCLUDE\n<style>body{margin:0;display:flex;align-items:center;justify-content:center;height:100vh;background:#102331}#canvas{width:min(100vw,calc(100vh * 16 / 9));height:auto;aspect-ratio:16/9}</style>\n<script src="measure.js"></script>')
 (stage/'shell.html').write_text(shell)
 presets=(stage/'export_presets.cfg').read_text().replace('html/canvas_resize_policy=2','html/canvas_resize_policy=0').replace('docs/*,tests/*,tools/*','docs/*,tools/*')
 (stage/'export_presets.cfg').write_text(presets+'\nhtml/custom_html_shell="res://shell.html"\n')
 reports=[]
 for action in [['import'],['godot','--','--export-release','Web',str(out/'index.html')]]:
  r=subprocess.run([sys.executable,str(ROOT/'tools/verify.py'),'--owner','S14-web-build','--timeout','120','--lock-timeout','60','--project',str(stage),*action],cwd=ROOT,capture_output=True,text=True,timeout=190)
  print(r.stdout,end='',flush=True)
  if r.stderr:print(r.stderr,file=sys.stderr)
  if r.returncode:raise SystemExit(r.returncode)
  reports.append(json.loads(r.stdout.strip().splitlines()[-1])['report'])
 shutil.copy2(ROOT/'tools/s14/measure.js',out/'measure.js')
 manifest={'engine':'4.7.2.stable.official.ed1daf0bf','entry':'res://tests/scenes/s14_web.tscn','normal_entry':'res://showcase/all_units.tscn','source_freeze':frozen,'reports':reports,'sources':{str(p.relative_to(stage)):sha(p) for p in stage.rglob('*') if p.is_file() and '.godot' not in p.parts and p.name!='freeze_manifest.json'},'outputs':{p.name:{'bytes':p.stat().st_size,'sha256':sha(p)}for p in out.iterdir()if p.is_file()and p.name!='build_manifest.json'}}
 (out/'build_manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
 (ROOT/'docs/showcase/evidence/S14/final/build_manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
 print(json.dumps({'output':str(out),'files':len(manifest['sources']),'cv01_excluded':not any('essex' in k for k in manifest['sources'])}))
if __name__=='__main__':main()
