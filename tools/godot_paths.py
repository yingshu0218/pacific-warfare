"""Platform paths shared by the pinned Godot Web export tools."""
from __future__ import annotations

import os
from pathlib import Path
import sys


def web_template_dir(version: str) -> Path:
    if sys.platform == "darwin":
        root = Path.home() / "Library" / "Application Support" / "Godot"
    elif sys.platform.startswith("linux"):
        xdg_data = Path(os.environ.get("XDG_DATA_HOME") or Path.home() / ".local" / "share")
        if not xdg_data.is_absolute():
            raise ValueError("XDG_DATA_HOME must be an absolute path")
        root = xdg_data / "godot"
    else:
        raise RuntimeError(f"Web template tools do not support {sys.platform}")
    return root / "export_templates" / version
