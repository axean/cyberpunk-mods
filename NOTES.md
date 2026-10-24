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

## Observations

- Archive name prefixes like `#` and `z` are probably load order (alphabetical, last wins), as in the Nexus convention. Not verified for the mod.io loader.
- ArchiveXL, TweakXL and redscript formats appear in mod.io mods. Not yet known if 2.5 supports them natively or bundles them.

## Open questions

- What file types does mod.io accept for Cyberpunk? Any native code, CET, RED4ext?
- Does 2.5 compile `.script` files itself, or do mods ship `r6/cache/*.redscripts` precompiled?
- WolvenKit on Linux: CLI for unpacking, GUI under Wine?
- Quest structure: `.questphase`, `.scene`, journal, facts. How do they hook into the main quest graph?
