# Cyberpunk 2077 movement captures

V's movement and camera in Cyberpunk 2077 (2.5, Steam, Proton), recorded with our CET mod [`dev-log`](../../mods/dev-log/README.md) in per-frame mode (≈ 67 lines/s, the frame rate), to compare with the [Mirror's Edge captures](../mirrors-edge/README.md). Our own measurements; no game files.

Cropped with `tools/devlog.py crop`: standstill lines are removed (so `t` has gaps); marker lines are kept.

| File | Lines | Contents |
|---|---|---|
| `20261025-172125.jsonl` | 18,606 | Marked test moves on rooftops in Watson: standing jumps, sprints from standstill, slides, vaults, dodges, double/charge jumps, landings from ~3.5 m, fast mouse turns. V is the Phantom Liberty quick-start character (see below) |

**Not a stock V:** the save is the Phantom Liberty quick-start character (level 15, preset attributes, perks and cyberware, incl. upgraded legs). Jump, double/charge jump, dodge and possibly sprint and slide numbers reflect that build. Gravity and the camera don't depend on it.

Marks (the F8 hotkey) group the moves:

| Marks | Moves |
|---|---|
| 1, 17 | standing jumps |
| 2–4, 13 | sprints from standstill (13: 11.7 s sprint with fast mouse turns) |
| 5, 18 | slides from a sprint |
| 6, 7, 12 | sprint jumps at walls |
| 8, 9, 15, 16 | vaults over low obstacles, jumps |
| 9, 10, 14 | double and charge jumps, onto and off roofs |
| 11 | forward dodges |

## Fields

One JSON object per line; units are metres and degrees. Marker lines are `{"t", "mark"}`.

| Field | Meaning |
|---|---|
| `t` | seconds since the mod (re)loaded |
| `pos` | V's position (at the feet) |
| `speed`, `speed_h` | total and horizontal speed, from the position change since the previous line (m/s) |
| `vel` | the game's velocity, or `null` when implausible (`GetVelocity()` sometimes returns nonsense) |
| `yaw` | V's facing |
| `locomotion` | movement state, named from the values the game's movement code writes (Default, Crouch, Sprint, Jump, Vault, Dodge, DodgeAir, Workspot, Slide, SlideFall, …) |
| `high_level` | `SceneTier1` = normal play |
| `cam_off` | active camera position minus `pos` (eye height ≈ 1.45 m standing) |
| `cam_rot` | view pitch, yaw, roll, from the camera's forward and right vectors |
| `fov` | field of view as the game reports it (51.0, which looks like the vertical FOV) |
