# dev-log

Development helper (needs [CET](../../thirdparty/README.md)). A few times per second, writes V's position, velocity, speed, facing and locomotion state as one JSON object per line to `bin/x64/plugins/cyber_engine_tweaks/mods/dev_log/dev_log.jsonl` in the game dir, so the data can be read while playing. The file starts fresh when the game starts or CET reloads mods. Registered with dev-status.

```sh
tools/build-mod.sh mods/dev-log --install
```
