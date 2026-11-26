#!/usr/bin/env python3
"""Encode the two passed, explicitly named native frame sequences under verify."""
from pathlib import Path
import hashlib
import json
import subprocess

ROOT = Path(__file__).resolve().parents[2]
CAND = ROOT / 'candidates/s14-bombing'
records = []
for name in ['b25-release-r12', 'd4y-release-r12', 'g4m-release-r12', 'b25-intercept-r12', 'sb2c-sea-r12']:
    folder = CAND / 'native' / name
    capture = json.loads((folder / 'capture.json').read_text())
    frames = [folder / f'frame_{i:04d}.png' for i in range(capture['frames'])]
    assert all(p.is_file() for p in frames)
    output = folder / 'continuous.mp4'
    assert not output.exists(), 'Do not overwrite an evidence movie'
    subprocess.run([
        '/opt/homebrew/bin/ffmpeg', '-hide_banner', '-loglevel', 'warning',
        '-framerate', str(capture['fps']), '-i', str(folder / 'frame_%04d.png'),
        '-frames:v', str(capture['frames']), '-an', '-c:v', 'libx264', '-crf', '20',
        '-pix_fmt', 'yuv420p', '-movflags', '+faststart', str(output),
    ], check=True, timeout=35)
    probe = json.loads(subprocess.check_output([
        '/opt/homebrew/bin/ffprobe', '-v', 'error', '-show_entries',
        'stream=width,height,avg_frame_rate,nb_frames:format=duration',
        '-of', 'json', str(output),
    ], text=True, timeout=10))
    stream = probe['streams'][0]
    assert int(stream['nb_frames']) == capture['frames']
    assert [stream['width'], stream['height']] == [1280,720]
    records.append({
        'sequence': name, 'fps': capture['fps'], 'frames': capture['frames'],
        'source_capture': str((folder / 'capture.json').relative_to(ROOT)),
        'source_capture_sha256': hashlib.sha256((folder / 'capture.json').read_bytes()).hexdigest(),
        'frozen_inputs': capture['source_manifest']['frozen_inputs'],
        'input_png_sha256': {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in frames},
        'movie': str(output.relative_to(ROOT)),
        'movie_sha256': hashlib.sha256(output.read_bytes()).hexdigest(),
        'probe': probe, 'audio': False, 'sampling_is_not_performance': True,
    })
(CAND / 'evidence/native-movies.json').write_text(json.dumps(records, indent=2) + '\n')
print(json.dumps([{'sequence': r['sequence'], 'frames': r['frames'], 'movie_sha256': r['movie_sha256']} for r in records]))
