# WolvenKit

Community modding toolkit for Cyberpunk 2077 (C#/.NET, open source): <https://github.com/WolvenKit/WolvenKit>, wiki: <https://wiki.redmodding.org/wolvenkit>.

- **GUI** (Windows, WPF): asset, quest graph and scene editors, mod projects (`.cpmodproj`), packaging. Not installed; no native Linux build.
- **CLI** (`WolvenKit.CLI`): native Linux build in every release as `WolvenKit.ConsoleLinux-<version>.zip`. Installed here.

## Install

```sh
tools/install-wolvenkit.sh   # ~/.local/opt/wolvenkit/<version>, .NET 10 runtime in ~/.local/opt/dotnet
tools/wk --version
```

Pinned to 10.0.0-beta.1 (2026-10-24), the first release with "early support for game version 2.5". The zip's sha256 is pinned in the install script. Change `VERSION`/`SHA256` there and `WK_VERSION` in `tools/wk` to upgrade. The CLI needs the .NET 10 runtime (framework-dependent build); Kraken/Oodle decompression is bundled (`libkraken.so`).

## Commands used so far

```sh
tools/wk archive -l <file.archive>                    # list files (paths are resolved, not hashes)
tools/wk archive -l -w '*.questphase' <file.archive>  # filter
tools/wk extract <file.archive> -o <dir>              # unpack to CR2W files
tools/wk convert serialize <dir> -o <abs-dir>         # CR2W -> JSON (output dir must exist)
```

Other commands: `extract-and-export`/`uncook` (export to raw formats), `import`, `export`, `pack`, `build` (`.cpmodproj`), `convert deserialize` (JSON -> CR2W), `conflicts`, `hash`, `oodle`, `wwise`.

## What the JSON shows

Quest files (`.questphase`) become graphs of typed nodes. Fact access looks like:

- `questFactsDBCondition` > `questVarComparison_ConditionType` with `factName`, `comparisonType` (`Equal`, `Less`, `Greater`, ...), `value`
- `questFactsDBManagerNodeDefinition` > `questSetVar_NodeType` with `factName`, `value`, `setExactValue`

Fact values are signed 32-bit. Combined with `tools/savdat.py factdiff <old> <new> <names...>`, fact names from a mod's quest files resolve the hashes in a save.
