# Mirror's Edge movement captures

Faith's movement in Mirror's Edge (2008, Steam build 252134), recorded with [`tools/me_capture.py`](../../tools/me_capture.py) at 60 Hz while playing, as the reference for parkour in our Cyberpunk mods. Our own measurements; no game files. Mirror's Edge is EA/DICE's; this repo is not affiliated with them.

Cropped with `me_capture.py --crop`: main menu, loading and standstill lines are removed, so `t` has gaps.

| File | Levels | Lines | Contents |
|---|---|---|---|
| `20261025-160313.jsonl` | `tutorial_p` (training), `Edge_p` (chapter 1) | 21,208 | Training course: runs, jumps, 19 wall runs, wall climbs, vaults, slides, rolls, zipline, swings, sidesteps. No camera fields; `health`, `wallrun`, `wall` read wrong values (ignore them) |
| `20261025-162844.jsonl` | `Edge_p`, `Escape_p` (chapter 2) | 30,752 | Chapter play with camera fields: 9 wall runs, 8 sidesteps, 33 landings incl. rolls and a hard landing, one 180 turn |

## Fields

One JSON object per line. Units: Unreal units, **1 uu = 1 cm**; rotations in degrees.

| Field | Meaning |
|---|---|
| `t` | seconds since the capture started |
| `level` | level package name |
| `pos`, `vel` | Faith's position and velocity (uu, uu/s) |
| `speed_h`, `speed` | horizontal and total speed (uu/s) |
| `rot` | body rotation: pitch, yaw, roll |
| `move` | movement state (`TdPawn.EMovement`, table below) |
| `walk`, `action` | walking and action state bytes (not decoded yet) |
| `health` | session 2 only: health, 100 = full |
| `cam_off` | session 2 only: rendered camera position minus `pos` (eye height ≈ 62 when walking) |
| `cam_rot` | session 2 only: rendered camera pitch, yaw, roll |
| `fov` | session 2 only: field of view |

## Movement states seen

From the `EMovement` enum (as listed in the [mmultiplayer SDK](https://github.com/btbd/mmultiplayer)):

| `move` | State | `move` | State |
|---|---|---|---|
| 1 | Walking (incl. running) | 21 | Climb |
| 2 | Falling | 22 | IntoClimb |
| 3 | Grabbing (ledge hang) | 24 | 180Turn |
| 4 | WallRunningRight | 27 | IntoZipLine |
| 5 | WallRunningLeft | 28 | ZipLine |
| 6 | WallClimbing | 29 | Balance |
| 7 | SpringBoarding | 30 | LedgeWalk |
| 9 | VaultOver | 31 | GrabTransfer (shimmy) |
| 10 | GrabPullUp | 32 | MeleeAir |
| 11 | Jump | 33 | DodgeJump (sidestep) |
| 12 | WallRunJump | 35 | Stumble |
| 14 | IntoGrab | 60 | Swing |
| 15 | Crouch | 61 | Coil |
| 16 | Slide | 72 | FallingUncontrolled |
| 17 | Melee | 73 | SwingJump |
| 19 | Barge | 78 | SoftLanding |
| 20 | Landing (hard landing) | 91 | SkillRoll |
