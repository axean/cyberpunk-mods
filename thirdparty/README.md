# thirdparty

Other authors' mods we use, installed with [`tools/thirdparty.sh`](../tools/thirdparty.sh). Only this list is in git: the zips, install manifests and generated dev-status entries in this folder are git-ignored. Download each file yourself from the links below and check its sha256.

| Name | Version | For game | Download | sha256 of the zip | License |
|---|---|---|---|---|---|
| Cyber Engine Tweaks (CET) | 1.38.0 (2026-10-22) | 2.5 | [GitHub release v1.38.0](https://github.com/maximegmd/CyberEngineTweaks/releases/tag/v1.38.0), file `cet_1_38_0.zip` (same file on [Nexus mod 107](https://www.nexusmods.com/cyberpunk2077/mods/107)) | `6da2e91b07d5ea9dd4aa32145b2c2920a976abee481854976e2ae82169b612e1` | MIT ([source](https://github.com/maximegmd/CyberEngineTweaks)) |

```sh
sha256sum cet_1_38_0.zip
tools/thirdparty.sh install cet cet_1_38_0.zip   # stores it here as cet.zip
tools/thirdparty.sh list
tools/thirdparty.sh uninstall cet
```

## Cyber Engine Tweaks

Development tool: Lua scripting with in-game reload of Lua mods, a console, a log file, and TweakDB edits at runtime. Native code, PC only, and tied to the game version (a new CET is needed after every game patch). Our published mods do not depend on it.

Loads through `bin/x64/version.dll` (Ultimate ASI Loader), which loads `bin/x64/plugins/cyber_engine_tweaks.asi`.

> [!IMPORTANT]
> **Required on Linux (Proton):** Wine uses its own built-in `version.dll` unless told otherwise, so CET does not load without this in the game's Steam launch options:
>
> ```
> WINEDLLOVERRIDES="version=n,b" %command%
> ```
>
> Full line we use: see [Game setup](../README.md#game-setup). On the first start with CET, it asks for a key to open its overlay.
