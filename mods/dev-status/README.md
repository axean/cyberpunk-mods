# dev-status

Development helper, sideload only (needs redscript: `tools/install-redscript.sh`). A few seconds after every save load, V gets a text from an unknown number for each of our dev mods that is installed, in one thread "dev mods", with its build time and commit (`+` = uncommitted changes).

A mod registers by adding its message to the conversation `contacts/unknown/devstatus` in its own journal:

```python
chat, texts = devstatus.register("my-mod", f"my-mod loaded, {devstatus.stamp(HERE)}")
# put `chat` in the journal folder "contacts/unknown", add `texts` to the mod's onscreens
```

```sh
tools/build-mod.sh mods/dev-status --install
```
