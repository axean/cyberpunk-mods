#!/usr/bin/env bash
# Install the pinned WolvenKit Linux CLI and a user-local .NET 10 runtime under ~/.local/opt.
set -euo pipefail
VERSION=10.0.0-beta.1
SHA256=561ff1387cb09e529c40a115cb55e12be0215653415dd2c6131c9c3f320f07d4  # from the GitHub release
ZIP=WolvenKit.ConsoleLinux-$VERSION.zip
DEST=$HOME/.local/opt/wolvenkit/$VERSION
DOTNET=$HOME/.local/opt/dotnet

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

if [[ ! -x $DEST/WolvenKit.CLI ]]; then
    curl -fsSL -o "$tmp/$ZIP" "https://github.com/WolvenKit/WolvenKit/releases/download/$VERSION/$ZIP"
    echo "$SHA256  $tmp/$ZIP" | sha256sum -c --quiet
    mkdir -p "$DEST"
    unzip -q -o "$tmp/$ZIP" -d "$DEST"
    chmod +x "$DEST/WolvenKit.CLI"
fi

if ! "$DOTNET/dotnet" --list-runtimes 2>/dev/null | grep -q '^Microsoft.NETCore.App 10\.'; then
    curl -fsSL -o "$tmp/dotnet-install.sh" https://dot.net/v1/dotnet-install.sh
    bash "$tmp/dotnet-install.sh" --channel 10.0 --runtime dotnet --install-dir "$DOTNET" --no-path
fi

DOTNET_ROOT=$DOTNET "$DEST/WolvenKit.CLI" --version
