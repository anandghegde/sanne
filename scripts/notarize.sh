#!/usr/bin/env bash
# Submit a signed DMG (or .app) to Apple notary service and staple the ticket.
#
# Prerequisites:
#   - Apple Developer Program membership
#   - App signed with Developer ID Application (see SANNE_SIGN_IDENTITY)
#   - notarytool credentials (keychain profile recommended)
#
# Usage:
#   ./scripts/notarize.sh dist/Sanne-0.1.0.dmg
#
# Auth (pick one):
#   A) Keychain profile (recommended):
#        xcrun notarytool store-credentials "sanne-notary" \
#          --apple-id "you@example.com" --team-id "TEAMID" --password "app-specific-password"
#        export SANNE_NOTARY_PROFILE=sanne-notary
#
#   B) Env vars each run:
#        export APPLE_ID=you@example.com
#        export APPLE_TEAM_ID=TEAMID
#        export APPLE_APP_SPECIFIC_PASSWORD=xxxx-xxxx-xxxx-xxxx
#
# Never commit credentials. This script only reads env / keychain profile names.
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

TARGET="${1:-}"
if [[ -z "$TARGET" ]]; then
  # Prefer latest versioned DMG in dist/
  if [[ -f "$ROOT/dist/.version" ]]; then
    V="$(tr -d '[:space:]' < "$ROOT/dist/.version")"
    TARGET="$ROOT/dist/Sanne-${V}.dmg"
  fi
fi

if [[ -z "$TARGET" || ! -e "$TARGET" ]]; then
  echo "usage: $0 path/to/Sanne-x.y.z.dmg" >&2
  echo "No target found. Build first: ./scripts/package-dmg.sh" >&2
  exit 1
fi

TARGET="$(cd "$(dirname "$TARGET")" && pwd)/$(basename "$TARGET")"
echo "→ notarizing $TARGET"

if ! command -v xcrun >/dev/null 2>&1; then
  echo "error: xcrun / Xcode CLT required" >&2
  exit 1
fi

AUTH_ARGS=()
if [[ -n "${SANNE_NOTARY_PROFILE:-}" ]]; then
  AUTH_ARGS=(--keychain-profile "$SANNE_NOTARY_PROFILE")
  echo "→ auth: keychain profile $SANNE_NOTARY_PROFILE"
elif [[ -n "${APPLE_ID:-}" && -n "${APPLE_TEAM_ID:-}" && -n "${APPLE_APP_SPECIFIC_PASSWORD:-}" ]]; then
  AUTH_ARGS=(
    --apple-id "$APPLE_ID"
    --team-id "$APPLE_TEAM_ID"
    --password "$APPLE_APP_SPECIFIC_PASSWORD"
  )
  echo "→ auth: APPLE_ID / APPLE_TEAM_ID env"
else
  cat >&2 <<'EOF'
error: no notary credentials configured.

Set one of:
  SANNE_NOTARY_PROFILE=sanne-notary
or
  APPLE_ID + APPLE_TEAM_ID + APPLE_APP_SPECIFIC_PASSWORD

See docs/RELEASING.md
EOF
  exit 1
fi

echo "→ notarytool submit (wait)…"
xcrun notarytool submit "$TARGET" "${AUTH_ARGS[@]}" --wait

echo "→ stapler staple"
xcrun stapler staple "$TARGET"
xcrun stapler validate "$TARGET"

# If we stapled a DMG that contains an app, optionally staple the .app too when present.
APP_CANDIDATE="$ROOT/dist/Sanne.app"
if [[ -d "$APP_CANDIDATE" ]]; then
  echo "→ also staple dist/Sanne.app (if ticket applies)"
  xcrun stapler staple "$APP_CANDIDATE" 2>/dev/null || true
fi

echo ""
echo "Notarized & stapled: $TARGET"
echo "Users can open without right-click bypass (once Apple propagates)."
