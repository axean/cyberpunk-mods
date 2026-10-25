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
> Made under the [CD PROJEKT RED Fan Content Guidelines](https://www.cdprojektred.com/en/fan-content) and [User Agreement](https://regulations.cdprojektred.com/en/user_agreement). This repo does **not** contain:
>
> - game files or assets extracted from the game
> - CD PROJEKT RED's modding tools or documentation (REDmod)
> - files from other authors' mods

- `NOTES.md`: findings on how modding works
- `TOOLS.md`: external modding tools (WolvenKit, Graphviz, ...)
- [`tools/`](tools/README.md): our scripts and how to use them
- [`thirdparty/`](thirdparty/README.md): other authors' mods we use (links and checksums only)
- `mods/`: our own mods ([`test-mod-hello-world-dqc-33`](mods/test-mod-hello-world-dqc-33/README.md): DQC slot test; [`dev-status`](mods/dev-status/README.md): texts which dev mods are loaded; [`hello-night-city-billboards`](mods/hello-night-city-billboards/README.md): billboard text)

## Setup

```sh
uv sync
uv run pre-commit install
```
