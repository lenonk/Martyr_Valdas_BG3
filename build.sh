#!/usr/bin/env bash
set -euo pipefail

MOD_NAME="MartyrValdas"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIST="$ROOT/dist"
OUTPUT="$DIST/$MOD_NAME.pak"
TEMP="$DIST/$MOD_NAME.pak.tmp"

mkdir -p "$DIST"
rm -f "$TEMP"

echo "==> Building $MOD_NAME"
echo "    Source: $ROOT"
echo "    Output: $OUTPUT"

# Only the mod's own tree: not these scripts, the docs or dist/.
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
cp -r "$ROOT/Mods" "$ROOT/Public" "$STAGE/"

# The .loca is generated from the .xml next to it, so edit only the .xml.
TOOL="$ROOT/tools/bg3tool/out/bg3tool.dll"
dotnet build -c Release -o "$ROOT/tools/bg3tool/out" "$ROOT/tools/bg3tool" > /dev/null
LOCA="$STAGE/Mods/$MOD_NAME/Localization/English/$MOD_NAME"
dotnet "$TOOL" loca "$LOCA.xml" "$LOCA.loca"

# Content banks (texture atlases and the like) are only read as LSF.
while IFS= read -r -d '' lsx; do
    dotnet "$TOOL" lsf "$lsx" "${lsx%.lsx}.lsf"
done < <(find "$STAGE/Public/$MOD_NAME/Content" -name '*.lsx' -print0)

# Effects (.lsfx) and MultiEffectInfos (.lsf) are kept as LSX here and shipped binary only.
while IFS= read -r -d '' lsx; do
    dotnet "$TOOL" convert "$lsx" "${lsx%.lsx}" && rm "$lsx"
done < <(find "$STAGE/Public/$MOD_NAME/Assets/Effects" -name '*.lsfx.lsx' -print0)
while IFS= read -r -d '' lsx; do
    dotnet "$TOOL" lsf "$lsx" "${lsx%.lsx}.lsf" && rm "$lsx"
done < <(find "$STAGE/Public/$MOD_NAME/MultiEffectInfos" -name '*.lsx' -print0)
# Root templates (the Snakestaff snake) likewise.
while IFS= read -r -d '' lsx; do
    dotnet "$TOOL" lsf "$lsx" "${lsx%.lsx}.lsf" && rm "$lsx"
done < <(find "$STAGE/Public/$MOD_NAME/RootTemplates" -name '*.lsx' -print0)

# Textures under Mods/<mod>/GUI need GUI/metadata.lsf, or the game reports missing texture metadata.
META="$STAGE/Mods/$MOD_NAME/GUI/metadata.lsx"
if [[ -f "$META" ]]; then
    dotnet "$TOOL" lsf "$META" "${META%.lsx}.lsf" && rm "$META"
fi

# Release-format (v18) package, from the same LSLib; Vortex's bundled divine.exe only writes v16.
dotnet "$TOOL" pack "$STAGE" "$TEMP"

[[ -f "$TEMP" ]] || {
    echo "ERROR: Build failed -- existing PAK untouched." >&2
    exit 1
}

mv -f "$TEMP" "$OUTPUT"

echo
echo "Build successful:"
ls -lh "$OUTPUT"
