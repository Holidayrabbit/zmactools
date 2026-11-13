#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${BUILD_DIR:-"$ROOT/build"}"
APP_BUNDLE="$BUILD_DIR/ZMacTools.app"
EXT_BUNDLE="$APP_BUNDLE/Contents/PlugIns/ZMacToolsFinder.appex"
SDK="$(xcrun --sdk macosx --show-sdk-path)"
MACOS_MIN_VERSION="14.0"

case "$(uname -m)" in
    arm64)
        HOST_ARCH="arm64"
        RUST_TARGET="aarch64-apple-darwin"
        ;;
    x86_64)
        HOST_ARCH="x86_64"
        RUST_TARGET="x86_64-apple-darwin"
        ;;
    *)
        echo "Unsupported Mac architecture: $(uname -m)" >&2
        exit 1
        ;;
esac

if ! rustup target list --installed | grep -qx "$RUST_TARGET"; then
    echo "Missing Rust target $RUST_TARGET. Run: rustup target add $RUST_TARGET" >&2
    exit 1
fi

if [[ ! -f "$ROOT/app/Resources/AppIcon.icns" || "$ROOT/assets/icon.svg" -nt "$ROOT/app/Resources/AppIcon.icns" ]]; then
    "$ROOT/scripts/make-icon.sh"
fi

echo "==> Testing Rust core"
cargo test --manifest-path "$ROOT/Cargo.toml" -p zmt-core

echo "==> Building Rust core ($RUST_TARGET)"
cargo build \
    --manifest-path "$ROOT/Cargo.toml" \
    -p zmt-core \
    --release \
    --target "$RUST_TARGET"

RUST_LIBRARY="$ROOT/target/$RUST_TARGET/release/libzmt_core.a"

rm -rf "$APP_BUNDLE"
mkdir -p \
    "$APP_BUNDLE/Contents/MacOS" \
    "$APP_BUNDLE/Contents/Resources" \
    "$EXT_BUNDLE/Contents/MacOS"

cp "$ROOT/app/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
cp "$ROOT/app/Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
cp "$ROOT/extension/Info.plist" "$EXT_BUNDLE/Contents/Info.plist"

echo "==> Compiling Finder extension"
xcrun swiftc \
    -parse-as-library \
    -application-extension \
    -O \
    -whole-module-optimization \
    -target "$HOST_ARCH-apple-macosx$MACOS_MIN_VERSION" \
    -sdk "$SDK" \
    -module-name ZMacToolsFinder \
    -import-objc-header "$ROOT/extension/Sources/BridgingHeader.h" \
    -I "$ROOT/crates/zmt-core/include" \
    -framework Cocoa \
    -framework FinderSync \
    -Xlinker -e \
    -Xlinker _NSExtensionMain \
    "$ROOT"/extension/Sources/*.swift \
    "$RUST_LIBRARY" \
    -o "$EXT_BUNDLE/Contents/MacOS/ZMacToolsFinder"

echo "==> Compiling host app"
xcrun swiftc \
    -parse-as-library \
    -O \
    -whole-module-optimization \
    -target "$HOST_ARCH-apple-macosx$MACOS_MIN_VERSION" \
    -sdk "$SDK" \
    -module-name ZMacTools \
    -framework AppKit \
    -framework FinderSync \
    -framework SwiftUI \
    "$ROOT"/app/Sources/*.swift \
    -o "$APP_BUNDLE/Contents/MacOS/ZMacTools"

plutil -lint "$APP_BUNDLE/Contents/Info.plist" >/dev/null
plutil -lint "$EXT_BUNDLE/Contents/Info.plist" >/dev/null

SIGNING_IDENTITY="${SIGNING_IDENTITY:--}"
if [[ "$SIGNING_IDENTITY" == "-" ]]; then
    echo "==> Signing ad hoc (local development)"
    codesign --force --sign - \
        --entitlements "$ROOT/extension/Finder.entitlements" \
        "$EXT_BUNDLE"
    codesign --force --sign - "$APP_BUNDLE"
else
    echo "==> Signing with $SIGNING_IDENTITY"
    codesign --force --options runtime --timestamp \
        --entitlements "$ROOT/extension/Finder.entitlements" \
        --sign "$SIGNING_IDENTITY" \
        "$EXT_BUNDLE"
    codesign --force --options runtime --timestamp \
        --sign "$SIGNING_IDENTITY" \
        "$APP_BUNDLE"
fi

codesign --verify --strict --deep "$APP_BUNDLE"

echo
echo "Built: $APP_BUNDLE"

