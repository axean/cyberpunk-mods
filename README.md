# modding-tools

[![Python 3.12+](https://img.shields.io/badge/python-3.12%2B-3776AB?logo=python&logoColor=white)](https://www.python.org/)
[![uv](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/astral-sh/uv/main/assets/badge/v0.json)](https://github.com/astral-sh/uv)
[![Checked with pyright](https://microsoft.github.io/pyright/img/pyright_badge.svg)](https://microsoft.github.io/pyright/)
[![Ruff](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/astral-sh/ruff/main/assets/badge/v2.json)](https://github.com/astral-sh/ruff)
[![pre-commit](https://img.shields.io/badge/pre--commit-enabled-brightgreen?logo=pre-commit)](https://github.com/pre-commit/pre-commit)

Tools, notes and mods for game modding, by game. Main project: Cyberpunk 2077 mods (long-term goal: questline mods). Mirror's Edge (2008) is measured as the reference for parkour movement.

- [`tools/`](tools/README.md): our scripts, for both games
- [`REFERENCES.md`](REFERENCES.md): external repos and pages worth knowing
- [`datasets/`](datasets/README.md): our movement measurements, and a [Mirror's Edge vs Cyberpunk comparison](datasets/comparison.md)

## Cyberpunk 2077

[![Cyberpunk 2077](https://img.shields.io/badge/Cyberpunk_2077-2.5-FCEE0A)](https://www.cyberpunk.net/)
[![Unofficial fan work](https://img.shields.io/badge/fan_work-unofficial-lightgrey)](https://www.cdprojektred.com/en/fan-content)

> [!IMPORTANT]
> **Disclaimer:** This is an unofficial fan work and is not approved/endorsed by CD PROJEKT RED.
>
> Made under the [CD PROJEKT RED Fan Content Guidelines](https://www.cdprojektred.com/en/fan-content) and [User Agreement](https://regulations.cdprojektred.com/en/user_agreement). This repo does **not** contain:
>
> - game files or assets extracted from the game
> - CD PROJEKT RED's modding tools or documentation (REDmod)
> - files from other authors' mods

- `NOTES.md`: findings on how Cyberpunk modding works
- `TOOLS.md`: external modding tools (WolvenKit, Graphviz, ...)
- [`thirdparty/`](thirdparty/README.md): other authors' mods we use (links and checksums only)
- `mods/`: our own mods
  - [`test-mod-hello-world-dqc-33`](mods/test-mod-hello-world-dqc-33/README.md): DQC slot test
  - [`dev-status`](mods/dev-status/README.md): texts which dev mods are loaded
  - [`hello-night-city-billboards`](mods/hello-night-city-billboards/README.md): billboard text
  - [`dev-log`](mods/dev-log/README.md): live movement and camera log (CET)
  - [`parkour`](mods/parkour/README.md): Mirror's Edge style movement, wall run in progress (CET)
- [`datasets/cyberpunk/`](datasets/cyberpunk/README.md): our movement captures

### Game setup

Steam → Cyberpunk 2077 → Properties → General → Launch Options:

```
WINEDLLOVERRIDES="version=n,b" PROTON_LOG=1 %command% --launcher-skip -skipStartScreen
```

| Option | Why |
|---|---|
| `WINEDLLOVERRIDES="version=n,b"` | **Required for CET** under Proton: use the game folder's `version.dll` (CET's loader) instead of Wine's |
| `PROTON_LOG=1` | Proton writes `~/steam-1091500.log`, which shows why the game fails to start |
| `--launcher-skip` | skips CDPR's launcher |
| `-skipStartScreen` | skips the "press any key" screen |

CET also needs a current Visual C++ runtime in the game's Proton prefix; see [`thirdparty/`](thirdparty/README.md#cyber-engine-tweaks).

Our sideloads also need redscript in the game dir (`tools/install-redscript.sh`), and third-party mods are installed with `tools/thirdparty.sh` (see [`thirdparty/`](thirdparty/README.md)).

## Mirror's Edge (2008)

[![Mirror's Edge](https://img.shields.io/badge/Mirror's_Edge-2008-E8202A)](https://store.steampowered.com/app/17410/Mirrors_Edge/)
[![Reference only](https://img.shields.io/badge/use-movement_reference-lightgrey)](datasets/mirrors-edge/README.md)

> [!IMPORTANT]
> **Disclaimer:** This is unofficial and is not affiliated with, approved or endorsed by Electronic Arts or DICE. Mirror's Edge is a trademark of Electronic Arts.
>
> We only read Faith's movement from the running game's memory (read-only; nothing is injected or changed) and publish our own measurements. This repo does **not** contain:
>
> - game files or assets extracted from the game
> - code or files from Mirror's Edge mods and tools (offsets we use are credited in the source)

- [`tools/me_capture.py`](tools/README.md): records Faith's position, velocity, movement state and camera at 60 Hz while you play
- [`datasets/mirrors-edge/`](datasets/mirrors-edge/README.md): our captures (training course, chapters 1–2), fields and movement states
- [`REFERENCES.md`](REFERENCES.md#mirrors-edge-2008-parkour-reference): Mirror's Edge tools and research we build on

```sh
uv run tools/me_capture.py                     # while the game runs; writes captures/mirrors-edge/
uv run tools/me_capture.py --crop IN.jsonl OUT.jsonl   # drop menu, loading and standstill lines
```

## Setup

```sh
uv sync
tools/install-lua-tools.sh   # selene + lua-language-server for the Lua hooks
uv run pre-commit install
```

Checks run on every commit: ruff and strict pyright for Python, shellcheck for shell, StyLua, selene (strict) and lua-language-server (strict, CET types in `typings/cet/`) for Lua.
