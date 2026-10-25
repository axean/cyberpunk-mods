# parkour

Mirror's Edge style movement for Cyberpunk 2077 (CET Lua). Work in progress: first the wall run, tuned against our [Mirror's Edge captures](../../datasets/comparison.md).

Status (2026-10-25): **wall run works** (milestones 1–2). Jump next to a tall wall while moving along it: V is lifted (5.15 m/s), runs along the wall with lower gravity (9.0 rising, 5.5 falling; Mirror's Edge's 8.2 / 5.0 plus 10%), view tilted ~22° away from the wall, footstep sounds. Peak +1.25 m after ~0.52 s; ends on landing, falling faster than 5 m/s, or at the end of the wall. V's double jump on the wall becomes a jump away from it (5 m/s away, 3 m/s up) that keeps the speed along the wall.

How it works: wall raycasts left and right of the movement direction (chest and 2 m height), velocity control with per-frame `PSMImpulse` events (gravity compensation plus damping; a full per-frame correction overshoots), camera roll with `FPPCameraComponent:SetLocalOrientation`, sounds with `SoundPlayEvent`. Cyberpunk picks landing damage from the falling speed at impact (gravity 16 m/s²), so wall running itself can't hurt V.

**Momentum works** (2026-10-25). On the ground the mod sets V's speed cap and acceleration through stat modifiers. The cap follows a carried speed:
- the sprint builds up over 1–2 s
- landings keep the speed from the air (minus 0.65 m/s)
- speed above the game's cap fades at 3 m/s² while the stick points on; after a dash, 80% of its extra speed is carried
- turns are wider (acceleration 15 instead of 24)

In the air and in other moves the game's own stats apply. Test race (~130 m, same course): 15.5 s without, 10.0 s with momentum.

Why stats, not pushing: pushing V with a `PSMImpulse` every frame on the ground suppressed the dash's own boost (dash peak 16–23 instead of 31–42 m/s). The game's movement values per state are in TweakDB `PlayerLocomotion.player_locomotion_data_<state>`: sprint cap 7.5, jog 3.5, air 4.5 (braking 1.3), landing 4.5 (braking 24).

Next: impact damage (impacts are already detected and logged), wall climb, edge cases (instant one-frame runs, combat, vehicles).

```sh
tools/build-mod.sh mods/parkour --install   # then "Reload all mods" in CET
```

Hotkeys (CET Bindings): "parkour: wall run on/off", "parkour: momentum on/off" (default on, show an on-screen message). `dev-log` logs the mod's state (`parkour` field).
