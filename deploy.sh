#!/usr/bin/env bash
set -euo pipefail

MOD_NAME="MartyrValdas"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT="$ROOT/dist/$MOD_NAME.pak"

if [[ -z "${BG3_MODS+x}" ]]; then
    BG3_MODS="$HOME/.local/share/Larian Studios/Baldur's Gate 3/Mods"
fi

"$ROOT/build.sh"

mkdir -p "$BG3_MODS"

echo "==> Deploying $MOD_NAME"
cp -f "$OUTPUT" "$BG3_MODS/$MOD_NAME.pak"

echo
echo "Build/deploy successful:"
ls -lh "$OUTPUT" "$BG3_MODS/$MOD_NAME.pak"
