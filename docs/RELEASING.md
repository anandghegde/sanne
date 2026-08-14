# Releasing Sanne

How to cut a versioned build, DMG, optional notarization, and GitHub Release notes.

## Prerequisites

| Item | Required for |
|------|----------------|
| macOS 13+, Swift 5.9+, Xcode CLT | All builds |
| Apple Developer Program | Developer ID sign + notarization |
| `Developer ID Application` cert in Keychain | Gatekeeper-friendly `.app` / DMG |
| App-specific password or notary keychain profile | `notarytool` |
| `gh` CLI + repo write access | Publishing a GitHub Release |

Local testers can use **ad-hoc** signed builds (default) and grant Accessibility manually.

## Version number

Single source of truth:

```text
VERSION          # marketing version, e.g. 0.1.0
```

Bump `VERSION` before packaging. Also update:

1. [CHANGELOG.md](../CHANGELOG.md) — move Unreleased notes under the new version
2. Tag `v$VERSION` when publishing

Build number is auto-generated (`YYYYMMDDHHMM`) unless you set `SANNE_BUILD`.

## Quick path (local DMG, ad-hoc sign)

```bash
# 1. Confirm version
cat VERSION

# 2. Build .app + DMG + checksum
./scripts/package-dmg.sh

# 3. Smoke-test
open dist/Sanne-$(cat VERSION).dmg
# Drag to Applications → open → Accessibility → Magic Mouse tap / titlebar swipe
```

Outputs:

| Path | Description |
|------|-------------|
| `dist/Sanne.app` | Menu bar app bundle |
| `dist/Sanne-<ver>.dmg` | Drag-to-Applications disk image |
| `dist/Sanne-<ver>.dmg.sha256` | SHA-256 checksum |

## Signed + notarized release

### 1. Sign with Developer ID

```bash
export SANNE_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"
./scripts/package-dmg.sh
```

`scripts/Sanne.entitlements` is applied automatically (hardened runtime; library validation relaxed for MultitouchSupport `dlopen`).

Verify:

```bash
codesign -dv --verbose=4 dist/Sanne.app
spctl -a -vv dist/Sanne.app   # may still fail until notarized
```

### 2. Notarize

One-time keychain profile (recommended):

```bash
xcrun notarytool store-credentials "sanne-notary" \
  --apple-id "you@example.com" \
  --team-id "TEAMID" \
  --password "app-specific-password"

export SANNE_NOTARY_PROFILE=sanne-notary
./scripts/notarize.sh dist/Sanne-$(cat VERSION).dmg
```

Or pass credentials via env (never commit these):

```bash
export APPLE_ID=...
export APPLE_TEAM_ID=...
export APPLE_APP_SPECIFIC_PASSWORD=...
./scripts/notarize.sh dist/Sanne-$(cat VERSION).dmg
```

Stapling is part of `notarize.sh`. Re-check:

```bash
spctl -a -vv -t open --context context:primary-signature dist/Sanne-$(cat VERSION).dmg
```

### 3. GitHub Release

Draft notes from the changelog section for this version.

```bash
VERSION=$(cat VERSION)
TAG="v${VERSION}"
DMG="dist/Sanne-${VERSION}.dmg"

# After git tag + push:
# git tag -a "$TAG" -m "Sanne $VERSION"
# git push origin "$TAG"

gh release create "$TAG" \
  "$DMG" \
  "${DMG}.sha256" \
  --title "Sanne $VERSION" \
  --notes-file "docs/releases/${VERSION}.md"
```

If `docs/releases/${VERSION}.md` does not exist yet, copy the matching section from [CHANGELOG.md](../CHANGELOG.md) into a new file under `docs/releases/`.

### 4. Homebrew

Cask sketch lives at [docs/homebrew/sanne.rb](./homebrew/sanne.rb). Publish to `homebrew-cask` once a public notarized DMG URL exists:

```bash
# Fill sha256 from dist/Sanne-<ver>.dmg.sha256, then:
brew tap homebrew/cask
# or submit a PR to Homebrew/homebrew-cask with that file
```

## Release checklist

- [ ] `VERSION` bumped; changelog entry complete
- [ ] `./scripts/package-dmg.sh` with `SANNE_SIGN_IDENTITY` set
- [ ] `./scripts/notarize.sh` succeeded; stapler validate OK
- [ ] Fresh machine / clean Accessibility grant smoke test
  - [ ] Magic Mouse left tap
  - [ ] Titlebar swipe snap
  - [ ] Settings open; remap still works
  - [ ] Launch at login (optional)
- [ ] Git tag `vX.Y.Z` + GitHub Release assets (DMG + sha256)
- [ ] Post-release: issue for next version; update README download link when public

## Scripts

| Script | Role |
|--------|------|
| [scripts/package-app.sh](../scripts/package-app.sh) | `swift build` → `dist/Sanne.app` + codesign |
| [scripts/package-dmg.sh](../scripts/package-dmg.sh) | App + UDZO DMG + checksum |
| [scripts/notarize.sh](../scripts/notarize.sh) | `notarytool submit` + staple |
| [scripts/Sanne.entitlements](../scripts/Sanne.entitlements) | Hardened runtime entitlements |

## Troubleshooting

**Accessibility doesn’t stick after update**  
Bundle id is `app.sanne.Sanne`. Prefer installing to `/Applications/Sanne.app` so the path is stable. Re-enable the checkbox after replace.

**“App is damaged” / can’t open**  
Unsigned or un-notarized build on stricter Gatekeeper. Right-click → Open once, or complete Developer ID + notarization.

**notarytool: Invalid credentials**  
Use an [app-specific password](https://support.apple.com/en-us/102654), not the Apple ID password. 2FA must be on.

**Multitouch / gestures die after notarized build**  
Confirm entitlements include library-validation relaxation (`com.apple.security.cs.disable-library-validation`) so private MultitouchSupport can load.
