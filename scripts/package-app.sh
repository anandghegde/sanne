#!/usr/bin/env bash
# Build a Sanne.app bundle for stable Accessibility / login-item identity.
#
# Usage:
#   ./scripts/package-app.sh [--debug]
#
# Env:
#   SANNE_VERSION       Override marketing version (default: VERSION file or 0.1.0)
#   SANNE_SIGN_IDENTITY codesign identity. Empty → ad-hoc (-).
#                       Example: "Developer ID Application: Your Name (TEAMID)"
#   SANNE_ENTITLEMENTS  Optional path to .entitlements (hardened runtime for notarization)
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

CONFIG="release"
if [[ "${1:-}" == "--debug" ]]; then
  CONFIG="debug"
fi

VERSION_FILE="$ROOT/VERSION"
if [[ -n "${SANNE_VERSION:-}" ]]; then
  VERSION="$SANNE_VERSION"
elif [[ -f "$VERSION_FILE" ]]; then
  VERSION="$(tr -d '[:space:]' < "$VERSION_FILE")"
else
  VERSION="0.1.0"
fi
BUILD="${SANNE_BUILD:-$(date +%Y%m%d%H%M)}"
SIGN_IDENTITY="${SANNE_SIGN_IDENTITY:-}"

echo "→ version $VERSION (build $BUILD)"
echo "→ swift build -c $CONFIG"
swift build -c "$CONFIG"

BIN="$ROOT/.build/$CONFIG/Sanne"
if [[ ! -x "$BIN" ]]; then
  # SPM may place binary under a triple directory on some toolchains.
  ALT="$(find "$ROOT/.build" -path "*/$CONFIG/Sanne" -type f -perm -111 2>/dev/null | head -1 || true)"
  if [[ -n "$ALT" && -x "$ALT" ]]; then
    BIN="$ALT"
  else
    echo "error: binary not found at $BIN" >&2
    exit 1
  fi
fi

DIST="$ROOT/dist"
APP="$DIST/Sanne.app"
CONTENTS="$APP/Contents"
MACOS="$CONTENTS/MacOS"
RES="$CONTENTS/Resources"

rm -rf "$APP"
mkdir -p "$MACOS" "$RES"

cp "$BIN" "$MACOS/Sanne"
chmod +x "$MACOS/Sanne"

# SPM resource bundle (preset JSON, etc.)
BUNDLE_SRC=""
for candidate in \
  "$ROOT/.build/$CONFIG/Sanne_Sanne.bundle" \
  "$ROOT/.build"/*/"$CONFIG/Sanne_Sanne.bundle"
do
  if [[ -d "$candidate" ]]; then
    BUNDLE_SRC="$candidate"
    break
  fi
done
if [[ -n "$BUNDLE_SRC" ]]; then
  cp -R "$BUNDLE_SRC" "$RES/"
  echo "→ copied resource bundle from $BUNDLE_SRC"
else
  echo "warn: Sanne_Sanne.bundle not found — preset JSON may be missing" >&2
fi

# Minimal DMG-friendly README inside Resources (also useful for support).
cat > "$RES/README.txt" <<EOF
Sanne ${VERSION}
Free & open source gestures for Magic Mouse and trackpad (MIT).

1. Drag Sanne to Applications (if installed from DMG).
2. Open Sanne.
3. Grant Accessibility: System Settings → Privacy & Security → Accessibility.
4. Menu bar icon → Settings for gestures and remaps.

Config: ~/Library/Application Support/Sanne/config.json
Logs:   ~/Library/Logs/Sanne/sanne.log

https://github.com/sanne-app/sanne
EOF

cat > "$CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>en</string>
	<key>CFBundleExecutable</key>
	<string>Sanne</string>
	<key>CFBundleIdentifier</key>
	<string>app.sanne.Sanne</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>Sanne</string>
	<key>CFBundleDisplayName</key>
	<string>Sanne</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>${VERSION}</string>
	<key>CFBundleVersion</key>
	<string>${BUILD}</string>
	<key>LSMinimumSystemVersion</key>
	<string>13.0</string>
	<key>LSUIElement</key>
	<true/>
	<key>NSHighResolutionCapable</key>
	<true/>
	<key>NSHumanReadableCopyright</key>
	<string>MIT License</string>
</dict>
</plist>
PLIST

echo -n "APPL????" > "$CONTENTS/PkgInfo"

# --- Codesign ---
if ! command -v codesign >/dev/null 2>&1; then
  echo "warn: codesign not available" >&2
elif [[ -n "$SIGN_IDENTITY" ]]; then
  ENTITLEMENTS_ARGS=()
  if [[ -n "${SANNE_ENTITLEMENTS:-}" && -f "$SANNE_ENTITLEMENTS" ]]; then
    ENTITLEMENTS_ARGS=(--entitlements "$SANNE_ENTITLEMENTS")
  elif [[ -f "$ROOT/scripts/Sanne.entitlements" ]]; then
    ENTITLEMENTS_ARGS=(--entitlements "$ROOT/scripts/Sanne.entitlements")
  fi
  echo "→ codesign with identity: $SIGN_IDENTITY"
  codesign --force --deep --options runtime --timestamp \
    "${ENTITLEMENTS_ARGS[@]}" \
    --sign "$SIGN_IDENTITY" \
    "$APP"
  codesign --verify --verbose=2 "$APP"
else
  codesign --force --deep --sign - "$APP" 2>/dev/null || true
  echo "→ ad-hoc codesign (set SANNE_SIGN_IDENTITY for Developer ID)"
fi

# Export version for other scripts
echo "$VERSION" > "$DIST/.version"
echo "$BUILD" > "$DIST/.build"

echo ""
echo "Built: $APP"
echo "Version: $VERSION ($BUILD)"
echo "Run:   open \"$APP\""
echo ""
echo "Grant Accessibility to Sanne (bundle id app.sanne.Sanne)."
echo "Launch at login works from this .app (Settings → General)."
echo "Next: ./scripts/package-dmg.sh"
