#!/bin/bash
# Regenerate the app icon PNGs, asset catalog images, and AppIcon.icns.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SVG="$ROOT/NewFileCreation2App/Design/AppIcon.svg"
ICONSET="$ROOT/NewFileCreation2App/Assets.xcassets/AppIcon.appiconset"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/nfc-icon.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

if [ ! -f "$SVG" ]; then
    echo "Missing icon source: $SVG" >&2
    exit 1
fi

mkdir -p "$TMP/render" "$TMP/AppIcon.iconset"
if command -v rsvg-convert >/dev/null 2>&1; then
    rsvg-convert -w 1024 -h 1024 "$SVG" -o "$TMP/render/AppIcon.png"
else
    qlmanage -t -s 1024 -o "$TMP/render" "$SVG" >/dev/null 2>&1
fi

RENDERED="$TMP/render/AppIcon.png"
if [ ! -f "$RENDERED" ]; then
    RENDERED="$TMP/render/$(basename "$SVG").png"
fi
if [ ! -f "$RENDERED" ]; then
    echo "Could not render $SVG with rsvg-convert or qlmanage." >&2
    exit 1
fi

sips -s format png "$RENDERED" --out "$TMP/master.png" >/dev/null

sizes=(16 32 128 256 512)
for size in "${sizes[@]}"; do
    sips -z "$size" "$size" "$TMP/master.png" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
    double=$((size * 2))
    sips -z "$double" "$double" "$TMP/master.png" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
cp "$ICONSET"/icon_*.png "$TMP/AppIcon.iconset/"
iconutil -c icns "$TMP/AppIcon.iconset" -o "$ROOT/NewFileCreation2App/Design/AppIcon.icns"

echo "Generated app icon:"
ls -1 "$ICONSET" | sed 's/^/  /'
echo "Generated $ROOT/NewFileCreation2App/Design/AppIcon.icns"
