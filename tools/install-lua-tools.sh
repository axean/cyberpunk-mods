#!/usr/bin/env bash
# Install the pinned Lua checkers (selene, lua-language-server) under ~/.local/opt.
# StyLua comes through pre-commit itself. Wrappers: tools/selene, tools/luals.
set -euo pipefail
SELENE=0.32.0
SELENE_SHA256=d3773393578580074386e69337d35b7acddfbaa9fc38964c07fa3e28436ade9b
LUALS=3.19.2
LUALS_SHA256=93ad326b10f6c00911dd8c450fa098332dbd8f9f45d1052f5636a2d54479b947
OPT=$HOME/.local/opt

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

if [[ ! -x $OPT/selene/$SELENE/selene ]]; then
    zip=selene-$SELENE-linux.zip
    curl -fsSL -o "$tmp/$zip" "https://github.com/Kampfkarren/selene/releases/download/$SELENE/$zip"
    echo "$SELENE_SHA256  $tmp/$zip" | sha256sum -c --quiet
    mkdir -p "$OPT/selene/$SELENE"
    unzip -q -o "$tmp/$zip" -d "$OPT/selene/$SELENE"
    chmod +x "$OPT/selene/$SELENE/selene"
fi

if [[ ! -x $OPT/lua-language-server/$LUALS/bin/lua-language-server ]]; then
    tgz=lua-language-server-$LUALS-linux-x64.tar.gz
    curl -fsSL -o "$tmp/$tgz" \
        "https://github.com/LuaLS/lua-language-server/releases/download/$LUALS/$tgz"
    echo "$LUALS_SHA256  $tmp/$tgz" | sha256sum -c --quiet
    mkdir -p "$OPT/lua-language-server/$LUALS"
    tar xzf "$tmp/$tgz" -C "$OPT/lua-language-server/$LUALS"
fi

"$OPT/selene/$SELENE/selene" --version
"$OPT/lua-language-server/$LUALS/bin/lua-language-server" --version
