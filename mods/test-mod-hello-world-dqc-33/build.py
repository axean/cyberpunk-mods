#!/usr/bin/env python3
"""Generate test-mod-hello-world-dqc-33. Run through tools/build-mod.sh.

    build.py <out dir>

Writes <out>/json/ (WolvenKit JSON, one file per resource) and <out>/mod/ (about.json and
the archive's .archive.xl/.archive.json).
"""

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools"))
import wkjson as wk  # noqa: E402

ARCHIVE = "hello_world_dqc_33"
SLOT = 33
FACT = f"deceptious_quest_{SLOT}"  # DQC slot fact: 0 free, -1 active, 1 reset requested

PHASE = rf"base\quest\deceptious_quests\deceptious_quest_{SLOT}.questphase"  # DQC starts this
DIR = rf"base\{ARCHIVE}"
JOURNAL = rf"{DIR}\{ARCHIVE}.journal"
SECTOR = rf"{DIR}\{ARCHIVE}_always.streamingsector"
BLOCK = rf"{DIR}\{ARCHIVE}.streamingblock"
ONSCREENS = rf"{DIR}\{ARCHIVE}_en-us.json"

# DQC checks "player is inside #deceptious_qc_<slot>" when V enters the apartment. This
# always-loaded trigger area covers the map, so the check passes whenever the mod is installed.
TRIGGER_REF = f"$/03_night_city/ne3/#DeceptiousQuestCore/#deceptious_qc_{SLOT}"
TRIGGER_NODE_ID = 1923095993371699770  # node id hashed from the path, as DQC slot mods use

CONVERSATION = f"contacts/unknown/{ARCHIVE}"  # vanilla contact: an unknown number
MESSAGE = f"{CONVERSATION}/hello"
TEXT = {f"{ARCHIVE}_title": "Hello world", f"{ARCHIVE}_hello": "Hello world!"}


def slot_phase() -> wk.Graph:
    """Claim the slot once and text V; on a reset from DQC's phone menu, free it again."""
    g = wk.Graph()
    start = g.add(wk.input_node(0))
    free = g.add(wk.condition_node(1, wk.fact_is(FACT, "Equal", 0)))
    claim = g.add(wk.set_fact_node(2, FACT, -1))
    chat = g.add(wk.journal_node(3, CONVERSATION, "gameJournalPhoneConversation"))
    text = g.add(wk.journal_node(4, MESSAGE, "gameJournalPhoneMessage"))
    reset = g.add(wk.pause_node(5, wk.fact_is(FACT, "Greater", 0)))
    untext = g.add(wk.journal_node(6, MESSAGE, "gameJournalPhoneMessage", notify=False))
    release = g.add(wk.set_fact_node(7, FACT, 0))
    end = g.add(wk.output_node(8))

    g.connect(start, free)
    g.connect(free, claim, out="True")
    g.connect(claim, chat, into="Active")
    g.connect(chat, text, into="Active")
    g.connect(claim, reset)
    g.connect(reset, untext, into="Inactive")
    g.connect(untext, release)
    g.connect(release, end)
    return g


def main() -> None:
    out = Path(sys.argv[1])
    src = out / "json"
    wk.write(src, PHASE, slot_phase().phase())
    message = wk.message("hello", f"{ARCHIVE}_hello")
    chat = wk.conversation(ARCHIVE, f"{ARCHIVE}_title", [message])
    wk.write(src, JOURNAL, wk.journal([wk.folder("contacts/unknown", [chat])]))
    wk.write(src, ONSCREENS, wk.onscreens(TEXT))
    sector = wk.trigger_sector(TRIGGER_REF, TRIGGER_NODE_ID, (4000, 4000, 1000), "{dqc_tr}")
    wk.write(src, SECTOR, sector)
    wk.write(src, BLOCK, wk.streaming_block([SECTOR]))

    # Loader config: .archive.json for the 2.5 loader, the same as YAML for ArchiveXL.
    config = {
        "journal": [JOURNAL],
        "localization": {"onscreens": {"en-us": ONSCREENS}},
        "streaming": {"blocks": [BLOCK]},
    }
    archive = out / "mod" / "archive"
    archive.mkdir(parents=True, exist_ok=True)
    (archive / f"{ARCHIVE}.archive.json").write_text(json.dumps(config, indent=4) + "\n")
    (archive / f"{ARCHIVE}.archive.xl").write_text(
        f"journal:\n  - {JOURNAL}\n"
        f"localization:\n  onscreens:\n    en-us: {ONSCREENS}\n"
        f"streaming:\n  blocks:\n    - {BLOCK}\n"
    )
    about = {"ModInfo": {"ModName": "test-mod-hello-world-dqc-33", "ModID": -1}}
    (out / "mod" / "about.json").write_text(json.dumps(about, indent=4) + "\n")


if __name__ == "__main__":
    main()
