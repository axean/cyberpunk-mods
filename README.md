# cyberpunk-mods

[![Cyberpunk 2077](https://img.shields.io/badge/Cyberpunk_2077-2.5-FCEE0A)](https://www.cyberpunk.net/)
[![Unofficial fan work](https://img.shields.io/badge/fan_work-unofficial-lightgrey)](https://www.cdprojektred.com/en/fan-content)
[![Python 3.12+](https://img.shields.io/badge/python-3.12%2B-3776AB?logo=python&logoColor=white)](https://www.python.org/)
[![uv](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/astral-sh/uv/main/assets/badge/v0.json)](https://github.com/astral-sh/uv)
[![Checked with pyright](https://microsoft.github.io/pyright/img/pyright_badge.svg)](https://microsoft.github.io/pyright/)
[![Ruff](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/astral-sh/ruff/main/assets/badge/v2.json)](https://github.com/astral-sh/ruff)
[![pre-commit](https://img.shields.io/badge/pre--commit-enabled-brightgreen?logo=pre-commit)](https://github.com/pre-commit/pre-commit)

Cyberpunk 2077 mods, and notes on how modding works. Long-term goal: questline mods.

> [!IMPORTANT]
> **Disclaimer:** This is an unofficial fan work and is not approved/endorsed by CD PROJEKT RED.
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
