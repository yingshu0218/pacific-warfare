#!/usr/bin/env python3
"""Freeze/export isolated CV02 dependency closure, without changing root project.

Every Godot subprocess obtains tools/verify.py --owner CV02's shared lock.
"""
import hashlib
import json
import re
import shutil
import subprocess
import sys
import zipfile
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
STAGE=ROOT/".local/cv02-web-project"
OUT=ROOT/"build/cv02-web"
EVIDENCE=ROOT/"docs/showcase/evidence/CV02"
ENTRY="naval/shokaku_1941_08_23/inspection/inspection.tscn"

def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()

def closure():
    pending=[p for p in (ROOT/"naval/shokaku_1941_08_23").rglob("*")
             if p.suffix in [".gd",".gdshader",".json",".tscn"] and p.name!="test_shokaku.gd"]
    sources={}
    while pending:
        path=pending.pop().resolve()
        name=str(path.relative_to(ROOT))
        if name in sources: continue
        sources[name]=sha(path)
        for value in re.findall(r'"(res://[^"\n]+)"',path.read_text()):
            candidate=ROOT/value[6:]
            if candidate.is_file(): pending.append(candidate)
    assert not any(n.startswith(("data/units/","data/ammunition/","docs/","showcase/","scripts/simulation/","naval/essex")) for n in sources)
    return sources

def main():
    sources=closure()
    if STAGE.exists(): shutil.rmtree(STAGE)
    STAGE.mkdir(parents=True); OUT.mkdir(parents=True,exist_ok=True)
    for name in sources:
        target=STAGE/name; target.parent.mkdir(parents=True,exist_ok=True); shutil.copy2(ROOT/name,target)
    (STAGE/"project.godot").write_text('''config_version=5
[application]
config/name="CV02 Shokaku · isolated inspection"
run/main_scene="res://'''+ENTRY+'''"
config/features=PackedStringArray("4.7")
[display]
window/size/viewport_width=1440
window/size/viewport_height=900
window/stretch/mode="canvas_items"
[rendering]
renderer/rendering_method="gl_compatibility"
''')
    templates=Path.home()/"Library/Application Support/Godot/export_templates/4.7.2.stable"
    assert (templates/"version.txt").read_text().strip()=="4.7.2.stable"
    with zipfile.ZipFile(templates/"web_nothreads_release.zip") as archive: shell=archive.read("godot.html").decode()
    shell=shell.replace('<canvas id="canvas">','<canvas id="canvas" width="1440" height="900">').replace('$GODOT_HEAD_INCLUDE','$GODOT_HEAD_INCLUDE\n<style>html,body{margin:0;width:100%;height:100%;overflow:hidden}#canvas{width:1440px;height:900px}</style>')
    (STAGE/"shell.html").write_text(shell)
    (STAGE/"export_presets.cfg").write_text('''[preset.0]
name="Web"
platform="Web"
runnable=true
export_filter="all_resources"
include_filter="naval/**/*.json"
exclude_filter=""
export_path="'''+str(OUT/"index.html")+'''"
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
''')
    reports=[]
    for action in [["import"],["godot","--","--export-release","Web",str(OUT/"index.html")]]:
        command=[sys.executable,str(ROOT/"tools/verify.py"),"--owner","CV02","--timeout","160","--lock-timeout","15","--project",str(STAGE),*action]
        result=subprocess.run(command,cwd=ROOT,capture_output=True,text=True,timeout=190)
        print(result.stdout,end="",flush=True)
        if result.stderr: print(result.stderr,file=sys.stderr)
        reports.append(json.loads(result.stdout.splitlines()[-1])["report"])
        if result.returncode: raise SystemExit(result.returncode)
    assert all(sha(ROOT/name)==value for name,value in sources.items()),"Shared input changed while freezing; do not mix evidence versions"
    manifest={"engine":"4.7.2.stable.official.ed1daf0bf","entry":ENTRY,"scope":"Isolated carrier model, 3 unchanged static A6M and one D4Y dimension cage; no combat or flight operations",
              "source_sha256":sources,"reports":reports,"template_sha256":{n:sha(templates/n) for n in ["web_nothreads_release.zip","web_nothreads_debug.zip"]},
              "output_sha256":{p.name:sha(p) for p in OUT.iterdir() if p.is_file() and p.name!="build_manifest.json"}}
    (OUT/"build_manifest.json").write_text(json.dumps(manifest,indent=2)+"\n")
    (EVIDENCE/"build_manifest.json").write_text(json.dumps(manifest,indent=2)+"\n")
    print("CV02 frozen isolated Web project:",len(sources),"source files",flush=True)

if __name__=="__main__": main()
