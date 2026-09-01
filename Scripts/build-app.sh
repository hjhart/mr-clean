#!/usr/bin/env bash
# Builds Mr Clean.app into dist/. Pass --install to also copy it to /Applications.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

APP_NAME="Mr Clean"
BUNDLE="dist/${APP_NAME}.app"
CONFIG=release

echo "==> Building (${CONFIG})"
swift build -c "$CONFIG" --disable-sandbox

echo "==> Assembling ${BUNDLE}"
rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"
cp "$(swift build -c "$CONFIG" --show-bin-path)/MrClean" "$BUNDLE/Contents/MacOS/MrClean"
cp Resources/Info.plist "$BUNDLE/Contents/Info.plist"
printf 'APPL????' > "$BUNDLE/Contents/PkgInfo"

echo "==> Rendering icon"
ICONSET="$(mktemp -d)/AppIcon.iconset"
if swift Scripts/make-icon.swift "$ICONSET" >/dev/null 2>&1 \
  && iconutil -c icns "$ICONSET" -o "$BUNDLE/Contents/Resources/AppIcon.icns" >/dev/null 2>&1; then
  echo "    icon ok"
else
  echo "    icon generation failed; using the default app icon"
  /usr/libexec/PlistBuddy -c "Delete :CFBundleIconFile" "$BUNDLE/Contents/Info.plist" >/dev/null 2>&1 || true
fi

echo "==> Signing (ad-hoc)"
codesign --force --deep --sign - "$BUNDLE"

if [[ "${1:-}" == "--install" ]]; then
  echo "==> Installing to /Applications"
  # Quit any copy that's already running so the replace succeeds.
  osascript -e 'quit app "Mr Clean"' >/dev/null 2>&1 || true
  rm -rf "/Applications/${APP_NAME}.app"
  cp -R "$BUNDLE" "/Applications/${APP_NAME}.app"
  echo "==> Launching"
  open "/Applications/${APP_NAME}.app"
fi

echo "Done: $BUNDLE"
