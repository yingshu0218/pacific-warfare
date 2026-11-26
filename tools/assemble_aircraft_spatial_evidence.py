#!/usr/bin/env python3
"""Assemble existing native frames and actual fixed-tick traces, under verify.py."""
import hashlib
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / 'docs/showcase/evidence/S04-spatial'


def run(command):
    result = subprocess.run(command, cwd=ROOT, timeout=45,
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if result.returncode:
        sys.stderr.write(result.stderr.decode(errors='replace'))
        result.check_returncode()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--v3', action='store_true')
    parser.add_argument('--capture')
    parser.add_argument('--skip-plots', action='store_true')
    parser.add_argument('--plots-only', action='store_true')
    args = parser.parse_args()
    captures = {}
    jobs = [
        ('four', '.local/S04-spatial-four-frames', [0, 120, 300], 360, 1100, 700),
        ('current', '.local/S04-spatial-current-frames', [60, 180, 270], 390, 1100, 700),
    ] if not args.v3 else [
        ('f6f-v3-split-final', '.local/S04-f6f-v3-split-final-frames', [0, 60, 105, 150, 210, 255], 270, 1100, 700),
        ('f6f-v3-reversal', '.local/S04-f6f-v3-reversal-frames', [0, 45, 90, 135, 180, 225], 240, 1100, 700),
        ('f6f-v3-current', '.local/S04-f6f-v3-current-frames', [60, 180, 270], 390, 1100, 700),
        ('f6f-v3-observer', '.local/S04-f6f-observer-frames', [0, 90, 180, 270, 360, 435], 450, 1280, 720),
    ]
    if args.capture:
        jobs = [job for job in jobs if job[0] == args.capture]
        assert jobs, args.capture
    if args.plots_only: jobs = []
    for name, frames, keys, expected, width, height in jobs:
        directory = ROOT / frames
        metadata = json.loads((directory / 'capture.json').read_text())
        files = sorted(directory.glob('frame_*.png'))
        assert len(files) == expected, (name, len(files), expected)
        assert all(p.name == f'frame_{i:04d}.png' for i, p in enumerate(files))
        video = OUTPUT / f'{name}-native.mp4'
        run(['/opt/homebrew/bin/ffmpeg', '-y', '-framerate', str(metadata['fps']),
             '-i', str(directory / 'frame_%04d.png'), '-an', '-vf', f'pad={width}:{height}:0:0:black', '-c:v', 'libx264',
             '-threads', '2', '-preset', 'fast', '-crf', '22', '-pix_fmt', 'yuv420p',
             '-movflags', '+faststart', str(video)])
        probe = subprocess.run(['/opt/homebrew/bin/ffprobe', '-v', 'error',
             '-select_streams', 'v:0', '-show_entries',
             'stream=width,height,nb_frames,r_frame_rate,duration',
             '-of', 'json', str(video)], check=True, capture_output=True, text=True, timeout=10)
        stream = json.loads(probe.stdout)['streams'][0]
        assert int(stream['nb_frames']) == expected
        assert (int(stream['width']), int(stream['height'])) == (width, height)
        shutil.copyfile(directory / 'capture.json', OUTPUT / f'{name}-native-samples.json')
        selected = []
        for key in keys:
            target = OUTPUT / f'{name}-native-{key:04d}.png'
            shutil.copyfile(files[key], target)
            selected.append(target.name)
        captures[name] = {
            'case': metadata['case'], 'follow': metadata['follow'],
            'first_simulation_time_s': metadata['samples'][0]['time_s'],
            'fixed_ticks_per_frame': 4, 'fps': metadata['fps'],
            'camera_offset_m': metadata.get('camera_offset_m'),
            'camera': metadata.get('camera_view', 'Constant world offset, world up; translation only, no orbit/roll'),
            'render': 'Godot 4.7.2 Compatibility, minimized, explicit force_draw, automatic exit',
            'encoding': 'Original pixels preserved, no resize/interpolation; only black bottom padding if the native macOS window is13px shorter',
            'frames': expected, 'stream': stream, 'video': video.name,
            'selected_frames': selected,
            'raw_frame_sha256': {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in files},
        }
        print(f'{name}: {expected} continuous native frames, {video.name}')
    manifest = OUTPUT / ('native-captures-v3.json' if args.v3 else 'native-captures.json')
    if captures:
        previous = json.loads(manifest.read_text()) if manifest.exists() and args.capture else {}
        previous.update(captures)
        manifest.write_text(json.dumps(previous, indent=2) + '\n')
    if args.skip_plots: return
    for source, target, seconds in [
        ('standard-before.json', 'standard-before.png', 120),
        ('standard-after-120s.json', 'standard-after-120s.png', 120),
        ('standard-after.json', 'standard-after.png', 240),
        ('four-after.json', 'four-after.png', 240),
        ('current-after.json', 'current-after.png', 240),
    ]:
        run([sys.executable, str(ROOT / 'tools/plot_aircraft_spatial.py'),
             str(OUTPUT / source), '--output', str(OUTPUT / target),
             '--time-limit', str(seconds)])
        print(f'plot: {target}, equal physical kilometre axes')


if __name__ == '__main__':
    main()
