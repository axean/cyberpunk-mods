# hello-night-city-billboards

Every Mr. Stud billboard ad says "HELLO NIGHT CITY -AA" in pink Orbitron (the game's font) on a dark background, on every screen shape. Works (2026-10-25), sideload only.

> [!IMPORTANT]
> **Disclaimer:** This is an unofficial fan work and is not approved/endorsed by CD PROJEKT RED.

How: `build.py` takes Mr. Stud's ad widgets from the player's own game at build time, replaces the images in each screen-shape layout with one text widget, and packs them under the original paths, so they override the vanilla ones everywhere. Only the patch code is in this repo; the built zip contains patched game data and is for local use only.

```sh
tools/build-mod.sh mods/hello-night-city-billboards --install   # needs the game installed
```
