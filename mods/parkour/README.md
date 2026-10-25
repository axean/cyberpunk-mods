# parkour

Mirror's Edge style movement for Cyberpunk 2077 (CET Lua). Work in progress: first the wall run, tuned against our [Mirror's Edge captures](../../datasets/comparison.md).

Status (2026-10-25): **wall run works** (milestones 1–2). Jump next to a tall wall while moving along it: V is lifted (5.15 m/s), runs along the wall with lower gravity (9.0 rising, 5.5 falling; Mirror's Edge's 8.2 / 5.0 plus 10%), view tilted ~22° away from the wall, footstep sounds. Peak +1.25 m after ~0.52 s; ends on landing, falling faster than 5 m/s, or at the end of the wall. V's double jump on the wall becomes a jump away from it (5 m/s away, 3 m/s up) that keeps the speed along the wall.

How it works: wall raycasts left and right of the movement direction (chest and 2 m height), velocity control with per-frame `PSMImpulse` events (gravity compensation plus damping; a full per-frame correction overshoots), camera roll with `FPPCameraComponent:SetLocalOrientation`, sounds with `SoundPlayEvent`. Cyberpunk picks landing damage from the falling speed at impact (gravity 16 m/s²), so wall running itself can't hurt V.

Next: momentum (speed buildup and loss like Mirror's Edge), wall climb, edge cases (instant one-frame runs, combat, vehicles).

```sh
tools/build-mod.sh mods/parkour --install   # then "Reload all mods" in CET
```

Hotkey (CET Bindings): "parkour: wall run on/off" (default on, shows an on-screen message). `dev-log` logs the mod's state (`parkour` field).
