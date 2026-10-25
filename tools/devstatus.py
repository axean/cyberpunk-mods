"""Register a dev mod with dev-status, which texts V on every save load.

Every dev mod adds one message to the shared conversation contacts/unknown/devstatus (journals
merge by id); the dev-status script re-sends all of that conversation's messages. Sideloads only.
"""

import subprocess
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
