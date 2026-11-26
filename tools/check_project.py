"""Fail on Godot diagnostics as well as nonzero exits; bound every check."""
import subprocess
from pathlib import Path

root = Path(__file__).resolve().parents[1]
godot = '/Applications/Godot.app/Contents/MacOS/Godot'
checks = [
    ['--headless', '--path', str(root), '--editor', '--import', '--quit'],
    ['--headless', '--path', str(root), '--script', 'tests/test_weapon_motion.gd'],
    ['--headless', '--path', str(root), '--script', 'tests/test_hull_geometry.gd'],
    ['--headless', '--path', str(root), '--script', 'tests/test_mesh_batching.gd'],
    ['--headless', '--path', str(root), '--script', 'tests/audit_guarded_motion.gd'],
    ['--headless', '--path', str(root), '--script', 'tests/audit_aa_shield_clearance.gd'],
]
for args in checks:
    result = subprocess.run([godot, *args], capture_output=True, text=True, timeout=60)
    output = result.stdout + result.stderr
    if result.returncode or 'SCRIPT ERROR:' in output or '\nERROR:' in output:
        print(output)
        raise SystemExit(1)
print('PASS: import, hull geometry, mixed mesh batching and weapon mechanism checks; no Godot error diagnostics')
