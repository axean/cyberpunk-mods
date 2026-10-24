#!/usr/bin/env bash
# Snapshot the Cyberpunk 2077 game dir and Proton prefix, and diff two snapshots.
#
#   snap.sh take <name>        record file list (path, size, mtime)
#   snap.sh diff <old> <new>   show ADDED / REMOVED / CHANGED files
#   snap.sh list
#
# mod.io thumbnail cache is hidden from diffs unless SNAP_SHOW_CACHE=1.
set -euo pipefail
export LC_ALL=C  # sort and join must agree on collation

STEAM="${STEAM:-$HOME/.local/share/Steam/steamapps}"
GAME="$STEAM/common/Cyberpunk 2077"
PREFIX="$STEAM/compatdata/1091500"
DIR="${SNAP_DIR:-$(cd "$(dirname "$0")/.." && pwd)/snapshots}"

listing() { find "$1" -printf '%P\t%s\t%T@\n' 2>/dev/null | sort; }

take() {
    mkdir -p "$DIR/$1"
    listing "$GAME" >"$DIR/$1/game.tsv"
    listing "$PREFIX" >"$DIR/$1/prefix.tsv"
    wc -l "$DIR/$1"/*.tsv
}

diff_one() {
    join -t $'\t' -a1 -a2 -e MISSING -o 0,1.2,1.3,2.2,2.3 "$1" "$2" |
        awk -F'\t' -v show="${SNAP_SHOW_CACHE:-0}" '
            !show && $1 ~ /mod\.io\/[0-9]+\/cache\// { next }
            $2 == "MISSING" { print "ADDED  \t" $1 "\t" $4 " B"; next }
            $4 == "MISSING" { print "REMOVED\t" $1; next }
            $2 != $4 || $3 != $5 { print "CHANGED\t" $1 "\t" $2 " -> " $4 " B" }'
}

case "${1:-}" in
take) take "${2:?name}" ;;
diff)
    for part in game prefix; do
        echo "=== $part ==="
        diff_one "$DIR/${2:?old}/$part.tsv" "$DIR/${3:?new}/$part.tsv"
    done
    ;;
list) ls -1 "$DIR" ;;
*) sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac
