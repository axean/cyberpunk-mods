# cyberpunk-mods

Cyberpunk 2077 mods, and notes on how modding works. Long-term goal: questline mods.

- `NOTES.md`: findings from taking apart other mods
- `tools/snap.sh`: snapshot the game dir and Proton prefix, diff before/after installing a mod

```sh
tools/snap.sh take before
# install a mod
tools/snap.sh take after
tools/snap.sh diff before after
```

Snapshots and unpacked third-party mods stay local (`snapshots/`, `dissected/`, both git-ignored).
