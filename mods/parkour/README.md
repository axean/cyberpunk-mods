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

**Wall climb, first version** (2026-10-25). Jump at a tall wall head-on (facing within 33° of it) with the stick forward:
- V is pulled tight against the wall and climbs with gravity 9 m/s².
- The height comes from the run-up speed, shaped like Faith's climbs: nothing from a standstill, 1.8 m at 3.5 m/s, 2.9 m at a full sprint, up to 4.5 m after a dash.
- The view pitches up 25°.
- Bumps on the wall (sills, pipes, signs) are remembered and V is held clear of them; an overhang over 0.8 m ends the climb.
- Her upward speed follows the planned climb every frame, so the jump's first frames can't cut it short.
- The climb ends when V stops rising or reaches the top (a small push over the edge), or when the game's own ledge climb takes over.

**Springboard, first version** (2026-10-25). Run at an obstacle 0.6–1.5 m tall (at least 4 m/s, within 1.2× the game's vault range), look up above it (at least 10°) and jump:
- V steps off it at 9.5 m/s upward from its top (Mirror's Edge SpringBoardJumpZ), gives up 1 m/s of horizontal speed (not below 4) and hangs 0.3 s at the top.
- While these conditions hold, the game's vault and ledge climb are held back (their TweakDB ranges set to 0).
- Otherwise the game's vault works as usual.
- First test: one springboard, about 4 m up; vaults happened when the view was level (−5° to +5°).

**Settings**: the CET overlay has a "parkour" window with sliders for nearly every tuning value (base speed, momentum, wall run, wall climb, camera), saved to `settings.txt` in the mod folder. Base speed is a multiplier on V's speed cap in every state (a stat modifier, so the dash stays intact). Wall runs and climbs use the game's sprint footstep (harder than the run step).

Code: `init.lua` wires up the modules in `modules/` (state, settings, world, input, walls, speed, momentum, wallrun, wallclimb, camera).

Next: test the springboard at per-frame logging (does the vault stay out of the way reliably), the end of the climb (ledge grab, 180° turn jump), hands during the climb, impact damage (impacts are already detected and logged), edge cases (instant one-frame runs, combat, vehicles).

```sh
tools/build-mod.sh mods/parkour --install   # then "Reload all mods" in CET
```

Hotkeys (CET Bindings): "parkour: wall moves on/off", "parkour: momentum on/off" (default on, show an on-screen message). `dev-log` logs the mod's state (`parkour` field).
