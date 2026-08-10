# Sanne

Native macOS gestures for Magic Mouse and trackpad — opinionated defaults, fully customizable.

**Free and open source** (MIT). No trial, no paid tier, no account.

> Install Sanne. Gestures just work. When you want more, every default is editable.

## Features (MVP)

- **Magic Mouse taps** — left / right / middle, double/triple multi-click, tap-drag; 2-finger Mission Control / App Exposé; top-edge 2F drag to move windows; 3-finger swipes L/R/U/D (off by default)
- **Titlebar gestures** — halves, long-swipe thirds, quarters; maximize / minimize; pinch close / fullscreen; 3-finger → adjacent display
- **Keyboard snap** — ⌃⌥ + arrows (cycle thirds); ⌃⌥⌘ + arrows move display
- **Modifier-drag** — ⌥⌘ + drag move; ⌃⌘ + drag resize (anywhere on window)
- **Per-app rules** — pause all Sanne, or only Magic Mouse / window gestures / keyboard+drag, while an app is frontmost
- **Per-app gesture bindings** — the same gesture can run a different action per frontmost app (app binding → your global remap → Sanne Standard), so one swipe does different things in Safari and Xcode
- **Import / export** — backup and share config JSON (scripts and per-app bindings included)
- **Dock gestures** — swipe up activate / down hide; pinch out new window
- **Menubar gestures** — swipe L/R cycle windows; down hide others
- **Live snap preview** + optional haptics
- **Action name overlay** — a brief HUD names the action a gesture just fired; silent for clicks and drags
- **Trackpad** — three-finger tap → middle-click; three-finger drag → text select / drag items (Apple/BTT-style); free-space 3- and 4-finger swipes and four-finger tap (off by default); tip-tap — rest one finger, tap beside it (off by default)
- **Settings** — toggles for every default; reset to Sanne Standard
- **Gesture remap** — Settings → Gestures: reassign any Standard gesture to catalog actions, a recorded keystroke, opening an app, or your own shell command / AppleScript / Shortcut
- **Menu bar app** — pause/resume, Accessibility onboarding, conflict warning

### Why some gestures ship off

The gestures above marked *off by default* are opt-in for a reason, not because they're unfinished:

- **Free-space 3- and 4-finger swipes / 4-finger tap** — macOS claims these chords for Mission Control and spaces, and registering for multitouch does **not** suppress the system gesture. Turn the matching ones off in System Settings → Trackpad → More Gestures first, or both will fire.
- **Tip-tap** — it shares the pad with two-finger scrolling, so it stays out of the way until you ask for it.
- **Magic Mouse 3-finger swipes** — three fingers are easy to land while simply gripping the mouse, and the same chord held still is already a middle-click.

Enable any of them in **Settings → Trackpad** or **Settings → Magic Mouse**.

## Run

**Recommended** (stable Accessibility identity + launch at login):

```bash
./scripts/package-app.sh
open dist/Sanne.app
```

**DMG** (shareable install image + checksum):

```bash
./scripts/package-dmg.sh
open dist/Sanne-$(cat VERSION).dmg
```

Developer ID sign + notarization: see [docs/RELEASING.md](./docs/RELEASING.md).

Or for quick iteration:

```bash
swift build
swift run
```

Grant **Accessibility** to **Sanne** (path/bundle is shown in onboarding / About):

**System Settings → Privacy & Security → Accessibility**

Then:

1. Tap the Magic Mouse surface (if you have one)  
2. Two-finger swipe on a window **title bar** to snap  
3. Double-tap and hold on Magic Mouse to drag  

Config is stored at:

```text
~/Library/Application Support/Sanne/config.json
```

## Project layout

```text
Sources/Sanne/
  App/           # menu bar, lifecycle
  TouchInput/    # MultitouchSupport (private, dynamic)
  Gestures/      # recognizers + engine
  Zones/         # titlebar / dock / menubar
  Windowing/     # snap layouts, preview, AX
  Actions/       # catalog, runner, custom scripts
  Config/        # Sanne Standard + user config
  InputSynth/    # synthetic clicks
  Feedback/      # haptics
  UI/            # Settings, onboarding, action HUD
  Utilities/
```

## Progress

**Living plan + status:** [PROGRESS.md](./PROGRESS.md)

| Phase | Status |
|-------|--------|
| 0 Feasibility | Done |
| 1 MVP | In progress (~93%) — MM taps verified; windowing; remap editor |
| 2 v1.0 | In progress — tutorial, remap, custom keystroke/open app; DMG packaging ready |
| 3+ | Started — custom scripts, per-app gesture bindings, action HUD |

## Docs

| Document | Description |
|----------|-------------|
| [PROGRESS.md](./PROGRESS.md) | **Step-by-step plan + progress (start here)** |
| [CHANGELOG.md](./CHANGELOG.md) | Release history |
| [docs/RELEASING.md](./docs/RELEASING.md) | DMG, notarize, GitHub Release checklist |
| [PRD.md](./PRD.md) | Product requirements |
| [TECHNICAL_DESIGN.md](./TECHNICAL_DESIGN.md) | Architecture |
| [MVP_SCOPE.md](./MVP_SCOPE.md) | Scope phases & non-goals |
| [UX_WIREFRAMES.md](./UX_WIREFRAMES.md) | Settings / gesture maps |
| [CONTRIBUTING.md](./CONTRIBUTING.md) | How to contribute |
| [LICENSE](./LICENSE) | MIT |

## License

[MIT](./LICENSE)
