#!/usr/bin/env python3
"""Register a dev mod with dev-status, which texts V on every save load.

Every dev mod adds one message to the shared conversation contacts/unknown/devstatus (journals
merge by id); the dev-status script re-sends all of that conversation's messages. Sideloads only.
"""

import json
import subprocess
import sys
from datetime import datetime
from pathlib import Path

import wkjson as wk

CONVERSATION = "devstatus"


def stamp(mod_dir: Path) -> str:
    """Build time and git commit, e.g. "built 25 Oct 14:02, 3f2a1c9+" (+ = uncommitted changes)."""
    git = ["git", "-C", str(mod_dir)]
    commit = subprocess.run(
        [*git, "rev-parse", "--short", "HEAD"], capture_output=True, text=True
    ).stdout.strip()
    dirty = subprocess.run([*git, "status", "--porcelain", "."], capture_output=True, text=True)
    return f"built {datetime.now():%d %b %H:%M}, {commit or 'no git'}{'+' if dirty.stdout else ''}"


def register(mod: str, text: str) -> tuple[wk.Handle, dict[str, str]]:
    """Conversation to put under the journal folder "contacts/unknown", and its onscreen texts."""
    key = f"{CONVERSATION}_{mod.replace('-', '_')}"
    message = wk.message(key, key, delay=0)
    chat = wk.conversation(CONVERSATION, f"{CONVERSATION}_title", [message])
    return chat, {f"{CONVERSATION}_title": "dev mods", key: text}


def write_status_mod(out: Path, archive: str, mod: str, text: str) -> None:
    """A mod that only registers `mod` with dev-status: journal, text, loader config, about.json.
    Used for mods with nothing else to add (dev-status itself, third-party installs)."""
    journal, onscreens = (
        rf"base\{archive}\{archive}.journal",
        rf"base\{archive}\{archive}_en-us.json",
    )
    chat, texts = register(mod, text)
    wk.write(out / "json", journal, wk.journal([wk.folder("contacts/unknown", [chat])]))
    wk.write(out / "json", onscreens, wk.onscreens(texts))
    config = {"journal": [journal], "localization": {"onscreens": {"en-us": onscreens}}}
    folder = out / "mod" / "archive"
    folder.mkdir(parents=True, exist_ok=True)
    (folder / f"{archive}.archive.json").write_text(json.dumps(config, indent=4) + "\n")
    (folder / f"{archive}.archive.xl").write_text(
        f"journal:\n  - {journal}\nlocalization:\n  onscreens:\n    en-us: {onscreens}\n"
    )
    about = {"ModInfo": {"ModName": mod, "ModID": -1}}
    (out / "mod" / "about.json").write_text(json.dumps(about, indent=4) + "\n")


def main() -> None:
    """devstatus.py status-mod <out dir> <mod name> <text>: build input for a status-only mod."""
    if len(sys.argv) != 5 or sys.argv[1] != "status-mod":
        sys.exit(main.__doc__)
    out, mod, text = Path(sys.argv[2]), sys.argv[3], sys.argv[4]
    write_status_mod(out, "devstatus_" + mod.replace("-", "_"), mod, text)


if __name__ == "__main__":
    main()
