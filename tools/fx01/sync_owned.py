"""Sync only FX01-owned files into its frozen input project; never refresh DM01 inputs."""
from pathlib import Path
import shutil
ROOT=Path(__file__).resolve().parents[2]
STAGE=ROOT/'.local/fx01-project'
FILES=['scripts/presentation/effects/combat_effects.gd','scripts/presentation/effects/combat_effect_geometry.gd','scripts/presentation/effects/effect_surface.gdshader']
FILES += [str(p.relative_to(ROOT)) for p in (ROOT/'tests').rglob('*') if p.is_file() and ('fx01' in p.name)]
for name in FILES:
 target=STAGE/name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(ROOT/name,target)
print('FX01-only sync',len(FILES))
