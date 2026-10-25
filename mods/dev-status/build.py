#!/usr/bin/env python3
"""Generate dev-status. Run through tools/build-mod.sh.

    build.py <out dir>

Writes <out>/json/ (WolvenKit JSON) and <out>/mod/ (about.json, the archive's loader files and
the redscript source under r6/scripts/).
"""

import json
import shutil
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parents[1] / "tools"))
import devstatus  # noqa: E402
import wkjson as wk  # noqa: E402

ARCHIVE = "dev_status"
DIR = rf"base\{ARCHIVE}"
JOURNAL = rf"{DIR}\{ARCHIVE}.journal"
ONSCREENS = rf"{DIR}\{ARCHIVE}_en-us.json"


def main() -> None:
    out = Path(sys.argv[1])
    chat, texts = devstatus.register("dev-status", f"dev-status loaded, {devstatus.stamp(HERE)}")
    wk.write(out / "json", JOURNAL, wk.journal([wk.folder("contacts/unknown", [chat])]))
    wk.write(out / "json", ONSCREENS, wk.onscreens(texts))

    config = {"journal": [JOURNAL], "localization": {"onscreens": {"en-us": ONSCREENS}}}
    archive = out / "mod" / "archive"
    archive.mkdir(parents=True, exist_ok=True)
    (archive / f"{ARCHIVE}.archive.json").write_text(json.dumps(config, indent=4) + "\n")
    (archive / f"{ARCHIVE}.archive.xl").write_text(
        f"journal:\n  - {JOURNAL}\nlocalization:\n  onscreens:\n    en-us: {ONSCREENS}\n"
    )
    scripts = out / "mod" / "r6" / "scripts" / ARCHIVE
    scripts.mkdir(parents=True)
    shutil.copy(HERE / "dev_status.reds", scripts)
    about = {"ModInfo": {"ModName": "dev-status", "ModID": -1}}
    (out / "mod" / "about.json").write_text(json.dumps(about, indent=4) + "\n")


if __name__ == "__main__":
    main()
