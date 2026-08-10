# Sanne — UX Wireframes & Gesture Maps

**Version:** 1.0  
**Status:** Draft  
**Companion to:** [PRD.md](./PRD.md) · [TECHNICAL_DESIGN.md](./TECHNICAL_DESIGN.md) · [MVP_SCOPE.md](./MVP_SCOPE.md)  
**Last updated:** 2026-07-31  

---

## 1. Design language

| Token | Choice |
|-------|--------|
| Inspiration | System Settings + Swish clarity (not BTT density) |
| Density | Comfortable; one concept per row |
| Icons | SF Symbols; template menu bar icon |
| Accent | System accent (respect user) + Sanne brand mark |
| Motion | Short (≤200 ms); honor Reduce Motion |
| Copy | Plain English; no “trigger/action” jargon in basic mode |

**Two modes in Preferences:**

- **Simple** (default): toggles + diagrams + sensitivity  
- **Advanced**: full rule list, per-app, remap picker  

---

## 2. Menu bar

### 2.1 Icon states

| State | Icon treatment |
|-------|----------------|
| Running | Template “S” or fingerprint/gesture mark |
| Paused | Dimmed / slash |
| Needs permission | Badge / warning |

### 2.2 Menu wireframe

```
┌─────────────────────────────────────┐
│  Sanne                        ✓     │
│─────────────────────────────────────│
│  Pause Gestures              ⌥⌘P    │
│  Open Preferences…           ⌘,     │
│─────────────────────────────────────│
│  Magic Mouse Taps            ✓      │
│  Titlebar Window Gestures    ✓      │
│─────────────────────────────────────│
│  Gesture Cheat Sheet…               │
│  Tutorial…                          │
│─────────────────────────────────────│
│  ⚠ Multitouch is also running…      │
│─────────────────────────────────────│
│  Quit Sanne                         │
└─────────────────────────────────────┘
```

---

## 3. Onboarding (first launch)

### Step 1 — Welcome

```
┌──────────────────────────────────────────────────────┐
│  [Sanne icon]                                        │
│                                                      │
│  Welcome to Sanne                                    │
│  Gestures for your trackpad and Magic Mouse          │
│  that feel like they belong on macOS.                │
│                                                      │
│  • Silent taps on Magic Mouse                        │
│  • Swipe window titlebars to snap                    │
│  • Opinionated defaults — fully customizable later   │
│                                                      │
│                         [ Continue ]                 │
└──────────────────────────────────────────────────────┘
```

### Step 2 — Accessibility

```
┌──────────────────────────────────────────────────────┐
│  Allow Accessibility                                 │
│                                                      │
│  Sanne needs Accessibility to move windows and       │
│  recognize gestures. Your data stays on this Mac.    │
│                                                      │
│  1. Click Open System Settings                       │
│  2. Enable Sanne in Privacy → Accessibility          │
│  3. Return here                                      │
│                                                      │
│  Status: ● Waiting for permission                    │
│                                                      │
│  [ Open System Settings ]      [ Quit ]              │
└──────────────────────────────────────────────────────┘
```

Auto-advances when `AXIsProcessTrusted()` becomes true.

### Step 3 — Tutorial (branch)

**If Magic Mouse connected:**

```
┌──────────────────────────────────────────────────────┐
│  Try a silent click                                  │
│                                                      │
│         ┌─────────────┐                              │
│         │  MAGIC MOUSE │  ← animate tap left         │
│         │   [•  ]      │                              │
│         └─────────────┘                              │
│                                                      │
│  Lightly tap the left side of your Magic Mouse.      │
│  (No physical click needed.)                         │
│                                                      │
│  Waiting for tap…                                    │
│                                                      │
│  [ Skip ]                                            │
└──────────────────────────────────────────────────────┘
```

On success → checkmark + “Tap right side for right-click” (optional second beat).

**Always (trackpad):**

```
┌──────────────────────────────────────────────────────┐
│  Snap a window                                       │
│                                                      │
│  1. Open any window (Finder is fine)                 │
│  2. Put the pointer on the title bar                 │
│  3. Two-finger swipe right on the trackpad           │
│                                                      │
│      ┌──────────────────────────┐                    │
│      │ ● ● ●   Title Here       │ ← swipe →          │
│      └──────────────────────────┘                    │
│                                                      │
│  Waiting for titlebar swipe…                         │
│                                                      │
│  [ Skip ]                                            │
└──────────────────────────────────────────────────────┘
```

### Step 4 — Done

```
┌──────────────────────────────────────────────────────┐
│  You’re ready                                        │
│                                                      │
│  Sanne lives in the menu bar.                        │
│  Open Preferences anytime to tweak or turn off       │
│  individual gestures.                                │
│                                                      │
│  [ Open Cheat Sheet ]    [ Finish ]                  │
└──────────────────────────────────────────────────────┘
```

---

## 4. Preferences window

**Size:** ~720×520 (resizable, min 640×440)  
**Structure:** leading sidebar + detail (System Settings style)

```
┌────────────────────────────────────────────────────────────────┐
│  Sanne Settings                                      ● ● ●     │
├────────────────┬───────────────────────────────────────────────┤
│                │                                               │
│  ○ Home        │   [ Detail pane for selection ]               │
│  ○ Magic Mouse │                                               │
│  ○ Trackpad    │                                               │
│  ○ Windows     │                                               │
│  ○ Keyboard    │                                               │
│  ○ Apps        │   (Advanced — v1.0)                           │
│  ○ Presets     │                                               │
│  ○ Advanced    │                                               │
│                │                                               │
│                │                                               │
└────────────────┴───────────────────────────────────────────────┘
```

**MVP sidebar:** Home, Magic Mouse, Windows (titlebar), Advanced (minimal).  
**v1.0:** full list.

---

### 4.1 Home

```
┌─────────────────────────────────────────────────────────────┐
│  Home                                                       │
│                                                             │
│  Status                                                     │
│  ● Running · Accessibility granted                          │
│  Devices: Built-in Trackpad · Magic Mouse                   │
│                                                             │
│  [ Pause All Gestures ]                                     │
│                                                             │
│  Quick toggles                                              │
│  ┌─────────────────────────────────────────────────────┐    │
│  │  Magic Mouse tap-to-click                    [ ON ] │    │
│  │  Titlebar window gestures                    [ ON ] │    │
│  │  Dock gestures                               [ ON ] │    │
│  │  Menubar gestures                            [ ON ] │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                             │
│  ⚠ Multitouch.app is running — may conflict                 │
│                                                             │
│  [ Tutorial ]  [ Cheat Sheet ]  [ Reset All Defaults ]      │
└─────────────────────────────────────────────────────────────┘
```

---

### 4.2 Magic Mouse

```
┌─────────────────────────────────────────────────────────────┐
│  Magic Mouse                                                │
│                                                             │
│  Tap to click                                        [ ON ] │
│  “Click” without pressing the mouse down.                   │
│                                                             │
│            ┌──────────────────────┐                         │
│            │   LEFT    │   RIGHT  │  ← live diagram         │
│            │   click   │   click  │                         │
│            │──────────────────────│                         │
│            │    3 fingers = middle│                         │
│            └──────────────────────┘                         │
│                                                             │
│  ☑ Left tap → Primary click                                 │
│  ☑ Right tap → Secondary click                              │
│  ☑ Three-finger touch → Middle click                        │
│  ☑ Double-tap and hold → Drag                               │
│  ☐ Gaming mode (v1.1)                                       │
│                                                             │
│  Sensitivity          ○───────●──────○   Default            │
│  Left / right split   ○────●─────────○   50%                │
│  Dead zone            ○──●───────────○   Narrow             │
│                                                             │
│  Palm rejection       [ Normal ▾ ]                          │
│                                                             │
│  ─ Advanced gestures ───────────────── (v1.0+) ─            │
│  Gesture list table…                                        │
└─────────────────────────────────────────────────────────────┘
```

**Interaction:** hovering a checkbox highlights the region on the diagram.

---

### 4.3 Trackpad (v1.0)

```
┌─────────────────────────────────────────────────────────────┐
│  Trackpad                                                   │
│                                                             │
│  Free-space gestures                                        │
│  (Most multi-finger swipes stay with macOS.)                │
│                                                             │
│  ☑ Three-finger tap → Middle click                          │
│                                                             │
│  Sensitivity          ○───────●──────○                      │
│                                                             │
│  All trackpad rules                           [ Advanced ]  │
│  ┌─────────────────────────────────────────────────────┐    │
│  │ ☑  3-finger tap     Middle click      All Apps  ›  │    │
│  │ … user-added rows …                                 │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                             │
│  [ + Add Gesture ]                                          │
└─────────────────────────────────────────────────────────────┘
```

---

### 4.4 Windows (zones) — Simple view

```
┌─────────────────────────────────────────────────────────────┐
│  Windows                                                    │
│                                                             │
│  Titlebar gestures                                   [ ON ] │
│                                                             │
│      Two fingers on a window’s title bar:                   │
│                                                             │
│                    pinch out → fullscreen                   │
│                          ↑ maximize                         │
│         left half ← swipe   titlebar   swipe → right half   │
│                          ↓ minimize                         │
│                    pinch in → close                         │
│              diagonals → corners (quarters)                 │
│                                                             │
│  ☑ Halves (swipe left / right)                              │
│  ☑ Quarters (diagonal)                                      │
│  ☑ Maximize (swipe up)                                      │
│  ☑ Minimize (swipe down)                                    │
│  ☑ Close (pinch in)                                         │
│  ☑ Fullscreen (pinch out)              // v1.0              │
│  ☑ Thirds (long swipe)                 // v1.0              │
│                                                             │
│  Dock gestures                                       [ ON ] │
│  ☑ Swipe down → Hide app windows                            │
│  ☑ Swipe up → Show / activate                               │
│                                                             │
│  Menubar gestures                                    [ ON ] │
│  ☑ Swipe left / right → Previous / next window              │
│                                                             │
│  Snap preview                                        [ ON ] │
│  Haptic feedback                                     [ ON ] │
│  Window gap           ○●────────────  0 px                  │
│                                                             │
│  [ Show Full Gesture Map ]                                  │
└─────────────────────────────────────────────────────────────┘
```

---

### 4.5 Gesture editor row (Advanced / v1.0)

```
┌──────────────────────────────────────────────────────────────────┐
│ ☑ │ trackpad · titlebar · 2-finger · swipe · right               │
│   │ Action: [ Snap window ▾ ]  Layout: [ Right half ▾ ]          │
│   │ App:    [ All Apps        ▾ ]   Modifiers: [ None ▾ ]        │
│   │ Source: Sanne Standard · Modified              [ Reset ]     │
└──────────────────────────────────────────────────────────────────┘
```

**Add Gesture sheet:**

```
┌──────────────────────────────────────────┐
│  Add Gesture                             │
│                                          │
│  Device   [ Trackpad ▾ ]                 │
│  Zone     [ Titlebar ▾ ]                 │
│  Fingers  [ 2 ▾ ]                        │
│  Type     [ Swipe ▾ ]                    │
│  Direction[ Left ▾ ]                     │
│                                          │
│  — or —                                  │
│  [ Perform gesture to capture… ]         │
│                                          │
│  Action   [ Choose action… ▾ ]           │
│                                          │
│           [ Cancel ]  [ Add ]            │
└──────────────────────────────────────────┘
```

---

### 4.6 Apps (v1.0)

```
┌─────────────────────────────────────────────────────────────┐
│  Apps                                                       │
│                                                             │
│  Overrides for specific applications.                       │
│  More specific rules win over All Apps.                     │
│                                                             │
│  [ + Add Application ]                                      │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐    │
│  │ Safari.app                                        › │    │
│  │   3-finger tap → Close Tab                          │    │
│  │ Visual Studio Code                                › │    │
│  │   3-finger tap → Middle click (default)             │    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

---

### 4.7 Keyboard (v1.0)

```
┌─────────────────────────────────────────────────────────────┐
│  Keyboard                                                   │
│                                                             │
│  Window snapping shortcuts                           [ ON ] │
│  Hold ⌃⌥ and press arrows to snap the focused window.       │
│                                                             │
│     ↑ maximize                                              │
│  ←     →   halves                                           │
│     ↓ restore / minimize (configurable)                     │
│                                                             │
│  Also enable:  ☐ WASD   ☐ IJKL                              │
│                                                             │
│  Hyper key                                           [ OFF ]│
│  Turn a key into Control+Option+Shift+Command.              │
│  Key: [ Right Command ▾ ]                                   │
│                                                             │
│  Move window: hold [ ⌥⌘ ▾ ] and drag                        │
│  Resize window: hold [ ⌃⌘ ▾ ] and drag                      │
└─────────────────────────────────────────────────────────────┘
```

---

### 4.8 Presets

```
┌─────────────────────────────────────────────────────────────┐
│  Presets                                                    │
│                                                             │
│  ● Sanne Standard     Opinionated defaults (recommended)    │
│  ○ Minimal            Taps + halves only                    │
│  ○ Custom             Your modifications                    │
│                                                             │
│  [ Export Configuration… ]  [ Import… ]                     │
│  [ Reset to Sanne Standard ]                                │
└─────────────────────────────────────────────────────────────┘
```

---

### 4.9 Advanced

```
┌─────────────────────────────────────────────────────────────┐
│  Advanced                                                   │
│                                                             │
│  Launch at login                                     [ ON ] │
│  Prefer Sanne over system free-space gestures        [ OFF ]│
│  Avoid private multitouch for trackpad (debug)       [ OFF ]│
│                                                             │
│  Competing apps                                             │
│  Detected: none                                             │
│                                                             │
│  [ Open Debug Overlay ]                                     │
│                                                             │
│  Privacy: Sanne does not send data anywhere.                │
│  License: MIT · Free and open source                        │
│  [ View Source on GitHub ]  [ Report an Issue ]             │
└─────────────────────────────────────────────────────────────┘
```

---

## 5. Snap preview (on-canvas)

```
 Screen
┌────────────────────────────────────────────┐
│ ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ │
│ ░░░░░┌─────────────────┐░░░░░░░░░░░░░░░░░ │
│ ░░░░░│                 │░░░░░░░░░░░░░░░░░ │
│ ░░░░░│  preview fill   │  (target half)  │
│ ░░░░░│  ~25% opacity   │░░░░░░░░░░░░░░░░░ │
│ ░░░░░│                 │░░░░░░░░░░░░░░░░░ │
│ ░░░░░└─────────────────┘░░░░░░░░░░░░░░░░░ │
│ ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ │
└────────────────────────────────────────────┘
```

- Rounded corners matching macOS window radius  
- Appears when swipe exceeds threshold  
- Updates if user continues into long-swipe thirds  
- Disappears on finger lift (commit) or cancel  

---

## 6. Cheat sheet window

```
┌─────────────────────────────────────────────────────────────┐
│  Sanne Gestures                              🔍 Search      │
├─────────────────────────────────────────────────────────────┤
│  TITLEBAR (2 fingers)                                       │
│  Swipe ← →     Snap half                                    │
│  Swipe ↑       Maximize                                     │
│  Swipe ↓       Minimize                                     │
│  Diagonal      Quarter                                      │
│  Pinch in      Close                                        │
│  Pinch out     Fullscreen                                   │
│                                                             │
│  MAGIC MOUSE                                                │
│  Tap left      Click                                        │
│  Tap right     Right-click                                  │
│  3 fingers     Middle-click                                 │
│  Double-tap+hold  Drag                                      │
│                                                             │
│  DOCK / MENUBAR / KEYBOARD …                                │
└─────────────────────────────────────────────────────────────┘
```

---

## 7. Default gesture maps (visual reference)

### 7.1 Titlebar — trackpad (Sanne Standard)

```
                         pinch OUT
                        fullscreen
                            │
                     swipe UP maximize
                            │
     snap LEFT ←──── 2-finger on TITLEBAR ────→ snap RIGHT
                            │
                     swipe DOWN minimize
                            │
                         pinch IN
                           close

     ↖ top-left quarter    top-right quarter ↗
     ↙ bottom-left         bottom-right      ↘

     Long swipe ← →   cycle thirds / two-thirds
     Long swipe ↑     center ~65%
```

### 7.2 Dock icon (v1.0)

```
              swipe UP → activate / unminimize
                    │
              [ App Icon ]
                    │
              swipe DOWN → hide / minimize windows

         pinch OUT → new window (⌘N)
```

### 7.3 Menubar (v1.0)

```
  ← swipe     MENUBAR     swipe →
  prev window             next window

  swipe DOWN → hide others / clear focus
  swipe UP   → reveal / unminimize (optional)
```

### 7.4 Magic Mouse surface

```
  ┌─────────────────────────────────────┐
  │            TOP EDGE                 │
  │   2-finger touch+drag → move win    │
  │   3-finger touch+drag → resize      │
  ├──────────────────┬──────────────────┤
  │                  │                  │
  │   TAP → click    │   TAP → right    │
  │                  │                  │
  │      LEFT        │      RIGHT       │
  │                  │                  │
  ├──────────────────┴──────────────────┤
  │     3-finger touch → middle click   │
  │     double-tap + hold → drag        │
  └─────────────────────────────────────┘
```

### 7.5 Free-space trackpad (Standard — minimal)

```
  3-finger TAP → middle click

  (3/4 finger swipes remain macOS defaults unless user overrides)
```

### 7.6 Keyboard snap (v1.0)

```
  Hold ⌃⌥ +

           ↑  maximize
     ←           →     left / right half
           ↓  restore last frame

  ⌃⌥ + ⌘ + arrows → quarters (optional)
```

---

## 8. Action catalog UI (picker)

Grouped list, searchable:

```
┌─ Choose Action ─────────────────────────┐
│ 🔍 filter                               │
│                                         │
│  WINDOW                                 │
│    Snap left half                       │
│    Snap right half                      │
│    Snap quarter…                        │
│    Maximize                             │
│    Minimize                             │
│    Close                                │
│    Fullscreen                           │
│    Move to next display                 │
│                                         │
│  CLICKS                                 │
│    Left click                           │
│    Right click                          │
│    Middle click                         │
│                                         │
│  SYSTEM                                 │
│    Mission Control                      │
│    App Exposé                           │
│    Show Desktop                         │
│                                         │
│  KEYSTROKE                              │
│    Send shortcut…                       │
│                                         │
│  APP                                    │
│    Launch / activate…                   │
└─────────────────────────────────────────┘
```

---

## 9. Error & empty states

| Case | UI |
|------|-----|
| No Accessibility | Home red banner + button to Settings |
| No Magic Mouse | Magic Mouse pane: “Connect a Magic Mouse to configure taps.” Diagram dimmed |
| Competing app | Yellow banner with app name + “Pause Sanne” / “OK” |
| Gesture failed (fullscreen window) | Brief HUD: “Can’t move fullscreen window” (v1.1; MVP silent) |
| (none — free forever) | No trial or activation modals |

---

## 10. Accessibility & inclusion (product UX)

- All Preferences controls keyboard-navigable  
- VoiceOver labels on gesture diagrams (described textually)  
- Respect Reduce Motion (instant preview, no fade)  
- No color-only status (use text + icon)  
- Minimum hit targets 24×24 in lists  

---

## 11. MVP vs v1.0 UI surface

| Screen | MVP | v1.0 |
|--------|:---:|:----:|
| Menu bar | ✓ | ✓ |
| Onboarding permissions | ✓ | ✓ |
| Tutorial (short) | optional | ✓ |
| Home | ✓ | ✓ |
| Magic Mouse taps | ✓ | ✓ |
| Windows titlebar toggles | ✓ | ✓ |
| Dock / menubar sections | — | ✓ |
| Trackpad free-space | middle-click only | ✓ |
| Keyboard | — | ✓ |
| Apps / per-app | — | ✓ |
| Full rule editor | — | ✓ |
| Presets import/export | reset only | ✓ |
| Cheat sheet | static help | ✓ searchable |
| About / OSS links | ✓ | ✓ |

---

## 12. Copy deck (key strings)

| Context | String |
|---------|--------|
| Promise | “Gestures that feel built into macOS.” |
| MM feature | “Tap to click — no physical press.” |
| Titlebar | “Swipe the title bar to snap windows.” |
| Defaults | “Sanne Standard — change anything later.” |
| Conflict | “Another gesture app is running. Using both can break recognition.” |
| Permission | “Sanne needs Accessibility to move windows. Nothing leaves your Mac.” |

---

*End of UX wireframes*
