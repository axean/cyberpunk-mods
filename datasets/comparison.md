# Mirror's Edge vs Cyberpunk 2077: movement

Measured from our captures ([Mirror's Edge](mirrors-edge/README.md), [Cyberpunk](cyberpunk/README.md)), 2026-10-25, in metres. Mirror's Edge values marked † are from the [parkour-game research handbook](https://github.com/dragon-fish/parkour-game/tree/main/docs/mirrors-edge-deep-research) and agree with our captures. In Cyberpunk, V is the Phantom Liberty quick-start character (level 15, preset perks and cyberware, incl. upgraded legs), so jump, dodge and possibly sprint and slide numbers are not a stock V's; gravity and camera are unaffected.

| | Mirror's Edge | Cyberpunk 2077 | Difference |
|---|---|---|---|
| gravity | 16.0 m/s² † (15.4 measured) | 15.9 m/s² (15.4–16.2) | the same |
| standing jump take-off | 6.3 m/s † (6.0 measured) | 5.6 m/s | Mirror's Edge slightly stronger |
| standing jump height | 1.24 m † | 0.96 m | Mirror's Edge higher |
| jump airtime | 0.79 s † | 0.71 s | |
| sprint buildup | ~7 s to top speed † | 8.8 m/s after 0.5 s | Cyberpunk is at full speed instantly |
| top running speed | 7.2 m/s † (7.8 measured) | 8.6 m/s | Cyberpunk faster |
| head bob (running) | 6–14 cm at 3.3–3.5 Hz, 12–14 cm sideways, roll up to 1.5–2.7°; calmer at top speed | 8.6 cm at ~2.2 Hz, 7.6 cm sideways, roll under 0.4° | Cyberpunk calmer, almost no roll |
| eye height above the feet | ≈ 1.5 m (estimated) | 1.45 m standing, 1.62 m sprinting | Cyberpunk's camera rises when sprinting |
| field of view | 90° horizontal, constant | 51 (vertical, ≈ 80° horizontal), constant | neither widens with speed |
| slide | 0.6 s at 5.4–6.7 m/s, eye drops ~0.54 m | 0.8–1.3 s, entry ~11 m/s → exit 2.5–5.4 m/s, eye at 0.36 m | Cyberpunk: boosted slide that bleeds speed |
| vault (low obstacle) | VaultOver ~0.8 s | 0.2–0.33 s, 8 → 4–6 m/s | Cyberpunk fast but halves the speed |
| dodge | sidestep (DodgeJump): 6.3–7.6 m/s sideways + 2.7 m/s hop, 0.3 s, speed carries into the run | forward dash: 26–33 m/s peak, 0.2 s, 3.5–4.8 m | different moves |
| double/charge jump | — | 5.6 m/s, then a mid-air boost of 4.5–9.4 m/s after 0.1–0.4 s: ~3.5 m up | Cyberpunk only |
| landing from ~3.5 m | camera dip 3–10 cm, speed kept | camera dip 4–17 cm, speed mostly kept | similar |
| hard landing | 5.3–10 m without roll: speed to 0, −15% health †; roll: no loss, view drops ~1.4 m and pitches to −88° | not measured (no 5+ m drops yet) | |
| 180° turn | 180Turn: ~180° in 0.2 s, roll up to 15°, near stop then re-accelerate | mouse flicks up to 161° in 0.16 s (~1040°/s) | Mirror's Edge's is automatic and costs speed |
| wall run | on-wall gravity 8.2 rising / 5.0 falling †, entry lift 5.15 m/s, ~5%/s speed loss, ~1.65 s max †, camera roll building to 17–24° away from the wall, eye +10 cm | none (cut in 2018) | to build |

## What this means for the parkour mod

- Gravity is identical, so Mirror's Edge's wall run numbers carry over directly.
- Cyberpunk has no speed buildup and loses a lot of speed on slides and vaults. Mirror's Edge's flow (build speed, keep it through moves) needs a speed model on top.
- Cyberpunk's camera is calm. A Mirror's Edge feel adds roll and bob, above all the wall-run tilt.
