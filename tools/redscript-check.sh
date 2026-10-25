#!/usr/bin/env bash
# Compile redscript sources offline, the way the game will at launch, and report errors.
#
#   redscript-check.sh [src ...]     default: the game's r6/scripts
#
# Uses redscript-cli under Proton's Wine (own prefix in ~/.local/opt/redscript), against the
# game's unmodified script bundle (final.redscripts.bk once redscript has run, else final).
set -euo pipefail
VERSION=v0.5.32  # same as tools/install-redscript.sh
SHA256=c8665c40199fb784a78b980db3a304a7f0b14a9494b3b59a125ff5618bf13f6c
STEAM="${STEAM:-$HOME/.local/share/Steam/steamapps}"
GAME="$STEAM/common/Cyberpunk 2077"
WINE="$STEAM/common/Proton - Experimental/files/bin/wine"
DIR="$HOME/.local/opt/redscript/$VERSION"
CLI="$DIR/redscript-cli.exe"
export WINEPREFIX="$HOME/.local/opt/redscript/wineprefix" WINEDEBUG=-all

if [[ ! -f $CLI ]]; then
    mkdir -p "$DIR"
    curl -fsSL -o "$CLI.tmp" \
        "https://github.com/jac3km4/redscript/releases/download/$VERSION/redscript-cli.exe"
    echo "$SHA256  $CLI.tmp" | sha256sum -c --quiet
    mv "$CLI.tmp" "$CLI"
fi

bundle="$GAME/r6/cache/final.redscripts.bk"
[[ -f $bundle ]] || bundle="$GAME/r6/cache/final.redscripts"
srcs=()
for s in "${@:-$GAME/r6/scripts}"; do srcs+=(-s "Z:$(realpath "$s")"); done
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
"$WINE" "$CLI" compile "${srcs[@]}" -b "Z:$bundle" -o "Z:$tmp/out.redscripts" 2>&1 \
    | grep -v '^wineserver:'
[[ -f $tmp/out.redscripts ]]  # no output file: compilation failed
