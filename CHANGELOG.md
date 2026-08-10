# Changelog

All notable changes to Sanne are documented here.

Format inspired by [Keep a Changelog](https://keepachangelog.com/).
Versioning follows [SemVer](https://semver.org/) once public releases begin.

## [Unreleased]

### Added

- **Free-space trackpad swipes** — 3-finger and 4-finger swipes L/R/U/D anywhere on the trackpad, plus a 4-finger tap, all remappable to any catalog action. Off by default: macOS consumes these for Mission Control / Spaces and registering multitouch does not suppress the system gesture, so turn the matching macOS gestures off first (Settings → Trackpad says so inline). Where 3-finger drag is also on, drag wins once it commits — a stuck mouse button is worse than a missed swipe
- **Tip-tap** — rest one finger on the trackpad and tap beside it; tap-left and tap-right are separate remappable gestures. Off by default, since it shares the pad with two-finger scrolling; the anchor must stay still, so drifting fingers cancel instead of firing
- **Magic Mouse 3-finger swipes** — L/R/U/D on the mouse surface (defaults: previous / next tab, Mission Control, App Exposé). Off by default — three fingers is an easy accident while gripping the mouse — and travel decides between a swipe and the 3-finger middle-click that shares the same chord
- **Custom script actions** — bind any gesture to a shell command, AppleScript, or macOS Shortcuts shortcut. Scripts are named and reusable across gestures, edited from Settings → Gestures → Action → Scripts, and travel with import / export. They run off the main thread with a 10 s timeout and a cap on how many may run at once; stderr and non-zero exits are reported in the Debug Log rather than crashing or stalling a gesture
- **Per-app gesture bindings** — the same gesture can run a different action depending on which app is frontmost. Settings → Apps → *Gesture bindings…*; the effective binding resolves app override → global override → Sanne Standard default, and each row shows whether it is this app's own remap or inherited from your global one. Removing an app's pause row no longer discards its remaps — they stay listed so nothing you configured can become invisible
- **Action name overlay (HUD)** — a brief label near the bottom of the screen naming the action a gesture just fired, so remapped and off-screen effects are no longer guesswork. Skipped for plain clicks and continuous drags, follows the display your cursor is on, and never takes focus from the app you are working in. Toggle in Settings → Home
- **Illustrated gesture diagrams** — every gesture row in Settings, the Gestures editor, and the Cheat Sheet now shows a small drawn tile of the device (trackpad / Magic Mouse) with finger dots, motion arrows, pinch marks, and 2× tap badges, so you can see at a glance what e.g. a "3-finger drag" looks like (inspired by BetterTouchTool/Multitouch). Zones (title bar, menu bar, Dock, mouse top edge) are highlighted on the device, and left/right mouse taps show a split line
- **System Settings-style sidebar** — tinted, filled icon tiles per section

### Fixed

- **Magic Mouse clicks without any touch** — the capacitive sensor reports fingers *hovering above* the surface (MT proximity states 1/2/6/7) and these were treated as physical contact, so a finger passing near the mouse could register a click with zero touch. Only true contact states (3–5: make-touch/touching/break-touch) now start or feed tap sessions; hover-only frames are ignored in the single-finger, multi-finger, and trackpad paths
- **Magic Mouse ghost clicks** — inadvertent left/right clicks from residual finger contacts after scrolling and from feather-light grazes:
  - Post-scroll tap locks extended (wheel/momentum 0.55/0.40s → 0.75s); logs showed residual repositions landing 0.4–0.9s after the last scroll event and clicking
  - A lift rejected by the scroll lock now re-arms the lock (+0.40s), so chains of residual contacts stay suppressed
  - New minimum tap duration (25–45ms, scales with sensitivity) rejects sub-frame grazes
  - Contact size (MT `size`) is now tracked and logged; contacts that never exceed size 0.08 are rejected as grazes

### Planned

- Notarized GitHub Releases workflow (credentials + CI)
- App icon + menu bar template images
- Homebrew cask
- Optional Sparkle auto-update

---

## [0.1.0] — 2026-08-01

First private-beta / MVP snapshot. Local packaging via `scripts/package-dmg.sh`.

### Added

- **Magic Mouse taps** — left / right / middle, multi-click, tap-drag; 2-finger Mission Control / App Exposé; top-edge 2F window move
- **Titlebar gestures** — halves, long-swipe thirds, quarters; maximize / minimize; pinch close / fullscreen; 3-finger adjacent display
- **Dock & menubar zones** — activate / hide / new window; cycle windows; hide others
- **Keyboard snap** — ⌃⌥ + arrows (cycle thirds); ⌃⌥⌘ + arrows move display
- **Modifier-drag** — ⌥⌘ move; ⌃⌘ resize
- **Gesture remap** — Settings → Gestures: catalog actions, **record custom keystroke**, **open application**
- **Per-app rules** — pause All / Magic Mouse / window gestures / keyboard+drag
- **Import / export** config JSON
- **Tutorial** + searchable gesture cheat sheet
- **Menu bar agent** — pause/resume, Accessibility onboarding, competing-app warning, launch at login (`Sanne.app`)
- **Debug log** — file + Settings UI
- **Packaging** — `package-app.sh`, `package-dmg.sh`, optional `notarize.sh`

### Known limitations

- Not notarized by default (ad-hoc sign for local installs)
- No app icon set yet
- Multi-monitor, sleep/wake, and many gestures need broader hardware QA
- Freeform keystroke labels use US key map for display

### Install

```bash
./scripts/package-dmg.sh
open dist/Sanne-0.1.0.dmg
```

Then grant **Accessibility** to Sanne.

[Unreleased]: https://github.com/sanne-app/sanne/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/sanne-app/sanne/releases/tag/v0.1.0
