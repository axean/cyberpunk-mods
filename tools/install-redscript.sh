#!/usr/bin/env bash
# Install the pinned redscript compiler into the game dir (Proton/Steam).
#
#   install-redscript.sh              install
#   install-redscript.sh --uninstall  remove it again
#
# The game runs engine/tools/scc.exe at launch, which compiles r6/scripts/**/*.reds into
# the script blob. PC only; for development and sideloaded script mods.
set -euo pipefail
VERSION=v0.5.32  # first release supporting game patch 2.5
SHA256=882c57a80b07e453bc8a34cd8430f460aceed789581de8743638e19dcfb7936f
ZIP=redscript-$VERSION-windows.zip
STEAM="${STEAM:-$HOME/.local/share/Steam/steamapps}"
GAME="$STEAM/common/Cyberpunk 2077"
FILES=(engine/config/base/scripts.ini engine/tools/scc.exe engine/tools/scc_lib.dll
    r6/config/cybercmd/scc.toml)

if [[ ${1:-} == --uninstall ]]; then
    for f in "${FILES[@]}"; do rm -f "$GAME/$f"; done
    "$(dirname "$0")/thirdparty.sh" unannounce redscript
    echo "removed redscript; compiled mods in r6/cache stay until Steam verifies the game files"
    exit 0
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
curl -fsSL -o "$tmp/$ZIP" "https://github.com/jac3km4/redscript/releases/download/$VERSION/$ZIP"
echo "$SHA256  $tmp/$ZIP" | sha256sum -c --quiet
unzip -q -o "$tmp/$ZIP" "${FILES[@]}" -d "$GAME"
echo "installed redscript $VERSION into $GAME"
"$(dirname "$0")/thirdparty.sh" announce redscript "redscript $VERSION (compiler) installed"
