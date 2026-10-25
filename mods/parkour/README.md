# parkour

Mirror's Edge style movement for Cyberpunk 2077 (CET Lua). Work in progress: first the wall run, tuned against our [Mirror's Edge captures](../../datasets/comparison.md).

Status: spikes done (2026-10-25). Per-frame impulses control V's vertical speed: a full per-frame correction overshoots and bobs (20–80 cm), gravity compensation (16 m/s² × Δt) plus damping holds V within 3 cm with no drift, wall raycasts find walls and their height, and the camera roll can be set (`FPPCameraComponent:SetLocalOrientation`). Cyberpunk picks the landing (and fall damage) from V's falling speed at impact, with gravity 16 m/s².

```sh
tools/build-mod.sh mods/parkour --install   # then "Reload all mods" in CET
```

Spike hotkeys (CET Bindings): "parkour spike: hover (hold)", "parkour spike: roll camera right (hold)", "… left (hold)". `dev-log` logs the mod's state (`parkour` field).
