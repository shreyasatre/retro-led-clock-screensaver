#!/bin/bash
# Builds "Retro LED Clock.saver" and installs it to ~/Library/Screen Savers.
# Requires Apple's Command Line Tools (the script offers to install them).
set -euo pipefail
cd "$(dirname "$0")"

NAME="RetroLEDClock"
SAVER="Retro LED Clock.saver"
BUILD="build"
BUNDLE="$BUILD/$SAVER"
DEPLOY="26.0"

if ! xcrun --find swiftc >/dev/null 2>&1; then
  echo "Swift compiler not found. Installing Apple Command Line Tools…"
  xcode-select --install || true
  echo "Re-run this script after the Command Line Tools finish installing."
  exit 1
fi

echo "→ Building…"
rm -rf "$BUILD"
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"
cp Info.plist "$BUNDLE/Contents/Info.plist"

SLICES=()
for ARCH in arm64 x86_64; do
  OUT="$BUILD/$NAME-$ARCH"
  if xcrun --sdk macosx swiftc -O \
      -target "$ARCH-apple-macos$DEPLOY" \
      -module-name "$NAME" -emit-library \
      -framework ScreenSaver -framework AppKit -framework QuartzCore \
      Sources/*.swift -o "$OUT"; then
    SLICES+=("$OUT")
  else
    echo "   (skipping $ARCH slice)"
  fi
done
[ ${#SLICES[@]} -gt 0 ] || { echo "Build failed."; exit 1; }
lipo -create "${SLICES[@]}" -output "$BUNDLE/Contents/MacOS/$NAME"

echo "→ Signing (ad-hoc)…"
codesign --force --deep --sign - "$BUNDLE"

echo "→ Installing to ~/Library/Screen Savers…"
DEST="$HOME/Library/Screen Savers"
mkdir -p "$DEST"
rm -rf "$DEST/$SAVER"
cp -R "$BUNDLE" "$DEST/"
xattr -cr "$DEST/$SAVER" 2>/dev/null || true

# Make macOS reload the new version
killall legacyScreenSaver 2>/dev/null || true
killall "legacyScreenSaver (Wallpaper)" 2>/dev/null || true

echo "✓ Installed: $DEST/$SAVER"
echo "  Open System Settings → Screen Saver and pick “Retro LED Clock” (under Other)."
open "x-apple.systempreferences:com.apple.ScreenSaver-Settings.extension" 2>/dev/null || true
