# Changelog

All notable changes to Sanne are documented here.

Format inspired by [Keep a Changelog](https://keepachangelog.com/).
Versioning follows [SemVer](https://semver.org/) once public releases begin.

## [Unreleased]

### Added

- **Continuous thirds** — a longer titlebar swipe left/right walks half → third → two-thirds; preview updates as you go. Same policy as keyboard ←/→
- **Window-to-Space** — experimental toggle on Advanced; remap any gesture to Move to Space left/right. HUD on failure
- **Magic Mouse 3-finger top-edge resize** — pair to 2-finger move
- **Gaming mode** — hold physical right-click, tap left to left-click. Off by default
- **Safe mode** — hold Option at launch to load Sanne Standard without touching `config.json`
- **Check for Updates…** — GitHub Releases compare from the menu bar and Settings → Advanced
- **Homebrew cask sketch** at `docs/homebrew/sanne.rb`
- Phase 5 tests: 0.2.0 migrate matrix, BindingResolver emit matrix, bundled Standard == slot defaults
- **First-run welcome** that stays open after Accessibility is granted, with Start Tutorial / Skip / Quit
- **One-shot Home tutorial banner** after Skip welcome
- **Menu bar** quick toggles, Option-click Debug, Accessibility badge, accessory restore on window close
- **Connected-device status** on Home; Magic Mouse empty state; wake rebind retries 3×
- **Settings IA** — 8 sidebar pages (Home, Magic Mouse, Trackpad, Windows, Keyboard, Apps, Presets, Advanced)
- **Simple-by-default** gesture lists with “Show all gestures”
- **Cheat sheet** driven by `GestureSlots` + live remaps
- **Apps page** rewrite (running-app picker, pause scope, remap count)
- **Device-branched tutorial** and one-click remap popover
- **Config honesty** — pause not persisted; corrupt JSON backed up to `.bak`; `AppOverride.isActive`
- **Slot enablement v2 migrate** — recognition reads `BindingResolver`; 0.2.0 configs keep behaviour
- **App icon** — 2D three-finger swipe mark (cream fingertips + motion dashes on clay)
- **`window.restore`** catalog action; second same-layout swipe preview shows the restore frame
- **Minimal preset** — taps + halves only; first real use of `presetId`
- **Settings search** — page titles, toggles, and slot names; “launch at login”, “haptics”, “gap”, “HUD” resolve
- **Live gesture highlight** — a fired gesture while Settings is open scrolls to its row
- **Conflict coach** — verified Multitouch / TapToClick bundle IDs; Pause Sanne / Dismiss
- **Trackpad empty state** when no pad is connected

### Changed

- Settings pages live one-file-per-tab under `UI/Preferences/Pages/`; action picker and keystroke recorder are separate files
- Magic Mouse recognition uses extracted `MMThresholds` / `ScrollLock` / `PhysicalClickGuard`; center dead zone rejects instead of becoming a left click
- Window identity is `pid + CGWindowNumber`; one `WindowMover` for modifier-drag move and Magic Mouse top-edge
- Keyboard snap is a slot family (⌃⌥ arrows / ↩ / ⌃⌥⌘ display). ↓ restores. A `CGEvent` tap consumes the chord
- Action HUD names Restore, shows “No window” on a failed snap, and says “Running {name}…” for scripts and launch-app
- Scripts run through `zsh -c` (no login profile). Click/key `usleep` is off the main actor
- ActionRunner snap cases go through `ActionCatalog.snapLayout`
- 3-finger tap uses the travel-aware drag recognizer (a wiggle is no longer a middle-click)
- `setFrame` returns false when AX set fails
- Keyboard ↓ is restore, not almost-maximize (almost-maximize stays remappable)
- Gesture diagrams expose a spoken label; HUD and tutorial skip fades when Reduce Motion is on
- Conflict detection no longer treats an app named “Middle” as a gesture app

### Planned

- Notarized GitHub Releases workflow (credentials + CI)
- Hardware QA (IMPROVEMENT_PLAN §5.2) and compatibility matrix (§5.3)
- Submit the Homebrew cask once a public DMG URL exists

---

## [0.2.0] — 2026-08-10

BTT / Multitouch parity slice: free-space trackpad chords, tip-tap, Magic Mouse 3-finger swipes,
custom scripts, per-app gesture bindings, and an action HUD. New *gestures* ship **off** by default
so existing configs keep the same behaviour until you opt in.

### Added

- **Free-space trackpad swipes** — 3-finger and 4-finger swipes L/R/U/D anywhere on the trackpad, plus a 4-finger tap, all remappable to any catalog action. Off by default: macOS consumes these for Mission Control / Spaces and registering multitouch does not suppress the system gesture, so turn the matching macOS gestures off first (Settings → Trackpad says so inline). Where 3-finger drag is also on, drag wins once it commits — a stuck mouse button is worse than a missed swipe
- **Tip-tap** — rest one finger on the trackpad and tap beside it; tap-left and tap-right are separate remappable gestures. Off by default, since it shares the pad with two-finger scrolling; the anchor must stay still, so drifting fingers cancel instead of firing
- **Magic Mouse 3-finger swipes** — L/R/U/D on the mouse surface (defaults: previous / next tab, Mission Control, App Exposé). Off by default — three fingers is an easy accident while gripping the mouse — and travel decides between a swipe and the 3-finger middle-click that shares the same chord
- **Custom script actions** — bind any gesture to a shell command, AppleScript, or macOS Shortcuts shortcut. Scripts are named and reusable across gestures, edited from Settings → Gestures → Action → Scripts, and travel with import / export. They run off the main thread with a 10 s timeout and a cap on how many may run at once; stderr and non-zero exits are reported in the Debug Log rather than crashing or stalling a gesture
- **Per-app gesture bindings** — the same gesture can run a different action depending on which app is frontmost. Settings → Apps → *Gesture bindings…*; the effective binding resolves app override → global override → Sanne Standard default, and each row shows whether it is this app's own remap or inherited from your global one. Removing an app's pause row no longer discards its remaps — they stay listed so nothing you configured can become invisible
- **Action name overlay (HUD)** — a brief label near the bottom of the screen naming the action a gesture just fired, so remapped and off-screen effects are no longer guesswork. Skipped for plain clicks and continuous drags, follows the display your cursor is on, and never takes focus from the app you are working in. Toggle in Settings → Home
- **Illustrated gesture diagrams** — every gesture row in Settings, the Gestures editor, and the Cheat Sheet now shows a small drawn tile of the device (trackpad / Magic Mouse) with finger dots, motion arrows, pinch marks, and 2× tap badges, so you can see at a glance what e.g. a "3-finger drag" looks like (inspired by BetterTouchTool/Multitouch). Zones (title bar, menu bar, Dock, mouse top edge) are highlighted on the device, and left/right mouse taps show a split line
- **System Settings-style sidebar** — tinted, filled icon tiles per section
- **`SanneTests` pure-logic suite** — BindingResolver precedence, config decode tolerance / round-trip, TipTapRecognizer state machine, free-zone finger-count lock, ActionCatalog HUD allow-list (35 tests)

### Fixed

- **Magic Mouse clicks without any touch** — the capacitive sensor reports fingers *hovering above* the surface (MT proximity states 1/2/6/7) and these were treated as physical contact, so a finger passing near the mouse could register a click with zero touch. Only true contact states (3–5: make-touch/touching/break-touch) now start or feed tap sessions; hover-only frames are ignored in the single-finger, multi-finger, and trackpad paths
- **Magic Mouse ghost clicks** — inadvertent left/right clicks from residual finger contacts after scrolling and from feather-light grazes:
  - Post-scroll tap locks extended (wheel/momentum 0.55/0.40s → 0.75s); logs showed residual repositions landing 0.4–0.9s after the last scroll event and clicking
  - A lift rejected by the scroll lock now re-arms the lock (+0.40s), so chains of residual contacts stay suppressed
  - New minimum tap duration (25–45ms, scales with sensitivity) rejects sub-frame grazes
  - Contact size (MT `size`) is now tracked and logged; contacts that never exceed size 0.08 are rejected as grazes
- **Deleting a custom script left per-app remaps dangling** — `removeCustomAction` now clears matching entries in both global and per-app override maps

### Known limitations

- New free-space / tip-tap / Magic Mouse 3F gestures still need a broader hardware QA pass on real devices (unit tests cover pure logic only)
- Not notarized by default unless this build was notarized with Developer ID credentials
- No custom app icon yet
- Freeform keystroke labels use US key map for display

### Install

```bash
./scripts/package-dmg.sh
open dist/Sanne-0.2.0.dmg
```

Then grant **Accessibility** to Sanne.

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

[Unreleased]: https://github.com/sanne-app/sanne/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/sanne-app/sanne/releases/tag/v0.2.0
[0.1.0]: https://github.com/sanne-app/sanne/releases/tag/v0.1.0
