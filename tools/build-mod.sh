#!/usr/bin/env bash
# Build one of our mods into build/<mod>/<mod>.zip (mod.io folder layout).
#
#   build-mod.sh mods/<mod>
#
# Runs mods/<mod>/build.py (writes WolvenKit JSON and the loader files), converts the JSON
# to game files, checks each converts back to the same JSON, and packs the archive.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MOD="$(cd "$1" && pwd)"
NAME="$(basename "$MOD")"
OUT="$ROOT/build/$NAME"

rm -rf "$OUT"
uv run --project "$ROOT" python "$MOD/build.py" "$OUT"

xl=("$OUT"/mod/archive/*.archive.xl)
ARCHIVE="$(basename "${xl[0]}" .archive.xl)"
RAW="$OUT/$ARCHIVE"  # pack names the archive after this folder

# WolvenKit writes converted files flat, so convert one folder at a time.
find "$OUT/json" -name '*.json' -printf '%P\n' | sort | while read -r rel; do
    res="${rel%.json}"
    dir="$(dirname "$res")"
    mkdir -p "$RAW/$dir" "$OUT/check/$dir"
    "$ROOT/tools/wk" convert deserialize "$OUT/json/$rel" -o "$RAW/$dir" -v Quiet
    "$ROOT/tools/wk" convert serialize "$RAW/$res" -o "$OUT/check/$dir" -v Quiet
    uv run --project "$ROOT" python "$ROOT/tools/wkjson.py" same \
        "$OUT/json/$rel" "$OUT/check/$rel" || { echo "round trip changed $res" >&2; exit 1; }
done

"$ROOT/tools/wk" pack "$RAW" -o "$OUT/mod/archive" -v Quiet
(cd "$OUT/mod" && zip -qr "../$NAME.zip" .)
echo "built $OUT/$NAME.zip"
(cd "$OUT/mod" && find . -type f | sort)
