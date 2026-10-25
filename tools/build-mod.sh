#!/usr/bin/env bash
# Build one of our mods into build/<mod>/<mod>.zip (mod.io folder layout), and optionally
# sideload it into the game.
#
#   build-mod.sh mods/<mod>               build
#   build-mod.sh mods/<mod> --install     build, then copy the archive files into the game's
#                                         archive/pc/mod/ and scripts into r6/scripts/
#                                         (safe while the game runs; restart to load)
#   build-mod.sh mods/<mod> --uninstall   remove the files --install put there
#
# Runs mods/<mod>/build.py (writes WolvenKit JSON and the loader files), converts the JSON
# to game files, checks each converts back to the same JSON, and packs the archive.
# Installed files are listed in build/installed/<mod>.txt, relative to the game dir.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MOD="$(cd "$1" && pwd)"
NAME="$(basename "$MOD")"
OUT="$ROOT/build/$NAME"
STEAM="${STEAM:-$HOME/.local/share/Steam/steamapps}"
GAME="$STEAM/common/Cyberpunk 2077"
MANIFEST="$ROOT/build/installed/$NAME.txt"

game_running() { pgrep -f '[C]yberpunk2077\.exe' >/dev/null; }

# A running game keeps reading the old file: replace by rename, never overwrite in place.
replace() {
    mkdir -p "$(dirname "$2")"
    cp "$1" "$2.tmp"
    mv -f "$2.tmp" "$2"
}

uninstall() {
    [[ -f $MANIFEST ]] || return 0
    while read -r f; do
        [[ $f == */* ]] || f="archive/pc/mod/$f"  # older manifests listed bare archive names
        rm -f "$GAME/$f"
        echo "removed $GAME/$f"
    done <"$MANIFEST"
    rm "$MANIFEST"
}

if [[ ${2:-} == --uninstall ]]; then
    uninstall
    exit 0
fi

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

if [[ -d $OUT/mod/r6/scripts ]]; then
    "$ROOT/tools/redscript-check.sh" "$OUT/mod/r6/scripts" >/dev/null \
        || { "$ROOT/tools/redscript-check.sh" "$OUT/mod/r6/scripts"; exit 1; }
fi

"$ROOT/tools/wk" pack "$RAW" -o "$OUT/mod/archive" -v Quiet
(cd "$OUT/mod" && zip -qr "../$NAME.zip" .)
echo "built $OUT/$NAME.zip"
(cd "$OUT/mod" && find . -type f | sort)

if [[ ${2:-} == --install ]]; then
    game_running && echo "note: the game is running; it may need a restart to load the change"
    mkdir -p "$(dirname "$MANIFEST")"
    old="$(cat "$MANIFEST" 2>/dev/null || true)"
    : >"$MANIFEST"
    while read -r rel; do
        case $rel in
            archive/*) dest="archive/pc/mod/${rel#archive/}" ;;
            r6/scripts/*) dest="$rel" ;;
            *) continue ;;  # about.json is for mod.io only
        esac
        replace "$OUT/mod/$rel" "$GAME/$dest"
        echo "$dest" >>"$MANIFEST"
        echo "installed $GAME/$dest"
    done < <(cd "$OUT/mod" && find . -type f -printf '%P\n' | sort)
    # files from an earlier install that this build no longer has
    for f in $old; do
        [[ $f == */* ]] || f="archive/pc/mod/$f"  # older manifests listed bare archive names
        grep -qxF "$f" "$MANIFEST" || { rm -f "$GAME/$f"; echo "removed $GAME/$f"; }
    done
fi
