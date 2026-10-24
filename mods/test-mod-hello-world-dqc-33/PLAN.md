# Plan

Goal: entering the H10 apartment sends a phone message "Hello world!". Smallest mod that exercises authoring, building, loading, DQC detection and the journal.

## 1. Sources (all our own files)

Authored as WolvenKit JSON, converted to game files at build time:

```
src/
  base/quest/deceptious_quests/deceptious_quest_33.questphase.json   slot phase
  mod/hello_world_dqc_33/hello_world.journal.json                    contact + message
  mod/hello_world_dqc_33/hello_world_always.streamingsector.json      trigger #deceptious_qc_33
  mod/hello_world_dqc_33/hello_world.streamingblock.json             lists the sector
  mod/hello_world_dqc_33/en-us.json                                  message text
archive/
  hello_world_dqc_33.archive.xl     streaming block, journal, localization (YAML)
  hello_world_dqc_33.archive.json   same content as JSON (read by the 2.5 loader)
about.json
```

Slot phase graph:

1. In
2. `deceptious_quest_33 == 0` ? True: set it to `-1`, then send the journal message with a notification ("Hello world!")
3. In parallel: wait until `deceptious_quest_33 > 0` (reset from DQC's phone menu), set it to `0`, Out

The message is sent once per registration. Resetting slot 33 from DQC's phone menu and re-entering the apartment sends it again.

## 2. Build

- `tools/build-mod.sh mods/test-mod-hello-world-dqc-33` (to write):
  - `tools/wk convert deserialize` the JSON sources into CR2W files
  - `tools/wk pack` them into `archive/hello_world_dqc_33.archive`
  - copy `.archive.xl`, `.archive.json` and `about.json`, zip in the mod.io folder layout
- Untested so far: JSON to CR2W with WolvenKit CLI 10.0.0-beta.1.
- No vanilla files needed, so the build also runs in CI.

## 3. Load and test

1. Local route first: put the archive files in the game's legacy `archive/pc/mod/`. Unknown whether the 2.5 loader reads `.archive.xl`/`.json` there.
2. Fallback: hidden mod.io upload (step 4).
3. In game: enter the apartment, expect the "Hello world!" text.
4. Check with `tools/savdat.py facts <save>/sav.dat deceptious_quest_33` (expect `-1`).
5. Check DQC detection: does DQC find `#deceptious_qc_33` by the short name, or must the node path match the one DQC's own mods use?

## 4. GitHub workflow and mod.io (hidden)

1. Create the mod by hand on mod.io: name, logo, description with the disclaimer, visibility **Hidden**. Note the mod id.
2. Create a mod.io **OAuth access token with write scope** (account settings, API access). The read-only API key cannot upload.
3. Store it as GitHub Actions secret `MODIO_TOKEN` in a protected environment `modio`; mod id as variable `MODIO_MOD_ID`.
4. Workflow `.github/workflows/modio-test-mod.yml`, on tags `test-mod-hello-world-v*`:
   - install WolvenKit via `tools/install-wolvenkit.sh`
   - build with `tools/build-mod.sh`
   - upload: `POST https://api.mod.io/v1/games/5784/mods/$MODIO_MOD_ID/files` with `filedata`, `version`, `changelog`, `active=true` and `platforms[]` (`windows` first)
5. Subscribe to the hidden mod in game (or on the website) and test as in step 3.

Never print the token. Uploads may land as pending if mod.io or CDPR moderates files.

## 5. Before going public

- Ask DQC's author for a reserved slot (Nexus message, Ko-fi or Patreon). Move to that slot number.
- Credit DQC, list it as a dependency, tag the mod "[DQC]".
- Disclaimer in the mod.io description.
