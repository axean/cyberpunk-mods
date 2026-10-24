# Tools

Modding tools used in this repo. One page per external tool under `docs/tools/`.

## External

| Tool | Version | What for | Notes |
|---|---|---|---|
| WolvenKit CLI | 10.0.0-beta.1 | Unpack/pack `.archive`, convert CDPR resources (CR2W) to JSON and back, build mod projects | [docs/tools/wolvenkit.md](docs/tools/wolvenkit.md) |
| REDmod metadata (CDPR) | 2.00 | `metadata-resources.csv`: list of all game resource paths, input for `tools/assetrefs.py` | In `REDmodPlugin_updated.zip` from CDPR's CDN. Mod Tools EULA: personal use, so not in this repo |

## In this repo

| Script | What for |
|---|---|
| `tools/wk` | Runs the pinned WolvenKit CLI |
| `tools/install-wolvenkit.sh` | Installs WolvenKit CLI + .NET 10 runtime under `~/.local/opt` |
| `tools/snap.sh` | Snapshot game dir + Proton prefix, diff two snapshots |
| `tools/verify_steam.py` | Check the game dir against Steam's depot manifests |
| `tools/savdat.py` | Decode `sav.dat`: nodes, facts, fact diffs |
| `tools/assetrefs.py` | Classify the resources an unpacked mod references: vanilla, its own, or neither |
