# Tools

Modding tools used in this repo. One page per external tool under `docs/tools/`.

## External

| Tool | Version | What for | Notes |
|---|---|---|---|
| WolvenKit CLI | 10.0.0-beta.1 | Unpack/pack `.archive`, convert CDPR resources (CR2W) to JSON and back, build mod projects | [docs/tools/wolvenkit.md](docs/tools/wolvenkit.md) |
| Graphviz | any recent | Layout and rendering for `tools/questgraph.py` (`dot`) | System package (`apt install graphviz`) |
| REDmod metadata (CDPR) | 2.00 | `metadata-resources.csv`: list of all game resource paths, input for `tools/assetrefs.py` | In `REDmodPlugin_updated.zip` from CDPR's CDN. Mod Tools EULA: personal use, so not in this repo |

## In this repo

See [`tools/README.md`](tools/README.md).
