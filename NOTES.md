# Notes

Generic findings on how Cyberpunk modding works. Game: Steam + Proton Experimental on Linux, AppId 1091500, Update 2.5.

## Platform policy

Target PC for now, but keep mods as platform agnostic as possible:

- Prefer data (tweaks, archives, quest graphs, scenes) over scripts. Data mods are the likeliest to work on consoles.
- Use redscript only where data can't do the job, and make the mod degrade gracefully if the script never runs.
- No CET or RED4ext (native code, PC only).

We have no console to test on. Console support for redscript is unconfirmed: mod.io gets a per-platform copy of each upload, but whether consoles run the scripts is unknown.

## Mod ecosystems

- **mod.io** (Update 2.5, 2026-10-22): official, cross-platform (PC, Mac, PS5, Xbox, Switch 2), browsed and installed in-game. ~39 mods at launch.
- **REDmod** (patch 1.6, 2022): official, PC only, no in-game browser.
- **Nexus**: PC only. Community frameworks: Cyber Engine Tweaks (Lua), RED4ext (C++), redscript, ArchiveXL, TweakXL.

## Where mod.io installs go

The game dir (`steamapps/common/Cyberpunk 2077`) is not touched. Everything goes in the Proton prefix, `steamapps/compatdata/1091500/pfx/drive_c/`:

| Path | Purpose |
|---|---|
| `users/Public/mod.io/5784/mods/<modID>/` | Installed mod (5784 = game id on mod.io) |
| `users/Public/mod.io/5784/metadata/state.json` | mod.io install state, full mod profiles |
| `users/Public/mod.io/5784/cache/mods/<modID>/` | Thumbnails from browsing, not installs |
| `users/steamuser/AppData/Local/mod.io/5784/steamuser/user.json` | mod.io account |
| `users/steamuser/Saved Games/CD Projekt Red/Cyberpunk 2077/EnabledMods.json` | Enabled mods list, plus `mods_config` (Boolean/Float/Int/Keybind/Combo, probably mod settings) |

Uninstalling in-game deletes `mods/<modID>/` and drops the mod from `state.json`, `user.json` and `EnabledMods.json`. Thumbnails in `cache/` stay. `EnabledMods.json` is written in two steps, so wait a moment before checking.

Layout of a mod folder:

```
about.json                  {"ModInfo": {"ModName": ..., "ModID": ...}}
archive/<name>.archive      assets
archive/<name>.archive.json
archive/<name>.archive.xl   ArchiveXL-style YAML
r6/scripts/*.script         redscript source
r6/tweaks/*.yaml|*.json     TweakXL-style records
r6/cache/*.redscripts(.h64) compiled scripts: final, final_noopts, master, profiling
```

## Saves

`drive_c/users/steamuser/Saved Games/CD Projekt Red/Cyberpunk 2077/<AutoSave-N|ManualSave-N>/`: `sav.dat` (compressed game state), `metadata.9.json`, `screenshot.png`.

`metadata.9.json` → `Data.metadata` is readable JSON. Mod-related fields: `isModded`, `enabledModioInfo` (modID, modName, authorName per enabled mod.io mod). Also level, attributes, lifePath, `activeQuests`, `finishedQuests`, `trackedQuestEntry` (e.g. `ep1/quests/main_quest/q301_crash/00_hook/get_to_combat_zone`) and a short `facts` list. That list is a fixed set of story facts; facts set by mods only show up in `sav.dat`.

Skip-to-Phantom-Liberty start: level 15, `q301_active=1`, `ep1_active=1`, Act 1 outcomes pre-set (`q110_voodoo_queen_dead=1`, `q110_08a_netwatch_deal=1`, ...).

Installing or enabling mods writes nothing besides the files above; playing only adds saves, `user.gls` and the vkd3d shader cache in the game dir.

### sav.dat format

Decoded by `tools/savdat.py`, checked against the facts listed in `metadata.9.json`.

- `VASC` magic, save version (277 on 2.5), game version (2500).
- `FZLC` table: u32 count, then (offset, compressed size, decompressed size) per chunk. Chunks are `4ZLX` + u32 size + an LZ4 block, 256 KiB each decompressed. A 1.8 MB save is 7.2 MB decompressed.
- Node table at the end: file ends with u32 offset + `ENOD`; at that offset `EDON`, a count, then per node a name, next index, child index, offset, size. Offsets point into header + decompressed chunks.
- ~286 nodes: `PersistencySystem2` (4.7 MB), `CommunitySystem` (1.8 MB), `inventory`, `JournalManager`, `ScriptableSystemsContainer`, `questSystem` > `FactsDB` > 10 `FactsTable`, `PhoneManager`, `ModdingSystem`, ...
- `FactsTable`: u32 node index, count, count × u32 FNV-1a 32 name hashes, count × u32 values. ~4,400 facts in an early Phantom Liberty save. Names are not stored; to read a fact you need its name.
- Node indices shift between saves; compare FactsTables by position.
- Names differing only in the last character hash to values that differ by multiples of the FNV prime (`0x01000193`), so numbered fact families (`x_1`, `x_2`, ...) show up as runs.

## Observations

- Mods can replace vanilla files, including `.questphase` quest graphs, by shipping the same resource path in their archive. Two mods replacing the same file conflict.
- Fact values are signed 32-bit (`-1` is stored as `0xffffffff`).
- Archive name prefixes like `#` and `z` are probably load order (alphabetical, last wins), as in the Nexus convention. Not verified for the mod.io loader.
- 2.5 has its own loader for ArchiveXL-style content. On a vanilla install (no RED4ext, no ArchiveXL), mod.io mods' streaming blocks, journal entries and localization load, and redscript runs. Every mod.io mod we installed ships `X.archive.xl` plus `X.archive.json` with the same content. The game exe contains `*.archive`, `.json`, `*.redscripts` and `about.json`, but not `.xl` or `ArchiveXL`. Likely: the native loader reads `.archive.json` and precompiled `r6/cache/*.redscripts`, and `.xl` is kept for Nexus ArchiveXL. Not confirmed.
- The Nexus frameworks (RED4ext and its plugins ArchiveXL, TweakXL, Codeware) broke with 2.5; only unofficial fixes existed at launch. Native code is outside the mod.io path anyway.
- Redscript runs on 2.5 via mod.io (PC, Proton). A mod's `.script` wraps an elevator method and sets facts; after an elevator ride those facts appeared in the save, and no quest or scene file writes them.
- Data-only mods can do a lot through quest scenes: `questInputAction_ConditionType` reads stick and button input (e.g. "player is idle"), `questInventory_ConditionType` + `questAddRemoveItem` check and consume items, and scenes can play vanilla player animations with vanilla props attached.
- 2.5 also loads mods from the game's legacy `archive/pc/mod/` folder, including their `.archive.json`/`.archive.xl` (journal, onscreens, streaming blocks): a test mod placed there worked without mod.io. Not yet known which of the two config files it reads.
- The game reads mod archives only at startup. Swapping a mod's files while the game runs is safe (replace by rename), but loading a save or going back to the main menu keeps the old version; a full restart picks up the new one (tested 2026-10-25).
- Tweaks (`r6/tweaks/*.yaml|json`) only load for mods the game lists in `EnabledMods.json` (`enabled_mods[].modPath`), which it builds from mod.io subscriptions. Not read: the game's own `r6/tweaks/`, or `<game>/mods/<name>/r6/tweaks/`. A hand-added `EnabledMods.json` entry is accepted once, then disabled ("doesn't work for this platform") and breaks the in-game Mods panel until removed. Sideloads stay out of mod.io's files.
- Scripts can read TweakDB (`TDB`, `TweakDBInterface`) but not write it; writes needed TweakXL.
- redscript 0.5.32 (community compiler, first with 2.5 support) works as a sideload: `tools/install-redscript.sh` puts its `scc.exe` in `engine/tools/`; at launch it compiles `r6/scripts/**/*.reds` into `r6/cache/final.redscripts` (original kept as `.bk`, log in `r6/logs/`). A test hooked `PlayerPuppet.OnGameAttached` (runs on every save load) and set a fact. mod.io script mods instead ship small per-mod blobs (`r6/cache/*.redscripts` + `.h64`); whether they still bind after redscript rewrites the game blob is untested.
- Faster restarts: Steam launch options `%command% --launcher-skip -skipStartScreen` (`skipStartScreen` is in the 2.5 exe; `--launcher-skip` is for `REDprelauncher.exe`). No command-line flag to load a save directly was found.
- WolvenKit CLI 10.0.0-beta.1 converts game files to JSON and back byte-identically (tested on a `.questphase` and a `.streamingsector`), so mods can be written as JSON (or generated) and converted at build time. `convert deserialize` writes its output flat, without the input's folders.
- Quest graphs in WolvenKit JSON: sockets and connections are shared objects (`HandleId` on first use, `HandleRefId` after), so each connection appears in both its source and destination socket. Journal nodes have `Active`/`Inactive` inputs; journal paths use `fileEntryIndex: 1` everywhere, vanilla and mods.
- A mod's journal can add a conversation under a vanilla contact by using a folder with the contact's path as id (e.g. `contacts/unknown`); entries merge by id.
- mod.io API: write calls on `api.mod.io` fail with 401 "deprecated api.mod.io domain"; use the per-game domain `https://g-5784.modapi.io/v1`. Write calls need a personal access token (OAuth clients are deprecated); the read-only API key cannot write.
- On mod.io, Cyberpunk's platforms (Windows, Mac, Xbox Series X/S, PS5, Switch 2) are all moderated and locked: the API only lets game admins target locked platforms, so an API upload gets no platforms and can never go live. Upload on the website instead: it files the chosen platform as a pending request (status 0) for CDPR's approval. For testing, use the local `archive/pc/mod/` route.
- Console versions come from mod.io's Cloud Cooking: the uploaded PC build is cooked for Xbox, PlayStation and Switch after upload (at most 50 files cooking at a time per author). The file is then set live per platform from the website ("Set file live"), pending CDPR approval. Which platforms a data-only mod ends up with is not yet known.
- mod.io tags some mods "Available on Consoles". Mods that ship scripts seem not to carry it; not confirmed.

## Existing frameworks

Check these before building our own.

- **Deceptious Quest Core (DQC)**, by Deceptious, on mod.io and Nexus. The problem: a new quest phase only loads if an already running quest graph points to it, so quest mods have to replace a vanilla quest file to hook in, and two mods replacing the same file conflict. DQC takes one vanilla hook and lets many quest mods hang off it, so they no longer replace vanilla files or collide. Mods activate when V leaves and re-enters the H10 apartment (or right away, if DQC already checked that slot earlier in the save while it was empty), and the phone lists active mods and can reset them. It adds no content of its own. It is the author's framework for their own mods; using it for ours would need their permission (see the Nexus "Permissions and credits" section).

## Open questions

- What file types does mod.io accept for Cyberpunk? Any native code, CET, RED4ext?
- Does 2.5 compile `.script` files itself, or only load the shipped `r6/cache/*.redscripts`? The exe globs `*.redscripts`, which points to the latter.
- Which ArchiveXL features does the native loader support? Seen working: streaming, journal, localization. Its config keys (from the exe) also cover sector `nodeMutations`/`nodeDeletions`/instance and actor mutations, `lipmaps`/`vomaps`, resource `copy`/`hide`/`tags`/`overrides`, `factories` and `customizations`. No key for adding quests or quest phases was found.
- Can a mod add a root quest to an existing save (like the native `QuestsSystem::AddQuest` that DLC root quests rely on) without native code? Vanilla scripts expose `StartGameDefinition` (start a new game from a `.gamedef`) on the main-menu request handler, but nothing that adds a quest to a running game was found.
- WolvenKit GUI under Wine/Proton: usable for quest and scene editing?
- Quest structure: `.gamedef` lists root `.quest` files (base game, plus `ep1\quest\ep1.quest` for Phantom Liberty), which run `.questphase` graphs, which play `.scene`s. Is there a way to hook a new quest phase in without replacing a vanilla file (ArchiveXL, 2.5 itself)?
