#!/usr/bin/env python3
"""One-command bounded native/Web preview; Ctrl-C closes only its owned processes."""
import argparse
from pathlib import Path
import subprocess
import sys
import json
from tempfile import TemporaryDirectory
from build_first_playable import admitted_sources, OUTPUT, RUNTIME

ROOT=Path(__file__).resolve().parents[1]

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode',choices=['native','web'])
    parser.add_argument('--build',action='store_true')
    parser.add_argument('--seconds',type=int,default=3600)
    parser.add_argument('--port',type=int,default=8765)
    parser.add_argument('--scene',choices=json.loads(RUNTIME.read_text())['entries'],
                        help='defaults to expanded for Web and all for native')
    parser.add_argument('--owner',default='local-preview')
    parser.add_argument('--quit-after-frames',type=int,help=argparse.SUPPRESS)
    args=parser.parse_args()
    if args.scene is None:
        args.scene = 'expanded' if args.mode == 'web' else 'all'
    if not 1<=args.seconds<=43200: parser.error('--seconds must be 1..43200')
    config,sources=admitted_sources()
    entry=config['entries'][args.scene]
    if args.mode=='web':
        try: manifest=json.loads((OUTPUT/'build_manifest.json').read_text())
        except (FileNotFoundError,ValueError): manifest={}
        stale=manifest.get('schema')!=2 or manifest.get('entry')!=entry or manifest.get('root_sources')!=sources
        if args.build or stale or not (OUTPUT/'index.html').exists():
            subprocess.run([sys.executable,str(ROOT/'tools/build_first_playable.py'),'--owner',args.owner,'--scene',args.scene],check=True,cwd=ROOT)
    command=[sys.executable,str(ROOT/'tools/verify.py'),'--owner',args.owner,'--timeout',str(args.seconds+15),'--lock-timeout','60']
    if args.mode=='native':
        command+=['godot','--render','--',entry]
        if args.quit_after_frames: command+=['--quit-after',str(args.quit_after_frames),'--position','-1800,0']
        return subprocess.call(command,cwd=ROOT)
    command+=['exec','--',sys.executable,str(ROOT/'tools/serve_first_playable.py'),'--port',str(args.port),'--seconds',str(args.seconds)]
    with TemporaryDirectory(prefix='pacific-preview-') as ready_dir:
        ready_file=Path(ready_dir)/'instructions.txt'
        command+=['--ready-file',str(ready_file)]
        with subprocess.Popen(command,cwd=ROOT) as preview:
            while preview.poll() is None and not ready_file.is_file():
                try:
                    preview.wait(timeout=0.1)
                except subprocess.TimeoutExpired:
                    pass
            if ready_file.is_file():
                print(ready_file.read_text(encoding='utf-8'),flush=True)
            return preview.wait()

if __name__=='__main__':
    try: sys.exit(main())
    except KeyboardInterrupt: sys.exit(130)
