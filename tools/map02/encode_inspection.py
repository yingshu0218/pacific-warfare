#!/usr/bin/env python3
"""Encode only the bounded MAP02 native screenshot sequence; run via tools/verify.py."""
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
EVIDENCE = ROOT / 'docs/showcase/evidence/MAP02'


def main():
    frames = sorted((EVIDENCE / 'sequence').glob('frame_*.png'))
    assert len(frames) == 80, f'Expected 80 native frames, got {len(frames)}'
    capture = json.loads((EVIDENCE / 'map_capture.json').read_text())
    assert not capture['failures']
    assert capture['source_hashes_before'] == capture['source_hashes_after']
    output = EVIDENCE / 'inspection.mp4'
    subprocess.run(['/opt/homebrew/bin/ffmpeg', '-hide_banner', '-loglevel', 'error', '-y',
                    '-framerate', '10', '-i', str(EVIDENCE / 'sequence/frame_%03d.png'),
                    '-frames:v', '80', '-c:v', 'libx264', '-crf', '20', '-pix_fmt', 'yuv420p',
                    '-movflags', '+faststart', str(output)], check=True, timeout=40)
    result = subprocess.run(['/opt/homebrew/bin/ffprobe', '-v', 'error', '-show_entries',
                             'stream=width,height,nb_frames,r_frame_rate:format=duration',
                             '-of', 'json', str(output)], check=True, timeout=5,
                            capture_output=True, text=True)
    metadata = json.loads(result.stdout)
    stream = metadata['streams'][0]
    assert (stream['width'], stream['height'], int(stream['nb_frames'])) == (1280, 720, 80)
    assert abs(float(metadata['format']['duration']) - 8.0) < .01
    metadata['scope'] = 'Native inspection camera at 10 fps output; not measured rendering FPS, aircraft flight, or OPS behavior'
    (EVIDENCE / 'video_probe.json').write_text(json.dumps(metadata, ensure_ascii=False, indent=2) + '\n')
    print(f'MAP02 native inspection: {output.name}, 1280x720, 80 frames, 8s')


if __name__ == '__main__':
    main()
