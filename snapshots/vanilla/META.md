# Vanilla baseline

Taken 2026-10-24T19:44:45Z, just before installing the first mod.io mod.

## Game

| | |
|---|---|
| Version | 2.5 (`Cyberpunk2077.exe` ProductVersion 2.5, FileVersion 3.0.5813403) |
| Steam buildid | 26161058, updated 2026-10-23T19:45:23Z |
| Depots | 1091501 base, manifest 3524634124112875626, 66.8 GB |
| | 2138330 Phantom Liberty (DLC), manifest 5565496786254603194, 14.6 GB |
| Language | english |
| Size on disk | 81.4 GB, 236 entries (186 files) |
| Launcher | `REDprelauncher.exe`, `launcher-configuration.json`: platform steam, exe `bin\x64\Cyberpunk2077.exe` |

Sizes: `archive/pc/content` 61G (33 archives), `archive/pc/ep1` 14G, `bin` 554M, `engine` 185M, `r6` 110M.

No mods or frameworks in the game dir: no `mods/`, `archive/pc/mod/`, `red4ext/`, `bin/x64/plugins/`. `r6/` has only `cache/`, `config/`, `publishing/`.

Script and tweak caches (`r6/cache/`):

| File | Size | sha256 |
|---|---|---|
| `final.redscripts` | 19280419 | `b78043064ae90fb80861b0d885d1c8dbcd22070f1db71f20664d19f2d83c4aac` |
| `tweakdb.bin` | 44143434 | see `game.sha256` |
| `tweakdb_ep1.bin` | 50350405 | see `game.sha256` |

`Cyberpunk2077.exe` sha256: `d36e74c47592e9c656ae250078cb40b2be63c782af5bfbeff2280d43e653fab4`.

## Runtime

| | |
|---|---|
| Proton | Experimental, `experimental-11.0-20261014` (prefix version 11.0-100) |
| Steam Linux Runtime | 4, depot 4.0.20261021.265997 (pressure-vessel 0.20261007.0) |
| Host | Linux 7.0.0-38-generic |

## Prefix state

Not a fresh prefix. Before this snapshot the game had been run and the in-game mod browser opened, so it already has:

- mod.io account (`AppData/Local/mod.io/5784/steamuser/user.json`), `globalsettings.json` with `RootLocalStoragePath: C:/users/Public/mod.io/`
- `users/Public/mod.io/5784/metadata/state.json` (23 bytes, no mods) and 77 thumbnail cache entries
- `EnabledMods.json` (291 bytes, no enabled mods)
- REDlauncher installed under `AppData/Local/Programs/CD Projekt Red/REDlauncher`

## Files

- `game.tsv`, `prefix.tsv`: path, size, mtime (`tools/snap.sh` format)
- `game.sha256`: sha256 of every file in the game dir, hashed 2026-10-24T20:00Z.

## Verification

- `tools/verify_steam.py` against Steam's cached depot manifests (`depotcache/1091501_3524634124112875626.manifest`, `2138330_5565496786254603194.manifest`): all 182 shipped files match CDPR's SHA-1, none missing.
- `game.sha256` re-checked against the same files: all 186 OK.
- `game.tsv` (taken before any mod install) matches a listing taken at hash time: same paths, sizes and mtimes.

So the 182 shipped files in `game.sha256` are vanilla 2.5. The 4 other files are not shipped by Steam; they were written on first launch (2026-10-24 ~19:28Z), before this snapshot:

| File | Size | What |
|---|---|---|
| `bin/x64/CrashInfo.json` | 0 | crash reporter |
| `bin/x64/Cyberpunk2077.exe-<timestamp>.txt` | 31 | crash reporter |
| `bin/x64/REDEngineErrorReporter.exe-<timestamp>.txt` | 31 | crash reporter |
| `bin/x64/vkd3d-proton.cache.write` | 1038776 | vkd3d-proton shader cache, changes as you play |
