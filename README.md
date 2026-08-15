# Sanne

Native macOS gestures for Magic Mouse and trackpad — opinionated defaults, fully customizable.

**Free and open source** (MIT). No trial, no paid tier, no account.

> Install Sanne. Gestures just work. When you want more, every default is editable.

## Features (MVP)

- **Magic Mouse taps** — left / right / middle, double/triple multi-click, tap-drag; tip-tap left / right → previous / next tab (BTT-style: rest one finger, tap the other); 2-finger Mission Control / App Exposé; top-edge 2F drag to move windows; 3-finger swipes L/R/U/D (off by default)
- **Titlebar gestures** — halves, continuous long-swipe thirds, quarters; maximize / minimize; pinch close / fullscreen; 3-finger → adjacent display
- **Keyboard snap** — ⌃⌥ + arrows (cycle thirds); ↓ restores; ⌃⌥⌘ + arrows move display. Remappable. The chord is consumed so the frontmost app does not also see it
- **Modifier-drag** — ⌥⌘ + drag move; ⌃⌘ + drag resize (anywhere on window)
- **Per-app rules** — pause all Sanne, or only Magic Mouse / window gestures / keyboard+drag, while an app is frontmost
- **Per-app gesture bindings** — the same gesture can run a different action per frontmost app (app binding → your global remap → Sanne Standard), so one swipe does different things in Safari and Xcode
- **Import / export** — backup and share config JSON (scripts and per-app bindings included)
- **Dock gestures** — swipe up activate / down hide; pinch out new window
- **Menubar gestures** — swipe L/R cycle windows; down hide others
- **Live snap preview** + optional haptics
- **Action name overlay** — a brief HUD names the action a gesture just fired; silent for clicks and drags
- **Trackpad** — three-finger tap → middle-click; three-finger drag → text select / drag items (Apple/BTT-style); tip-tap left / right → previous / next tab; tip-tap middle, 3-finger tip-tap, 3-finger click, and corner / top-edge taps (off by default); free-space 3- and 4-finger swipes and four-finger tap (off by default)
- **Settings** — 8 pages (Home, Magic Mouse, Trackpad, Windows, Keyboard, Apps, Presets, Advanced); Simple lists day-one gestures, power one click away; search finds toggles and slots
- **Presets** — Sanne Standard or Minimal (taps + halves only)
- **Gesture remap** — on each device/zone page (Magic Mouse, Trackpad, Windows, Dock, Menubar), or All bindings: reassign any Standard gesture to catalog actions, a recorded keystroke, opening an app, or your own shell command / AppleScript / Shortcut
- **Menu bar app** — pause/resume, Magic Mouse / titlebar toggles, Accessibility badge, first-run welcome + tutorial, Check for Updates
- **Magic Mouse 3-finger top-edge resize** and **gaming mode** (physical right-hold + left tap, off by default)
- **Safe mode** — hold Option at launch to load Sanne Standard without writing your config
- **Window-to-Space** — experimental, off by default; HUD on failure

### Why some gestures ship off

The gestures above marked *off by default* are opt-in for a reason, not because they're unfinished:

- **Free-space 3- and 4-finger swipes / 4-finger tap** — macOS claims these chords for Mission Control and spaces, and registering for multitouch does **not** suppress the system gesture. Turn the matching ones off in System Settings → Trackpad → More Gestures first, or both will fire.
- **Magic Mouse 3-finger swipes** — three fingers are easy to land while simply gripping the mouse, and the same chord held still is already a middle-click.
- **Tip-tap middle, 3-finger tip-tap, 3-finger click, corner / top-edge taps** — available BTT triggers, not factory defaults. Easy to hit by accident on a full-size pad; enable and remap in Settings → Trackpad.

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
swift test    # pure-logic tests (SanneKit)
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

## Privacy

Sanne is local-only. Gestures, remaps, scripts, and the debug log stay on this Mac (`~/Library/Application Support/Sanne` and `~/Library/Logs/Sanne`). There is no account, no analytics, and no cloud sync. **Check for Updates…** (Settings → Advanced, off unless you click it) is the only optional network call — it reads the latest GitHub Release. Hold **Option** at launch to load Sanne Standard without touching your config file.

**Safe mode:** hold Option while opening Sanne.app.

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

## Docs

| Document | Description |
|----------|-------------|
| [PERFORMANCE_AND_REFACTOR_PLAN.md](./PERFORMANCE_AND_REFACTOR_PLAN.md) | Performance and refactor implementation plan |
| [CHANGELOG.md](./CHANGELOG.md) | Release history |
| [docs/RELEASING.md](./docs/RELEASING.md) | DMG, notarize, GitHub Release checklist |
| [CONTRIBUTING.md](./CONTRIBUTING.md) | How to contribute |
| [LICENSE](./LICENSE) | MIT |

## License

[MIT](./LICENSE)
