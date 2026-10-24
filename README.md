# cyberpunk-mods

Cyberpunk 2077 mods, and notes on how modding works. Long-term goal: questline mods.

> [!IMPORTANT]
> This is an unofficial fan work and is not approved/endorsed by CD PROJEKT RED.
>
> Made under the [CD PROJEKT RED Fan Content Guidelines](https://www.cdprojektred.com/en/fan-content) and [User Agreement](https://regulations.cdprojektred.com/en/user_agreement). This repo does not contain:
>
> - game files or assets extracted from the game
> - CD PROJEKT RED's modding tools or documentation (REDmod)
> - files from other authors' mods

- `NOTES.md`: findings on how modding works
- `TOOLS.md`: index of modding tools (WolvenKit, ...) and the scripts in `tools/`
- `tools/snap.sh`: snapshot the game dir and Proton prefix, diff before/after installing a mod
- `tools/verify_steam.py`: check the game dir against Steam's depot manifests (`~/.local/share/Steam/depotcache/`)
- `tools/savdat.py`: decode a `sav.dat`: node tree, node dumps, facts by name, fact diffs between saves

## Setup

```sh
uv sync
uv run pre-commit install
```

## Usage

```sh
tools/snap.sh take before
# install a mod
tools/snap.sh take after
tools/snap.sh diff before after

uv run tools/savdat.py facts <save>/sav.dat q101_done
uv run tools/savdat.py factdiff <old>/sav.dat <new>/sav.dat [candidate fact names...]
```

Snapshots (except `snapshots/vanilla`) and unpacked third-party mods stay local (`snapshots/`, `dissected/`).
