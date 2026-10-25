# tools

Scripts for studying and building mods. External tools (WolvenKit, Graphviz, REDmod metadata) are listed in [`TOOLS.md`](../TOOLS.md).

> [!NOTE]
> **The graph is the mod.** A quest graph you build is your own work, even when every node is an engine node type and every reference points into the game. Node types are the engine's building blocks, and resource paths, TweakDB IDs and vanilla fact names are pointers. Graphs, wiring, flags and IDs you write can be published.
>
> What stays out of this repo is anything copied out of the game:
>
> - vanilla `.questphase` or `.scene` files you edit (e.g. a hook): keep only your changes, and apply them at build time to the file extracted from the player's own game
> - vanilla data embedded in your files, such as dialogue text or lip-sync: reference lines by ID instead
>
> This is our reading of the [Fan Content Guidelines](https://www.cdprojektred.com/en/fan-content) and [User Agreement](https://regulations.cdprojektred.com/en/user_agreement), not legal advice.

| Script | What for |
|---|---|
| `wk` | Runs the pinned WolvenKit CLI |
| `install-wolvenkit.sh` | Installs WolvenKit CLI + .NET 10 runtime under `~/.local/opt` |
| `snap.sh` | Snapshot the game dir and Proton prefix, diff before/after installing a mod |
| `verify_steam.py` | Check the game dir against Steam's depot manifests (`~/.local/share/Steam/depotcache/`) |
| `savdat.py` | Decode a `sav.dat`: node tree, node dumps, facts by name, fact diffs between saves |
| `questgraph.py` | Render a `.quest`, `.questphase` or `.scene` (WolvenKit JSON) as a flowchart (needs Graphviz) |
| `assetrefs.py` | List which resources an unpacked mod references: vanilla, its own, or neither |
| `wkjson.py` | Write WolvenKit JSON from Python: quest graphs, journal, onscreen text, trigger sectors |
| `build-mod.sh` | Build `mods/<mod>` (its `build.py`) into a mod.io zip under `build/` |

## Usage

```sh
tools/snap.sh take before
# install a mod
tools/snap.sh take after
tools/snap.sh diff before after

uv run tools/savdat.py facts <save>/sav.dat q101_done
uv run tools/savdat.py factdiff <old>/sav.dat <new>/sav.dat [candidate fact names...]

uv run tools/questgraph.py <file>.questphase.json -o graph.svg
uv run tools/questgraph.py <file>.scene.json --from <node id> --stop <node id> --loc <subtitles>.json --fold -o graph.png

uv run tools/assetrefs.py <mod dir with raw/ and json/> <metadata-resources.csv> [-v]

tools/build-mod.sh mods/<mod>
```

Each script prints its full usage with `--help` or without arguments.

> [!IMPORTANT]
> Snapshots (except `snapshots/vanilla`), unpacked third-party mods and diagrams rendered from them stay local (`snapshots/`, `dissected/`, both git-ignored). Never commit them.
