#!/usr/bin/env python3
"""Generate parkour (a CET Lua mod). Run through tools/build-mod.sh.

    build.py <out dir>

Writes the dev-status registration (archive) and copies init.lua into CET's mods folder layout.
"""

import shutil
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parents[1] / "tools"))
import devstatus  # noqa: E402

CET_MOD = Path("bin/x64/plugins/cyber_engine_tweaks/mods/parkour")


def main() -> None:
    out = Path(sys.argv[1])
    text = f"parkour loaded (CET, spikes), {devstatus.stamp(HERE)}"
    devstatus.write_status_mod(out, "parkour", "parkour", text)
    (out / "mod" / CET_MOD).mkdir(parents=True)
    shutil.copy(HERE / "init.lua", out / "mod" / CET_MOD)


if __name__ == "__main__":
    main()
