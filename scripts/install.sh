#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${BUILD_DIR:-"$ROOT/build"}"
SOURCE_APP="$BUILD_DIR/ZMacTools.app"
DESTINATION_APP="${DESTINATION_APP:-/Applications/ZMacTools.app}"
EXTENSION_ID="com.zmactools.app.finder"

"$ROOT/scripts/build.sh"

echo "==> Installing to $DESTINATION_APP"
osascript -e 'tell application "ZMacTools" to quit' >/dev/null 2>&1 || true
pkill -x ZMacTools >/dev/null 2>&1 || true

if [[ -e "$DESTINATION_APP" ]]; then
    pluginkit -r "$DESTINATION_APP/Contents/PlugIns/ZMacToolsFinder.appex" >/dev/null 2>&1 || true
    rm -rf "$DESTINATION_APP"
fi

ditto "$SOURCE_APP" "$DESTINATION_APP"
xattr -dr com.apple.quarantine "$DESTINATION_APP" 2>/dev/null || true

echo "==> Registering Finder extension"
pluginkit -a "$DESTINATION_APP/Contents/PlugIns/ZMacToolsFinder.appex" >/dev/null 2>&1 || true

# Re-registering alone can leave the previous extension process alive, which
# makes Finder show two ZMacTools submenus until it is relaunched.
pkill -x ZMacToolsFinder >/dev/null 2>&1 || true
pluginkit -e use -i "$EXTENSION_ID" >/dev/null 2>&1 || true

open "$DESTINATION_APP"

echo
echo "Installed and launched: $DESTINATION_APP"
echo "If the menu is not visible yet, enable ZMacTools under:"
echo "  System Settings > General > Login Items & Extensions > Finder Extensions"

