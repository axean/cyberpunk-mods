# Notes

Generic findings on how Cyberpunk modding works. Game: Steam + Proton Experimental on Linux, AppId 1091500, Update 2.5.

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
- ArchiveXL, TweakXL and redscript formats appear in mod.io mods. Not yet known if 2.5 supports them natively or bundles them.

## Open questions

- What file types does mod.io accept for Cyberpunk? Any native code, CET, RED4ext?
- Does 2.5 compile `.script` files itself, or do mods ship `r6/cache/*.redscripts` precompiled?
- WolvenKit GUI under Wine/Proton: usable for quest and scene editing?
- Quest structure: `.questphase`, `.scene`, journal, facts. How do they hook into the main quest graph?
