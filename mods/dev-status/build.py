#!/usr/bin/env python3
"""Generate dev-status. Run through tools/build-mod.sh.

    build.py <out dir>

Writes <out>/json/ (WolvenKit JSON) and <out>/mod/ (about.json, the archive's loader files and
the redscript source under r6/scripts/).
"""

import shutil
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parents[1] / "tools"))
import devstatus  # noqa: E402

ARCHIVE = "dev_status"


def main() -> None:
    out = Path(sys.argv[1])
    text = f"dev-status loaded, {devstatus.stamp(HERE)}"
    devstatus.write_status_mod(out, ARCHIVE, "dev-status", text)
    scripts = out / "mod" / "r6" / "scripts" / ARCHIVE
    scripts.mkdir(parents=True)
    shutil.copy(HERE / "dev_status.reds", scripts)


if __name__ == "__main__":
    main()
