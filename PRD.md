# Sanne — Product Requirements Document

**Version:** 1.0  
**Status:** Draft  
**Last updated:** 2026-07-31  
**Platform:** macOS (native)  
**Product name:** Sanne  

---

## 1. Executive summary

**Sanne** is a **free and open-source** native macOS utility that makes the Magic Trackpad, built-in MacBook trackpad, and Magic Mouse feel complete. It combines:

1. **Opinionated default gestures** that work well out of the box (inspired by Swish and TapToClick).
2. **Deep customization** so power users can remap any gesture, add app-specific rules, and extend actions (inspired by Multitouch and BetterTouchTool).
3. **First-class Magic Mouse support**, including silent tap-to-click and multi-finger gestures Apple never shipped.

Sanne sits between Swish (beautiful, fixed, window-focused) and BetterTouchTool (infinitely flexible, complex) — and unlike those apps, it has **no price tag**. The product promise:

> Install Sanne. Gestures just work. When you want more, every default is editable. Free forever.

---

## 2. Problem statement

macOS multi-touch input has three structural gaps:

| Gap | Detail |
|-----|--------|
| **Magic Mouse is underpowered** | Physical click required for primary/secondary click; no middle-click; no multi-finger gestures beyond 1–2 fingers; no silent tap. |
| **Trackpad window management is weak** | Snapping requires drag-to-edge or third-party keyboard tools. Gestures are not zone-aware (titlebar / Dock / menubar). |
| **Customization is all-or-nothing** | Swish is delightful but mostly fixed. Multitouch and BetterTouchTool are powerful but require configuration before they feel good. |

Users today stack 2–4 apps (Swish + TapToClick + Multitouch/Middle + Rectangle/BTT). Sanne replaces that stack with one focused product.

---

## 3. Product vision & principles

### 3.1 Vision

Sanne is the **missing gesture layer for macOS**: native-feeling, quiet, opinionated defaults, fully customizable.

### 3.2 Design principles

| Principle | Implication |
|-----------|-------------|
| **Opinionated first** | Ship a curated default gesture set. Day-1 experience should feel “Apple-complete.” |
| **Everything is overridable** | Every default can be toggled, remapped, or replaced. No hidden magic. |
| **Native macOS feel** | Haptics, HUDs, animations, and settings UI that match system design language. |
| **Devices as first-class citizens** | Trackpad and Magic Mouse get equal love—not Magic Mouse as an afterthought. |
| **Zone-aware where it matters** | Titlebar / Dock / menubar / desktop gestures (Swish model) are core, not a preset. |
| **Simplicity over feature count** | Prefer fewer polished systems over BTT-scale surface area (no Touch Bar rebuild, no Stream Deck, no Siri Remote in v1). |
| **Install & forget** | Menu bar app; low CPU/RAM; works after sleep/wake; minimal permission friction. |
| **Privacy** | No telemetry by default. No account required. |
| **Free & open** | MIT (recommended). All features free. No “pro” upsell. |

---

## 4. Competitive feature inventory

Features collected from each reference product, then mapped into Sanne’s scope.

### 4.1 Swish ([highlyopinionated.co/swish](https://highlyopinionated.co/swish/))

| Feature | Description |
|---------|-------------|
| Zone-based gestures | Gestures on **titlebar**, **Dock icons**, **menubar** (not only free-space swipes) |
| ~30 window/dock/menubar gestures | Curated set; toggle each on/off |
| Titlebar swipe L/R | Snap left/right half |
| Titlebar diagonal swipe | Quarters |
| Titlebar swipe up | Maximize / fullscreen variants |
| Titlebar swipe down | Minimize |
| Titlebar pinch in | Close window (deeper pinch → quit app) |
| Titlebar pinch out | Fullscreen |
| Continuous / extended swipe | Cycle thirds, two-thirds, center layouts |
| Dock swipe up/down | Show/hide app windows; activate |
| Dock pinch | New window/tab (⌘N-style) |
| Menubar swipe L/R | Focus next/prev window |
| Menubar swipe up/down | Unminimize all / hide all |
| Multi-display moves | Swipe to move windows between screens by physical layout |
| Spaces support | Move windows between Spaces |
| Pixel-perfect grids | 2×2, 3×2, 3×3; drag divider to resize adjacent windows |
| Live snap preview | Visual feedback before commit |
| Haptic feedback | On action recognition |
| Keyboard snapping | Arrows, WASD, IJKL, Dvorak |
| Magic Mouse support | Adapted gestures + modifier combos |
| Magic Trackpad + built-in trackpad | Primary input |
| Settings explain gestures | In-app tutorial + per-gesture docs |
| Per-gesture enable/disable | Click icon to toggle |
| Commercial / paid | Free alternatives exist; Sanne is FOSS instead |

**Sanne takeaway:** Zone model + opinionated defaults + preview + haptics are non-negotiable.

### 4.2 Multitouch ([multitouch.app](https://multitouch.app/))

| Feature | Description |
|---------|-------------|
| General gesture engine | Map multi-finger trackpad & Magic Mouse gestures → actions |
| Large action catalog | Browser actions, keystrokes, clicks, system actions |
| Window management | Rectangle-style shortcuts, menu items, drag-to-snap areas |
| Hyper key | Convert a key into Hyper (⌃⌥⇧⌘) |
| Key remapping | Keys → clicks, shortcuts, scripts |
| Mouse button remapping | Remap buttons |
| Keyboard shortcuts → scripts | Run scripts from hotkeys |
| 3/4-finger swipes | Custom swipes beyond macOS defaults |
| Middle click | Multi-finger click/tap implementations |
| Private framework option | Required for Magic Mouse; optional avoid for trackpad stability |
| Commercial | Multitouch is paid; Sanne is free/OSS |

**Sanne takeaway:** Flexible gesture→action mapping, middle-click, key remaps, and solid window actions.

### 4.3 BetterTouchTool ([folivora.ai](https://folivora.ai/))

| Feature | Description |
|---------|-------------|
| 600+ triggers × 600+ actions | Chainable actions; millions of combos |
| Per-app configurations | Triggers scoped to specific apps or global |
| Trackpad gestures | Full multi-finger catalog |
| Magic Mouse gestures | Including multi-finger top-touch, tip-taps, etc. |
| Drawing gestures | Finger-drawn shapes as triggers |
| Normal mouse | Button remap, short/long click, smooth scroll |
| Keyboard shortcuts | Global + app-specific |
| Window snapping | Edge/corner snap areas; customizable |
| Modifier+drag move/resize | Move/resize window from anywhere in window |
| Magic Mouse start/stop move-resize | e.g. 2/3 finger touch top + move |
| Trigger conditions | Cursor over titlebar / Dock / menubar / notch; advanced conditions |
| On touch release actions | e.g. middle-mouse-down on press, up on release (CAD pan) |
| HUD overlay | Show when gesture fires |
| Haptic on gesture | Configurable |
| Action repeat while fingers down | For supported gestures |
| Floating menus / widgets | Custom HUDs attached to windows/screen (power feature) |
| Spotlight-style launcher | Search apps, windows, files, actions |
| Scripting | AppleScript, shell, JS automation |
| Presets import/export | Share configurations |
| Scroll modifiers | Dynamic scroll behavior changes |
| Touch Bar / Stream Deck / Siri Remote | Broad input surface (out of Sanne v1 scope) |

**Sanne takeaway:** Per-app scopes, conditions (zone), action chaining (limited), HUD, haptics, export/import. Cap complexity; do not aim for BTT’s entire surface in v1.

### 4.4 TapToClick ([taptoclick.app](https://taptoclick.app/))

| Feature | Description |
|---------|-------------|
| Silent tap-to-click (left) | Light tap left zone = primary click (no physical click) |
| Right-click zone | Tap right side = secondary click |
| Middle-click | Three-finger surface touch |
| Tap-drag | Double-tap-and-hold on second tap → drag |
| Single / double / triple click | Via taps |
| Palm rejection | Resting hand does not click |
| Gaming mode | Physical right-click hold + left tap fire (ADS + shoot) |
| Battery / CPU efficient | Background agent, minimal resources |
| Non-interference | Works with native Magic Mouse gestures |
| Install & forget | Accessibility once; silent thereafter |
| Notarized | Apple notarization |
| Commercial | Paid utility; Sanne covers this FOSS |

**Sanne takeaway:** Magic Mouse tap stack (left/right/middle/drag/gaming/palm rejection) is a **core pillar**, not an add-on.

---

## 5. Product positioning

| | Swish | Multitouch | BTT | TapToClick | **Sanne** |
|--|-------|------------|-----|------------|-----------|
| Opinionated defaults | ★★★★★ | ★★☆☆☆ | ★☆☆☆☆ | ★★★★★ | **★★★★★** |
| Gesture customization | ★★☆☆☆ | ★★★★☆ | ★★★★★ | ★☆☆☆☆ | **★★★★☆** |
| Window / zone WM | ★★★★★ | ★★★☆☆ | ★★★★☆ | — | **★★★★★** |
| Magic Mouse taps | — | ★★☆☆☆ | ★★★☆☆ | ★★★★★ | **★★★★★** |
| Complexity | Low | Medium | Very high | Very low | **Low→Medium** |
| Scope creep risk | Low | Medium | High | Low | **Controlled** |

**One-liner:**  
*Sanne = Swish’s zone window gestures + Multitouch’s gesture engine + TapToClick’s Magic Mouse taps + a curated slice of BTT power.*

---

## 6. Goals & non-goals

### 6.1 Goals (v1)

1. Ship a **complete default gesture pack** for trackpad and Magic Mouse that feels intentional day one.
2. Make **Magic Mouse** usable without physical clicks (tap, right, middle, drag).
3. Provide **zone-based window management** (titlebar / Dock / menubar) with live preview and haptics.
4. Allow **full remapping** of defaults and custom gesture→action rules (global + per-app).
5. Stay **lightweight**, stable across sleep/wake, and respectful of Accessibility APIs.
6. Deliver a native Swift/AppKit (or SwiftUI shell) menu bar app with excellent settings UX.

### 6.2 Non-goals (v1)

- Touch Bar customization  
- Stream Deck / MIDI / Siri Remote  
- Full floating-menu / desktop-widget builder (BTT-level)  
- Spotlight-style universal launcher (may be v2)  
- Complex multi-step automation / full Keyboard Maestro replacement  
- Non-Apple third-party trackpads (best-effort only if free)  
- Windows / iOS / iPadOS  
- Cloud sync of settings (local export/import first)  
- Paid tiers, trials, license servers, or feature gating  

---

## 7. Target users & personas

### 7.1 Primary: “Trackpad-native knowledge worker”

Uses MacBook trackpad or Magic Trackpad all day. Wants window snapping and app control without keyboard gymnastics. Values polish and defaults.

### 7.2 Primary: “Magic Mouse user who hates the click”

Uses Magic Mouse for desk setups. Wants silent taps, middle-click for browser tabs, and more gestures without buying a third-party mouse.

### 7.3 Secondary: “Power customizer”

Wants per-app gestures (e.g. middle-click only in browsers/CAD), custom keystrokes, and exportable configs. Will leave if forced into a rigid set only.

### 7.4 Anti-persona

- Users who only want free Rectangle-style keyboard snapping  
- Users who need BTT’s entire ecosystem (Touch Bar + Stream Deck + floating HUDs)  

---

## 8. Platform & technical constraints

| Requirement | Detail |
|-------------|--------|
| **OS** | macOS 13 Ventura minimum (target); optimize for Apple Silicon + Intel |
| **Permissions** | Accessibility (required); Input Monitoring if needed for key remaps |
| **Distribution** | Direct download + notarization (not App Store—sandbox blocks low-level touch/window APIs) |
| **Architecture** | Menu bar agent + preferences window; launch at login option |
| **Input stack** | MultiTouch private APIs / event taps as needed (Magic Mouse multi-finger); graceful fallbacks |
| **Conflict policy** | Detect other gesture apps (BTT, Multitouch, Swish, Middle, TapToClick); warn user |
| **Performance** | Idle CPU near 0%; memory budget target &lt; 50 MB typical |
| **Reliability** | Re-attach on wake; survive display reconfig; multi-monitor aware |

---

## 9. Feature requirements

Priority: **P0** = must ship v1 · **P1** = strong v1 if capacity · **P2** = v1.x / v2

---

### 9.1 Magic Mouse — Tap & click system (from TapToClick + Multitouch)

| ID | Feature | Priority | Description |
|----|---------|----------|-------------|
| MM-01 | **Tap to left-click** | P0 | Light tap on left zone → primary click without physical click |
| MM-02 | **Tap to right-click** | P0 | Tap right zone → secondary click |
| MM-03 | **Middle-click** | P0 | Configurable: 3-finger tap/touch OR two-finger click OR tip-tap |
| MM-04 | **Double / triple click via tap** | P0 | Double-tap and triple-tap map to OS multi-clicks |
| MM-05 | **Tap-drag** | P0 | Double-tap-hold on second tap then move → drag files/windows |
| MM-06 | **Palm rejection** | P0 | Ignore resting palm / broad contact; only deliberate taps |
| MM-07 | **Sensitivity & zone tuning** | P0 | Adjust left/right split, tap force/duration thresholds |
| MM-08 | **Gaming mode** | P1 | Physical secondary hold + left tap = fire while ADS |
| MM-09 | **Click sound optional** | P2 | Optional soft click sound (off by default—silent is the point) |
| MM-10 | **Physical click still works** | P0 | Never break hardware click; taps augment |
| MM-11 | **Disable when not Magic Mouse** | P0 | Auto-detect connected device; no false triggers on trackpad |

**Default Magic Mouse tap profile (opinionated):**

| Gesture | Action |
|---------|--------|
| Tap left | Left click |
| Tap right | Right click |
| 3-finger touch | Middle click |
| Double-tap-hold + move | Drag |
| 1-finger double-tap | Smart zoom (keep macOS behavior or map explicitly) |

---

### 9.2 Trackpad & Magic Mouse — Gesture engine (from Multitouch + BTT)

#### 9.2.1 Supported devices

| Device | Support |
|--------|---------|
| Built-in MacBook trackpad | Full |
| Magic Trackpad 1/2/3 | Full |
| Magic Mouse 1/2/3 | Full |
| Third-party mice | P2 best-effort button remap only |

#### 9.2.2 Gesture vocabulary (triggers)

**Trackpad triggers (P0 unless noted):**

| Category | Gestures |
|----------|----------|
| Taps | 1–5 finger tap; tip-tap sequences |
| Clicks | 1–4 finger click; force click (if available) |
| Swipes | 2/3/4/5 finger swipe N/S/E/W + diagonals |
| Pinch / spread | 2-finger pinch in/out |
| Rotate | 2-finger rotate CW/CCW |
| Hold / long press | Multi-finger touch-and-hold |
| Tip-tap | e.g. 2-finger base + 1-finger tip-tap L/R |
| Drawing | P2 — simple shapes (circle, swipe-path) |

**Magic Mouse triggers (P0 unless noted):**

| Category | Gestures |
|----------|----------|
| Surface taps | 1-finger tap zones (left/right/center) |
| Multi-finger touch | 2/3 finger touch; touch top region |
| Swipes | 1/2 finger swipe N/S/E/W |
| Pinch | If hardware reports (limited) |
| Double-tap | 1/2 finger double-tap |
| Touch + drag | Multi-finger touch then move for window move/resize |
| Tip-tap / corner taps | P1 |

#### 9.2.3 Gesture configuration options (per gesture)

| Option | Priority |
|--------|----------|
| Enable / disable | P0 |
| Map to one or more actions (sequence, max ~5) | P0 (chain of 2–3 is enough for v1) |
| Require modifier keys (⌘⌥⌃⇧ fn) | P0 |
| Scope: All apps / specific app | P0 |
| Cursor zone condition (anywhere, titlebar, Dock, menubar, not Dock/menubar, notch) | P0 |
| Sensitivity / distance / speed threshold | P0 |
| Haptic feedback on fire | P0 |
| Show HUD overlay on fire | P1 |
| On finger-down action + on release action | P1 (middle-click hold patterns) |
| Conflict with system gesture (warn / override / defer) | P0 |

---

### 9.3 Zone-based window management (from Swish)

This is Sanne’s **signature experience**.

#### 9.3.1 Zones

| Zone | Cursor / context |
|------|------------------|
| **Titlebar** | Over window titlebar / traffic-light region |
| **Dock** | Over Dock icons |
| **Menubar** | Over menu bar |
| **Desktop / free space** | Elsewhere (optional set of free-space gestures) |
| **Window body** | Optional with modifier (e.g. Fn) for anywhere-on-window |

#### 9.3.2 Default titlebar gestures (trackpad, 2-finger)

| Gesture | Action | Notes |
|---------|--------|-------|
| Swipe left | Snap left half | Live preview |
| Swipe right | Snap right half | |
| Swipe up | Maximize (fill screen, not macOS fullscreen) | Distinguish maximize vs Stage Manager / fullscreen |
| Swipe down | Minimize | |
| Diagonal UL/UR/DL/DR | Snap to corresponding quarter | |
| Continuous / long swipe L/R | Cycle thirds → two-thirds → middle third | |
| Continuous / long swipe up | Centered ~65% window | |
| Pinch in | Close window | Deeper pinch → Quit app |
| Pinch out | Enter native fullscreen | |
| 3-finger swipe L/R | Move window to adjacent display (by physical arrangement) | Multi-monitor |
| 3-finger swipe U/D | Move window to adjacent Space | |

#### 9.3.3 Default Dock gestures

| Gesture | Action |
|---------|--------|
| Swipe down on icon | Minimize / hide all windows of that app |
| Swipe up on icon | Activate / unminimize app |
| Pinch out on icon | New window (⌘N) |
| Pinch in on icon | Quit app (with optional confirm for unsaved) |

#### 9.3.4 Default menubar gestures

| Gesture | Action |
|---------|--------|
| Swipe left / right | Focus previous / next window (cycle) |
| Swipe down | Hide all other apps / Show Desktop-like focus |
| Swipe up | Unminimize / bring forward open apps |

#### 9.3.5 Grid & layout system

| Feature | Priority |
|---------|----------|
| Halves, quarters | P0 |
| Thirds / two-thirds | P0 |
| 2×2, 3×2, 3×3 grids | P0 |
| Live preview overlay while gesturing | P0 |
| Restore previous frame on unsnap / double gesture | P0 |
| Adjacent window resize via shared divider drag | P1 |
| Per-display layout memory | P1 |
| Custom snap percentages | P1 |
| Edge drag-to-snap (Rectangle-style) | P1 |
| Keyboard snap: arrows / WASD / IJKL | P0 |

#### 9.3.6 Window move & resize helpers (from BTT/Multitouch)

| Feature | Priority |
|---------|----------|
| Modifier + drag anywhere to **move** window | P0 |
| Modifier + drag anywhere to **resize** window | P0 |
| Magic Mouse: multi-finger touch top → move/resize | P0 |
| Three-finger drag (if not conflicting with system) | P1 |

---

### 9.4 Action catalog

Actions a gesture or hotkey can invoke.

#### 9.4.1 Window actions (P0)

- Snap to position (halves, thirds, quarters, custom rect)  
- Maximize / restore / minimize / close / quit  
- Fullscreen enter/exit  
- Move to next/prev display  
- Move to next/prev Space  
- Center window  
- Almost-maximize (inset margins)  
- Bring all windows of app forward  
- Hide others / hide app  

#### 9.4.2 Input / click actions (P0)

- Left / right / middle click (down, up, full click)  
- Double / triple click  
- Scroll step (direction)  
- Send keystroke / key sequence  
- Hyper key press (modifier chord)  
- Toggle modifier lock  

#### 9.4.3 System & app actions (P0–P1)

- Launch / activate / quit app  
- Open URL / file / folder  
- Mission Control / App Exposé / Show Desktop / Launchpad  
- Volume / brightness / media keys  
- Switch Space / full-screen app swipe simulation  
- Run Shell script / Shortcuts / AppleScript (P1)  
- Browser: new tab, close tab, next/prev tab, back/forward (P0 common set)  

#### 9.4.4 Feedback actions (P0–P1)

- Haptic pattern  
- HUD message  
- Play system sound (P2)  

---

### 9.5 Keyboard & keys (from Multitouch + BTT slice)

| ID | Feature | Priority |
|----|---------|----------|
| KB-01 | Global keyboard shortcuts → any action | P0 |
| KB-02 | App-specific shortcuts | P0 |
| KB-03 | Hyper key (map Caps Lock or other → ⌃⌥⇧⌘) | P0 |
| KB-04 | Key remaps (simple single-key → other key/action) | P1 |
| KB-05 | Keyboard window snapping (arrows/WASD) | P0 |

---

### 9.6 Defaults system & opinionation

This is Sanne’s product differentiator vs BTT.

| ID | Feature | Priority | Description |
|----|---------|----------|-------------|
| DEF-01 | **Sanne Standard pack** | P0 | Curated defaults for trackpad + Magic Mouse + zones + taps |
| DEF-02 | **Preset gallery** | P1 | Alternate packs: “Minimal”, “Windows refugee”, “Dev browser-heavy”, “Designer” |
| DEF-03 | **Reset single gesture** | P0 | Restore one item to default |
| DEF-04 | **Reset all to Sanne Standard** | P0 | With confirmation |
| DEF-05 | **Tutorial on first launch** | P0 | Interactive 60–90s walkthrough of titlebar swipe, tap-to-click, middle-click |
| DEF-06 | **Gesture cheat sheet** | P0 | In-app searchable list; optional menu bar quick reference |
| DEF-07 | **Conflict resolver** | P0 | Detect macOS system gesture overlaps; suggest disable system or Sanne |
| DEF-08 | **Import / export config** | P0 | JSON or package file for backup/share |
| DEF-09 | **Diff vs defaults view** | P1 | See what user changed from Standard |

**Philosophy:** Defaults should be so good that 70%+ of users never open Advanced. Customization must still be one click away from any default row.

---

### 9.7 Settings UX

| ID | Feature | Priority |
|----|---------|----------|
| UX-01 | Menu bar icon (status: active / paused / permission needed) | P0 |
| UX-02 | Preferences window with sections: Overview, Trackpad, Magic Mouse, Windows, Keyboard, Apps, Advanced | P0 |
| UX-03 | Visual gesture editor (diagram of trackpad/mouse + mapped action) | P0 |
| UX-04 | Live test / “perform gesture to capture” | P1 |
| UX-05 | Per-gesture toggle without deleting | P0 |
| UX-06 | Pause Sanne globally (hotkey + menu) | P0 |
| UX-07 | Launch at login | P0 |
| UX-08 | Onboarding permission flow (Accessibility step-by-step) | P0 |
| UX-09 | Dark / light / system appearance | P0 |
| UX-10 | Search in settings | P1 |

---

### 9.8 Reliability, performance, safety

| ID | Feature | Priority |
|----|---------|----------|
| REL-01 | Survive sleep/wake; re-bind multi-touch listeners | P0 |
| REL-02 | Multi-monitor configuration changes | P0 |
| REL-03 | Detect competing apps and warn | P0 |
| REL-04 | Safe mode: hold modifier on launch to skip custom config | P1 |
| REL-05 | Crash reports opt-in only | P1 |
| REL-06 | No network required for core function | P0 |

---

## 10. Default gesture packs (detailed)

### 10.1 Sanne Standard — Trackpad (free space)

| Gesture | Default action | Rationale |
|---------|----------------|-----------|
| 3-finger swipe up | Mission Control | Familiar macOS (or keep system if enabled) |
| 3-finger swipe down | App Exposé | |
| 3-finger swipe L/R | Switch Space / full-screen apps | |
| 3-finger tap | Middle click | High-value addition |
| 4-finger pinch | Show Desktop | |
| *Zone gestures* | See §9.3 | Sanne signature |

*Note:* Free-space 3/4 finger defaults should **defer to system** when system already owns them; Sanne documents the handoff and only overrides when user opts in.

### 10.2 Sanne Standard — Magic Mouse

| Gesture | Default action |
|---------|----------------|
| Tap left | Left click |
| Tap right | Right click |
| 3-finger touch | Middle click |
| Double-tap-hold + move | Drag |
| 1-finger swipe L/R | Back / forward (browser) or system swipe between pages |
| 2-finger swipe L/R | Switch Space |
| 2-finger double-tap | Mission Control |
| 2-finger touch top + move | Move window under cursor |
| 3-finger touch top + move | Resize window under cursor |

### 10.3 Sanne Standard — Titlebar (2-finger)

As in §9.3.2 — this pack is always on after install (individually togglable).

---

## 11. User journeys

### 11.1 First-run (Magic Mouse user)

1. Download DMG → drag to Applications → open.  
2. Grant Accessibility.  
3. Tutorial: “Tap left side of mouse” → success haptic.  
4. Tutorial: “Hover a window titlebar, two-finger swipe right” → window snaps.  
5. Menu bar icon shows ready. User works silently.

### 11.2 First-run (Trackpad-only)

1. Same install.  
2. Tutorial focuses on titlebar snap + Dock hide + middle-click 3-finger tap.  
3. Magic Mouse section shows “Connect a Magic Mouse for tap-to-click.”

### 11.3 Power user customization

1. Open Preferences → Trackpad → find 3-finger tap.  
2. Change action from Middle Click → “Close Tab” for Safari only.  
3. Add global 4-finger tip-tap → run script.  
4. Export config to Dropbox / git.

### 11.4 Conflict

1. User also runs Multitouch.  
2. Sanne detects and shows: “Another gesture app is running. Disable Multitouch or pause Sanne.”  
3. User pauses Multitouch; Sanne continues.

---

## 12. Information architecture (settings)

```
Sanne Preferences
├── Home / Status
│   ├── Permissions
│   ├── Active devices
│   ├── Pause / Resume
│   └── Tutorial / Cheat sheet
├── Magic Mouse
│   ├── Tap to click (left / right / middle)
│   ├── Drag
│   ├── Palm rejection & sensitivity
│   ├── Gaming mode
│   └── Advanced gestures list
├── Trackpad
│   ├── Free-space gestures
│   ├── Sensitivity
│   └── Advanced gestures list
├── Windows
│   ├── Zone gestures (Titlebar / Dock / Menubar)
│   ├── Grid & snap positions
│   ├── Move / resize helpers
│   └── Keyboard snapping
├── Keyboard
│   ├── Hyper key
│   ├── Global shortcuts
│   └── Remaps
├── Apps
│   └── Per-app overrides
├── Presets
│   ├── Sanne Standard
│   ├── Other packs
│   └── Import / Export / Reset
└── Advanced
    ├── Conflicts
    ├── Performance
    ├── Privacy
    └── About / License (OSS)
```

---

## 13. Success metrics

| Metric | Target (post-launch 90 days) |
|--------|------------------------------|
| GitHub stars / Homebrew installs | Steady growth; qualitative community signal |
| Day-1 return usage (survey / opt-in) | ≥ 60% would keep using |
| % users who never change defaults | ≥ 50% (opinionation working) |
| % users who customize ≥1 gesture | ≥ 30% (power path exists) |
| Crash-free sessions | ≥ 99.5% |
| Issues: “gestures stopped after sleep” | &lt; 5% of bug reports |
| Qualitative | “Feels like it should be built into macOS” |
| Contributors | ≥ 1 external PR merged in first 90 days |

---

## 14. Licensing & distribution (free & open source)

Sanne is **completely free** and **open source**. No trial, no paid tier, no license keys, no activation limits.

| Item | Decision |
|------|----------|
| **Price** | Free forever (all features) |
| **Source** | Public repository; contributions welcome |
| **License** | **MIT** (default recommendation — simple, permissive, App-Store-adjacent tooling friendly). Alternatives if contributors prefer: Apache-2.0 or GPL-3.0 — pick one before first public commit and keep it consistent. |
| **Distribution** | GitHub Releases (notarized DMG/ZIP) + optional Homebrew cask |
| **Updates** | Free; Sparkle or GitHub-native update check (optional) |
| **Accounts** | None required |
| **Telemetry** | Off by default; none in core (see privacy principle) |
| **Commercial use** | Allowed under the chosen OSI license (MIT/Apache allow; GPL has copyleft terms) |
| **Donations** | Optional (GitHub Sponsors / similar) — never gated features |
| **Trademark** | Name “Sanne” may still need clearance; code is free regardless |

**Why FOSS:** The category is dominated by paid utilities ($16–$22). A polished, opinionated, free alternative is a clear differentiator and matches the “should be built into macOS” ethos.

**Notarization:** Releases can still be **Apple-notarized** by maintainers so users don’t fight Gatekeeper; that does not require closing the source.

---

## 15. Release plan

### 15.1 MVP (v0.9 / public beta)

- Magic Mouse tap left/right/middle + drag + palm rejection  
- Titlebar zone gestures (halves, quarters, minimize, close, maximize) with preview  
- Dock minimize/activate  
- 3-finger trackpad middle-click  
- Sanne Standard defaults  
- Preferences + per-gesture toggle  
- Accessibility onboarding  
- Notarized builds  

### 15.2 v1.0

- Full zone pack (menubar + multi-display + Spaces)  
- Custom gesture→action mapping (global + per-app)  
- Keyboard snapping + Hyper key  
- Modifier move/resize  
- Import/export  
- Conflict detection  
- Tutorial + cheat sheet  
- Thirds / continuous swipe layouts  

### 15.3 v1.x

- Preset gallery  
- HUD overlays  
- On-release action pairs  
- Adjacent divider resize  
- Shell/AppleScript actions  
- Gaming mode polish  
- Edge drag-to-snap  

### 15.4 v2 (later)

- Drawing gestures  
- Limited floating quick-actions palette  
- Launcher-lite  
- iCloud/local sync of configs  
- Third-party mouse deeper support  

---

## 16. Risks & mitigations

| Risk | Mitigation |
|------|------------|
| Private MultiTouch APIs break on OS update | Abstract device layer; subscribe to beta macOS; “avoid private framework” trackpad fallback |
| Gesture conflicts with macOS system gestures | Explicit conflict matrix; defer-to-system defaults; clear UI |
| Competing with BTT feature creep | Hard non-goals; quarterly scope review |
| Accessibility rejection / fragility | Single event-tap ownership; sleep/wake tests in CI-like script |
| Magic Mouse false clicks | Strong palm rejection; tunable thresholds; disable list per app |
| Users expect full BTT | Marketing: “opinionated gesture & window layer,” not “automate everything” |

---

## 17. Open questions — resolved

Decisions locked for design (see [TECHNICAL_DESIGN.md](./TECHNICAL_DESIGN.md) §2):

| Question | Decision |
|----------|----------|
| **Maximize vs fullscreen** | Swipe-up → **fill visible frame**; pinch-out → native fullscreen |
| **System gesture ownership** | Standard pack **zones only**; free-space 3/4-finger stays with macOS |
| **Hyper / Caps Lock** | v1: remap a chosen key (e.g. Right ⌘); Caps Lock Hyper → v1.x |
| **Business model** | **100% free and open source** — no paid tier |
| **OSS license** | **MIT** (recommended; confirm in repo `LICENSE`) |
| **Bundle ID** | `app.sanne.Sanne` (placeholder until domain/trademark confirmed) |
| **UI stack** | AppKit agent + overlays; **SwiftUI** Preferences |

**Still open (non-blocking):**

1. Trademark clearance for the name “Sanne”  
2. Final brand accent color / menu bar glyph  
3. MIT vs Apache-2.0 vs GPL-3.0 if legal preference differs  
4. Whether Homebrew cask ships day-one with v1.0  

---

## 18. Appendix A — Feature matrix (reference apps → Sanne)

| Feature | Swish | Multitouch | BTT | TapToClick | Sanne v1 |
|---------|:-----:|:----------:|:---:|:----------:|:--------:|
| Titlebar zone gestures | ✓ | ~ | ✓* | — | ✓ |
| Dock / menubar zones | ✓ | — | ✓* | — | ✓ |
| Live snap preview | ✓ | ~ | ✓ | — | ✓ |
| Grid thirds/quarters | ✓ | ✓ | ✓ | — | ✓ |
| Multi-display window move | ✓ | ✓ | ✓ | — | ✓ |
| Keyboard snap | ✓ | ✓ | ✓ | — | ✓ |
| Custom free-space gestures | — | ✓ | ✓ | — | ✓ |
| Per-app gesture maps | — | ✓ | ✓ | — | ✓ |
| Action chaining | — | ~ | ✓ | — | Limited |
| Middle click | — | ✓ | ✓ | ✓ | ✓ |
| Magic Mouse tap-to-click | — | ~ | ~ | ✓ | ✓ |
| Palm rejection | — | ~ | ~ | ✓ | ✓ |
| Gaming mode | — | — | — | ✓ | P1 |
| Hyper key | — | ✓ | ✓ | — | ✓ |
| Drawing gestures | — | — | ✓ | — | v2 |
| Floating menus | — | — | ✓ | — | Out |
| Touch Bar / Stream Deck | — | — | ✓ | — | Out |
| Scripting | — | ~ | ✓ | — | P1 basic |
| Opinionated defaults | ✓ | — | — | ✓ | ✓ |
| Full remap of defaults | Partial | ✓ | ✓ | Partial | ✓ |

\*BTT supports via conditions/presets, not opinionated product UX.

---

## 19. Appendix B — Default titlebar gesture map (quick reference)

```
                 [pinch out → fullscreen]
                        ↑ swipe
    snap left ← swipe · titlebar · swipe → snap right
                        ↓ swipe
                   [minimize]

    diagonals → quarters
    long swipe L/R → thirds cycle
    pinch in → close (deeper → quit)
```

---

## 20. Appendix C — Glossary

| Term | Meaning |
|------|---------|
| **Zone** | Screen region (titlebar, Dock, menubar) that changes gesture meaning |
| **Trigger** | Detected gesture or key event |
| **Action** | Effect Sanne performs when a trigger fires |
| **Sanne Standard** | The opinionated default preset |
| **HUD** | Transient on-screen confirmation (like volume bezel) |
| **Hyper key** | Single key that holds ⌃⌥⇧⌘ |

---

## 21. Appendix D — Source apps (research basis)

1. [Swish](https://highlyopinionated.co/swish/) — zone window gestures, opinionated UX  
2. [Multitouch](https://multitouch.app/) — general gesture engine, keys, window actions  
3. [BetterTouchTool](https://folivora.ai/) — triggers, conditions, move/resize, extensibility  
4. [TapToClick](https://taptoclick.app/) — Magic Mouse silent taps, middle-click, drag, gaming  

---

## 22. Next steps

Completed:

1. ~~Resolve open questions~~ → §17  
2. ~~Technical design~~ → [TECHNICAL_DESIGN.md](./TECHNICAL_DESIGN.md)  
3. ~~MVP scope cut~~ → [MVP_SCOPE.md](./MVP_SCOPE.md)  
4. ~~UX wireframes & gesture maps~~ → [UX_WIREFRAMES.md](./UX_WIREFRAMES.md)  

Remaining:

1. Harden multitouch layout decoding & Magic Mouse device classification on real hardware  
2. Dock / menubar zones, keyboard snap, per-app rules (v1.0)  
3. Proper `.app` bundle + notarization + Homebrew  
4. Trademark / domain / icon for **Sanne**  
5. Community beta  

---

*End of PRD*
