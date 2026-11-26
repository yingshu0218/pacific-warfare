#!/usr/bin/env python3
"""Measure one or two unpacked regular Web exports inside an owned Ego Lite task space."""
import argparse
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import json
from math import ceil
from pathlib import Path
import signal
import subprocess
from threading import Thread
from uuid import uuid4


HERE = Path(__file__).resolve().parent
CONTROL = b'''<!doctype html><meta charset="utf-8"><title>PF01 canvas control</title>
<style>body{margin:0;display:flex;align-items:center;justify-content:center;height:100vh;
background:#102331}canvas{display:block;width:min(100vw,calc(100vh * 16 / 9));height:auto;aspect-ratio:16/9}</style>
<canvas width="1280" height="720" tabindex="0"></canvas><script>document.querySelector('canvas').focus()</script>'''


class Handler(SimpleHTTPRequestHandler):
    extensions_map = {**SimpleHTTPRequestHandler.extensions_map, ".wasm": "application/wasm", ".js": "text/javascript"}

    def __init__(self, *args, directories):
        self.directories = directories
        super().__init__(*args, directory=HERE)

    def log_message(self, *_):
        pass

    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def do_GET(self):
        if self.path == "/control.html":
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(CONTROL)))
            self.end_headers()
            self.wfile.write(CONTROL)
        else:
            super().do_GET()

    def translate_path(self, path):
        split = path.split("/", 2)
        if len(split) < 3 or split[1] not in self.directories:
            return str(HERE / "__pf01_missing__")
        parent = self.directory
        self.directory = self.directories[split[1]]
        try:
            return super().translate_path("/" + split[2])
        finally:
            self.directory = parent


def ego(script, timeout):
    result = subprocess.run(["ego-browser", "nodejs", "-e", script], text=True, capture_output=True, timeout=timeout)
    if result.stderr:
        print(result.stderr, end="", flush=True)
    if result.returncode:
        raise RuntimeError(f"Ego Lite exited {result.returncode}: {result.stdout.strip()}")
    return result.stdout


def receipt(output):
    return json.loads(next(line.removeprefix("PF01_JSON ") for line in output.splitlines() if line.startswith("PF01_JSON ")))


def percentiles(samples):
    values = sorted(samples)
    if not values:
        return {"n": 0}
    return {"n": len(values), **{f"p{pct}": values[ceil(pct * len(values) / 100) - 1] for pct in (50, 95, 99)}}


def summarize(result):
    frames = result["frames"]
    start, end = result["startWall"], result["endWall"]
    game_samples = result["gameSamples"]
    godot_frames = [row for sample in game_samples[1:] if sample["wall"] <= end for row in sample["frames"]]
    result["summary"] = {"wall_s": (end - start) / 1000, "raf_dispatch_ms": percentiles(row[0] for row in frames),
                         "raf_clock_ms": percentiles(row[1] for row in frames), "visibility": sorted({row[2] for row in frames}),
                         "focused": sorted({row[3] for row in frames})}
    if godot_frames:
        result["summary"]["godot_ms"] = {name: percentiles(row[index] for row in godot_frames) for index, name in
            ((0, "engine_delta"), (2, "session_advance"), (3, "presentation"), (4, "camera"), (5, "hud"))}


def interrupt(*_):
    raise KeyboardInterrupt


def main():
    parser = argparse.ArgumentParser(description="Run under tools/verify.py exec and its project lock")
    parser.add_argument("--baseline", type=Path, required=True)
    parser.add_argument("--candidate", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--seconds", type=int, default=40, choices=range(5, 91), metavar="5..90")
    parser.add_argument("--fighter-button", nargs=2, type=float, metavar=("X", "Y"),
                        help="documented fighter button center in a 1280x720 canvas; omit to retain the default camera")
    parser.add_argument("--pause-control", action="store_true", help="add a normal pause-button shortcut with S08 enabled")
    args = parser.parse_args()
    directories = {name: str(directory.resolve()) for name, directory in (("baseline", args.baseline), ("candidate", args.candidate)) if directory}
    for directory in directories.values():
        if not (Path(directory) / "index.html").is_file():
            parser.error(f"expected a regular Web export at {directory}")
    script = (HERE / "measure_ego.mjs").read_text()
    space_id = None
    evidence = {"arms": {}, "cleanup": False}
    signal.signal(signal.SIGTERM, interrupt)
    with ThreadingHTTPServer(("127.0.0.1", 0), partial(Handler, directories=directories)) as server:
        thread = Thread(target=server.serve_forever, daemon=True)
        thread.start()
        try:
            name = json.dumps(f"PF01 Harbor benchmark {uuid4().hex[:10]}")
            space_id = receipt(ego(f'const task = await taskSpace({name}); console.log("PF01_JSON " + JSON.stringify(task.spaceId));', 20))
            evidence["space_id"] = space_id
            base_url = f"http://127.0.0.1:{server.server_port}"
            arms = [("control", "control.html", False, False)]
            for name in directories:
                export = f"{name}/index.html"
                arms.extend(((name, export, False, False), (f"{name}_probe", export, True, False)))
                if args.pause_control:
                    arms.append((f"{name}_paused", export, True, True))
            for name, route, probe, paused in arms:
                config = {"spaceId": space_id, "url": f"{base_url}/{route}", "durationMs": args.seconds * 1000,
                          "warmupMs": 5000, "probe": probe, "paused": paused, "control": name == "control",
                          "fighterButton": args.fighter_button if name != "control" else None}
                result = receipt(ego(f"const PF01 = {json.dumps(config)};\n{script}", args.seconds + 105))
                summarize(result)
                evidence["arms"][name] = result
                print(name, json.dumps(result["summary"]), flush=True)
        finally:
            try:
                if space_id is not None:
                    ego(f"const task = await taskSpace({space_id}); await task.finish({{keep: []}});", 20)
                    evidence["cleanup"] = True
            finally:
                server.shutdown()
                thread.join(timeout=2)
                args.output.write_text(json.dumps(evidence, ensure_ascii=False, indent=2) + "\n")


if __name__ == "__main__":
    main()
