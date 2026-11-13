#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE="$ROOT/assets/icon.svg"
ICONSET="$ROOT/build/AppIcon.iconset"
MASTER="$ROOT/build/AppIcon-1024.png"
OUTPUT="$ROOT/app/Resources/AppIcon.icns"

mkdir -p "$ICONSET" "$(dirname "$OUTPUT")"
rm -f "$ICONSET"/*.png

if command -v rsvg-convert >/dev/null 2>&1; then
    rsvg-convert --width 1024 --height 1024 "$SOURCE" --output "$MASTER"
else
    sips -s format png "$SOURCE" --out "$MASTER" >/dev/null
fi

make_size() {
    local size="$1"
    local name="$2"
    sips -z "$size" "$size" "$MASTER" --out "$ICONSET/$name" >/dev/null
}

make_size 16 icon_16x16.png
make_size 32 icon_16x16@2x.png
make_size 32 icon_32x32.png
make_size 64 icon_32x32@2x.png
make_size 128 icon_128x128.png
make_size 256 icon_128x128@2x.png
make_size 256 icon_256x256.png
make_size 512 icon_256x256@2x.png
make_size 512 icon_512x512.png
make_size 1024 icon_512x512@2x.png

iconutil --convert icns "$ICONSET" --output "$OUTPUT"
echo "Wrote $OUTPUT"

