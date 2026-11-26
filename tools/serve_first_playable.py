#!/usr/bin/env python3
"""Bounded localhost static preview. No browser scanning or measurement injection."""
import argparse
import datetime as dt
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import signal
import threading
import time

ROOT=Path(__file__).resolve().parents[1]

def preview_instructions(port: int, seconds: float) -> str:
    return (f'在 Ego Lite 打开 http://127.0.0.1:{port}/index.html\n'
            f'在终端按 Ctrl-C 停止预览（最长 {seconds:g} 秒）。')

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--port',type=int,default=8765)
    parser.add_argument('--seconds',type=float,default=3600)
    parser.add_argument('--evidence',type=Path,help='Optional server lifetime audit only')
    parser.add_argument('--ready-file',type=Path,help=argparse.SUPPRESS)
    args=parser.parse_args()
    if not 0<args.seconds<=43200: parser.error('--seconds must be >0 and <=43200')
    stopped=threading.Event()
    class Handler(SimpleHTTPRequestHandler):
        extensions_map={**SimpleHTTPRequestHandler.extensions_map,'.wasm':'application/wasm','.js':'text/javascript'}
        def log_message(self,*_): pass
        def end_headers(self):
            self.send_header('Cache-Control','no-store');super().end_headers()
        def do_GET(self):
            if self.path=='/favicon.ico': self.send_response(204);self.end_headers();return
            super().do_GET()
        def do_POST(self):
            if self.path!='/stop': self.send_error(404);return
            self.send_response(200);self.end_headers();stopped.set()
    server=ThreadingHTTPServer(('127.0.0.1',args.port),partial(Handler,directory=str(ROOT/'build/first-playable')))
    server.timeout=.25;server.daemon_threads=True
    signal.signal(signal.SIGTERM,lambda *_:stopped.set())
    signal.signal(signal.SIGINT,lambda *_:stopped.set())
    start=time.monotonic();opened=dt.datetime.now(dt.timezone.utc).isoformat()
    try:
        instructions=preview_instructions(server.server_port,args.seconds)
        print(instructions,flush=True)
        if args.ready_file:
            pending=args.ready_file.with_suffix('.tmp')
            pending.write_text(instructions,encoding='utf-8')
            pending.replace(args.ready_file)
        while not stopped.is_set() and time.monotonic()-start<args.seconds: server.handle_request()
    finally:
        server.server_close()
        audit={'opened_utc':opened,'closed_utc':dt.datetime.now(dt.timezone.utc).isoformat(),'duration_s':time.monotonic()-start,'server_closed':True,'browser_process_scanning':False}
        if args.evidence:
            args.evidence.mkdir(parents=True,exist_ok=True)
            (args.evidence/'server_cleanup.json').write_text(json.dumps(audit,indent=2)+'\n')
        print(json.dumps(audit),flush=True)

if __name__=='__main__': main()
