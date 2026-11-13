#!/usr/bin/env bash
set -euo pipefail

DESTINATION_APP="${DESTINATION_APP:-/Applications/ZMacTools.app}"
EXTENSION_ID="com.zmactools.app.finder"

osascript -e 'tell application "ZMacTools" to quit' >/dev/null 2>&1 || true
pkill -x ZMacTools >/dev/null 2>&1 || true

pluginkit -e default -i "$EXTENSION_ID" >/dev/null 2>&1 || true
pluginkit -r "$DESTINATION_APP/Contents/PlugIns/ZMacToolsFinder.appex" >/dev/null 2>&1 || true
pkill -x ZMacToolsFinder >/dev/null 2>&1 || true
rm -rf "$DESTINATION_APP"

echo "Removed $DESTINATION_APP"

