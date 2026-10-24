# cyberpunk-mods

Cyberpunk 2077 mods, and notes on how modding works. Long-term goal: questline mods.

- `NOTES.md`: findings on how modding works
- `tools/snap.sh`: snapshot the game dir and Proton prefix, diff before/after installing a mod
- `tools/verify_steam.py`: check the game dir against Steam's depot manifests (`~/.local/share/Steam/depotcache/`)

```sh
tools/snap.sh take before
# install a mod
tools/snap.sh take after
tools/snap.sh diff before after
```

Snapshots and unpacked third-party mods stay local (`snapshots/`, `dissected/`, both git-ignored).
