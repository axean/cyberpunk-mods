# Plan

Goal: entering the H10 apartment sends a phone message "Hello world!". Smallest mod that exercises authoring, building, loading, DQC detection and the journal.

## 1. Sources (done)

`build.py` describes every resource in Python (via `tools/wkjson.py`) and writes WolvenKit JSON:

| Resource | What |
|---|---|
| `base\quest\deceptious_quests\deceptious_quest_33.questphase` | slot phase |
| `base\hello_world_dqc_33\hello_world_dqc_33.journal` | conversation + message under the vanilla `contacts/unknown` |
| `base\hello_world_dqc_33\hello_world_dqc_33_en-us.json` | onscreen text |
| `base\hello_world_dqc_33\hello_world_dqc_33_always.streamingsector` | trigger `#deceptious_qc_33` |
| `base\hello_world_dqc_33\hello_world_dqc_33.streamingblock` | lists the sector |

Plus `archive/hello_world_dqc_33.archive.json` and `.archive.xl` (journal, onscreens, streaming block) and `about.json`.

Slot phase graph:

1. In
2. `deceptious_quest_33 == 0` ? True: set it to `-1`, activate the conversation, then the message (with notification)
3. In parallel: wait until `deceptious_quest_33 > 0` (reset from DQC's phone menu), deactivate the message, set the slot to `0`, Out

The message is sent once per registration. Resetting slot 33 from DQC's phone menu and re-entering the apartment sends it again.

## 2. Build (done)

`tools/build-mod.sh mods/test-mod-hello-world-dqc-33` gives `build/test-mod-hello-world-dqc-33/test-mod-hello-world-dqc-33.zip` (mod.io folder layout). It converts each JSON file to a game file and back, and fails if the result differs. No vanilla files needed, so it also runs in CI.

## 3. Load and test (works)

Result 2026-10-25, local route: the text arrived as soon as the save loaded (behind Viktor's), since DQC was already waiting for slot 33's trigger in that save.


1. Local route first: copy `build/.../mod/archive/*` into the game's `archive/pc/mod/` (done 2026-10-25; delete the three files to uninstall). Unknown whether the 2.5 loader reads `.archive.json` there.
2. In game: enter the apartment (leave and re-enter if already inside), expect a text from an unknown number: "Hello world!".
3. Check with `tools/savdat.py facts <save>/sav.dat deceptious_quest_33`: `-1` means DQC found the trigger and the phase ran; `0` means the trigger (streaming block) did not load.
4. If the local route does not load: hidden mod.io upload (step 4).

## 4. GitHub workflow and mod.io (hidden)

Set up 2026-10-25:

- mod.io: mod "test-mod-hello-world-dqc-33 [DQC]", visibility Hidden. Uploads use a mod.io personal access token (read + write); the read-only API key cannot upload.
- GitHub environment `modio`: secret `MODIO_TOKEN`, variable `MODIO_MOD_ID`. Only tags `test-mod-hello-world-v*` may use it, and each run waits for the owner's approval.
- `.github/workflows/modio-test-mod.yml`, on tags `test-mod-hello-world-v<version>`: install WolvenKit, build, upload the zip as a new active file (`platforms[]=windows`), version from the tag.

To release: `git tag test-mod-hello-world-v0.1.1 && git push origin test-mod-hello-world-v0.1.1`, then approve the run on GitHub. Then subscribe to the hidden mod (logged in on the website) and remove the local copy from `archive/pc/mod/`.

Uploads may land as pending if mod.io or CDPR moderates files.

## 5. Before going public

- Ask DQC's author for a reserved slot (Nexus message, Ko-fi or Patreon). Move to that slot number.
- Credit DQC, list it as a dependency, tag the mod "[DQC]".
- Disclaimer in the mod.io description.
