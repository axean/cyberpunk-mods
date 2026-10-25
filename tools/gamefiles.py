"""Read resources from the player's own game install at build time. Never commit the results."""

import json
import os
import subprocess
import tempfile
from pathlib import Path
from typing import Any

TOOLS = Path(__file__).resolve().parent
STEAM = Path(os.environ.get("STEAM", "~/.local/share/Steam/steamapps")).expanduser()
CONTENT = STEAM / "common" / "Cyberpunk 2077" / "archive" / "pc" / "content"


def wk(*args: str | Path) -> None:
    subprocess.run([TOOLS / "wk", *args, "-v", "Quiet"], check=True, capture_output=True)


def resource_json(depot_path: str) -> dict[str, Any]:
    """A vanilla resource as WolvenKit JSON, extracted from the game's archives."""
    with tempfile.TemporaryDirectory() as tmp:
        regex = "^" + depot_path.replace("\\", "\\\\").replace(".", "\\.") + "$"
        for archive in sorted(CONTENT.glob("basegame_*.archive")):
            wk("unbundle", archive, "-o", tmp, "-r", regex)
        found = Path(tmp) / depot_path.replace("\\", "/")
        if not found.exists():
            raise FileNotFoundError(f"{depot_path} not found in {CONTENT}")
        wk("convert", "serialize", found, "-o", tmp)
        return json.loads((Path(tmp) / (found.name + ".json")).read_text())
