# References

External resources we found useful, with what each is good for. Links only; nothing from these is copied into this repo. Add new finds here.

## Cyberpunk 2077: tools and frameworks

| Link | License | Useful for |
|---|---|---|
| [WolvenKit/WolvenKit](https://github.com/WolvenKit/WolvenKit) | GPL-3.0 | Mod editor and CLI we use (`tools/wk`): archives, CR2W ↔ JSON |
| [jac3km4/redscript](https://github.com/jac3km4/redscript) | MIT | redscript compiler/decompiler; 0.5.32 added 2.5 support ([PR by alphanin9](https://github.com/jac3km4/redscript/pull/202)). Our sideload compiler and `redscript-check.sh` |
| [maximegmd/CyberEngineTweaks](https://github.com/maximegmd/CyberEngineTweaks) | MIT | CET: Lua scripting, console, hot reload, TweakDB edits. Our dev tool ([`thirdparty/`](thirdparty/README.md)) |
| [wopss/RED4ext](https://github.com/wopss/RED4ext) | MIT | Native plugin loader most Nexus frameworks build on |
| [psiberx/cp2077-archive-xl](https://github.com/psiberx/cp2077-archive-xl) | MIT | ArchiveXL; the 2.5 native loader reads the same `.archive.xl` ideas from `.archive.json` |
| [psiberx/cp2077-tweak-xl](https://github.com/psiberx/cp2077-tweak-xl) | MIT | TweakXL; `r6/tweaks` YAML format, which 2.5 also reads for mod.io mods |
| [psiberx/cp2077-codeware](https://github.com/psiberx/cp2077-codeware) | MIT | Script library (file access, more game APIs); RED4ext-based |
| [wiki.redmodding.org](https://wiki.redmodding.org/) | | Community modding wiki (WolvenKit, redscript, file formats) |
| [mod.io REST API docs](https://docs.mod.io/restapi/) | | Uploads, platforms, moderation ([locked platforms](https://docs.mod.io/restapi/docs/schemas/game-emh-object)) |
| [CDPR Fan Content Guidelines](https://www.cdprojektred.com/en/fan-content) | | What fan work may do |

## Cyberpunk 2077: public mod sources to learn from

| Link | License | Useful for |
|---|---|---|
| [alphanin9/CyberpunkNewGamePlus](https://github.com/alphanin9/CyberpunkNewGamePlus) | GPL-3.0 | New Game+; own `.gamedef` and root quest, how quests are hooked in |
| [jackhumbert/mod_settings](https://github.com/jackhumbert/mod_settings) | MIT | In-game mod settings menu (ink UI) |
| [tiltedphoques/CyberpunkMP](https://github.com/tiltedphoques/CyberpunkMP) | | Multiplayer mod; large WolvenKit + native project |
| [rfuzzo/cp77fuzzymods](https://github.com/rfuzzo/cp77fuzzymods) | MIT | Small mods by a WolvenKit developer |
| [radj307/HARDCORE44](https://github.com/radj307/HARDCORE44) | | Difficulty mod (gameplay tuning) |
| [DoctorPortal-IX/DWA-Arcadia-Mark-V](https://github.com/DoctorPortal-IX/DWA-Arcadia-Mark-V) | | Vehicle mod project |
| [JonnesTT/JonnesTTs_Cyberpunk2077_Mods](https://github.com/JonnesTT/JonnesTTs_Cyberpunk2077_Mods) | GPL-3.0 | Collection of active and abandoned mods |
| [dkollmann/cyberpunk2077-furigana](https://github.com/dkollmann/cyberpunk2077-furigana) | GPL-3.0 | UI/text mod (Japanese furigana) |

## Cyberpunk 2077: mods we looked at

| Link | Useful for |
|---|---|
| [Deceptious Quest Core (mod.io)](https://mod.io/g/cyberpunk-2077/m/deceptious-quest-core2) | DQC: quest framework our test mod plugs into |
| [Wall Hang (Nexus 2950)](https://www.nexusmods.com/cyberpunk2077/mods/2950) | CET mod: hang on and jump off walls; reference for wall detection |
| [WallRun mod (PCGamesN article, 2021)](https://www.pcgamesn.com/cyberpunk-2077/mod-wall-run) | Earlier wall run (CET + GravityTweaker); CDPR cut wall running after E3 2018 ([TweakTown](https://www.tweaktown.com/news/73559/cyberpunk-2077-wall-running-parkour-nuked-from-final-game/index.html)) |

## Mirror's Edge (2008): parkour reference

| Link | License | Useful for |
|---|---|---|
| [totenhack/megem](https://github.com/totenhack/megem) | Apache-2.0 | Modding/practice tools; `DLL/player.h` documents Faith's memory layout, used by `tools/me_capture.py` |
| [Degaussed/Livesplit-ASL-scripts](https://github.com/Degaussed/Livesplit-ASL-scripts) | | Autosplitters; static pointers per game version (Steam/GOG, Origin, Reloaded) |
| [fatalis/LiveSplit.MirrorsEdge](https://github.com/fatalis/LiveSplit.MirrorsEdge) | WTFPL | LiveSplit component (load detection) |
| [softsoundd/MirrorsEdgeTweaks](https://github.com/softsoundd/MirrorsEdgeTweaks) | GPL-3.0 | Current fixes and tweaks tool for the 2008 game |
| [softsoundd/MirrorsEdgeMapManager](https://github.com/softsoundd/MirrorsEdgeMapManager) | MIT | Custom map manager |
| [tnrjns/faith-runner](https://github.com/tnrjns/faith-runner) | MIT | Mirror's Edge movement, animation and first-person body re-implemented in Rust (Bevy), with Ghidra extraction notes |
| [dragon-fish/parkour-game](https://github.com/dragon-fish/parkour-game) | AGPL-3.0 + commercial | Godot parkour game. `docs/mirrors-edge-deep-research` (Chinese) is a reverse-engineering handbook on Mirror's Edge movement: speed curve, speed loss, wall run/climb/kick physics, the move state machine, all default values (appendix A1), tools incl. a frame-by-frame HUD reader |
| [btbd/mmultiplayer](https://github.com/btbd/mmultiplayer) ([softsoundd fork](https://github.com/softsoundd/mmultiplayer)) | | Multiplayer mod; `Client/sdk/` is a generated SDK of the game's classes: the `EMovement` enum (94 movement states) and field offsets |
| [Eideren/Mirror-s-Edge](https://github.com/Eideren/Mirror-s-Edge) | | Port to Unity with the game's scripts converted to C# (`TdMove_WallRun`, `TdPawn`, ...) |
| [speedrun.com/me](https://www.speedrun.com/me) | | Speedrun community: movement tech, resources |

## Parkour in other games

| Link | License | Useful for |
|---|---|---|
| [SlugGlove/Free-Running-Controller](https://github.com/SlugGlove/Free-Running-Controller) | | Unity free-running controller (Mirror's Edge / Apex style) |
| [mine-edge/MineEdge](https://github.com/mine-edge/MineEdge) | MIT | Mirror's Edge style movement mod for Minecraft |
| [letsgosportsteam/mirrors-edge-vr-mod](https://github.com/letsgosportsteam/mirrors-edge-vr-mod) | | VR mod for Mirror's Edge |

## Development tooling

| Link | License | Useful for |
|---|---|---|
| [JohnnyMorganz/StyLua](https://github.com/JohnnyMorganz/StyLua) | MPL-2.0 | Lua formatter (pre-commit) |
| [Kampfkarren/selene](https://github.com/Kampfkarren/selene) | MPL-2.0 | Lua linter (pre-commit, strict) |
| [LuaLS/lua-language-server](https://github.com/LuaLS/lua-language-server) | MIT | Lua type checker (pre-commit, strict) |
