#!/usr/bin/env bash
# Build Sanne.app (if needed) and wrap it in a distributable DMG.
#
# Usage:
#   ./scripts/package-dmg.sh           # release app + DMG
#   ./scripts/package-dmg.sh --skip-app  # use existing dist/Sanne.app
#
# Output:
#   dist/Sanne-<version>.dmg
#   dist/Sanne-<version>.sha256
#
# Env: same as package-app.sh (SANNE_VERSION, SANNE_SIGN_IDENTITY, …)
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SKIP_APP=0
if [[ "${1:-}" == "--skip-app" ]]; then
  SKIP_APP=1
fi

if [[ "$SKIP_APP" -eq 0 ]]; then
  "$ROOT/scripts/package-app.sh"
else
  if [[ ! -d "$ROOT/dist/Sanne.app" ]]; then
    echo "error: dist/Sanne.app missing — run without --skip-app" >&2
    exit 1
  fi
fi

if [[ -f "$ROOT/dist/.version" ]]; then
  VERSION="$(tr -d '[:space:]' < "$ROOT/dist/.version")"
elif [[ -f "$ROOT/VERSION" ]]; then
  VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION")"
else
  VERSION="0.1.0"
fi

DIST="$ROOT/dist"
APP="$DIST/Sanne.app"
DMG_NAME="Sanne-${VERSION}.dmg"
DMG_PATH="$DIST/$DMG_NAME"
STAGE="$DIST/dmg-stage"

echo "→ staging DMG contents"
rm -rf "$STAGE"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/Sanne.app"
ln -sf /Applications "$STAGE/Applications"

# First-run note on the volume
cat > "$STAGE/Read Me.txt" <<EOF
Sanne ${VERSION}
===============

Install
  1. Drag Sanne into Applications
  2. Open Sanne from Applications (first launch may need right-click → Open if not notarized)
  3. Enable Accessibility for Sanne:
     System Settings → Privacy & Security → Accessibility

Uninstall
  Quit Sanne (menu bar → Quit), then delete Sanne from Applications.
  Optional: remove ~/Library/Application Support/Sanne and ~/Library/Logs/Sanne

License: MIT — see the project repository.
EOF

# Prefer UDZO (zlib-compressed) for smaller downloads.
echo "→ creating $DMG_NAME"
rm -f "$DMG_PATH"
hdiutil create \
  -volname "Sanne ${VERSION}" \
  -srcfolder "$STAGE" \
  -ov \
  -format UDZO \
  -imagekey zlib-level=9 \
  "$DMG_PATH"

rm -rf "$STAGE"

# Checksums
if command -v shasum >/dev/null 2>&1; then
  (cd "$DIST" && shasum -a 256 "$DMG_NAME" | tee "${DMG_NAME}.sha256")
elif command -v sha256sum >/dev/null 2>&1; then
  (cd "$DIST" && sha256sum "$DMG_NAME" | tee "${DMG_NAME}.sha256")
fi

# Size hint
if command -v du >/dev/null 2>&1; then
  echo "→ size: $(du -h "$DMG_PATH" | awk '{print $1}')"
fi

echo ""
echo "DMG: $DMG_PATH"
echo "Next (optional notarization): ./scripts/notarize.sh \"$DMG_PATH\""
echo "See docs/RELEASING.md for the full release checklist."
