# Sanne — Technical Design Document

**Version:** 1.0  
**Status:** Draft  
**Companion to:** [PRD.md](./PRD.md) · [MVP_SCOPE.md](./MVP_SCOPE.md) · [UX_WIREFRAMES.md](./UX_WIREFRAMES.md)  
**Last updated:** 2026-07-31  

---

## 1. Goals of this document

Specify how Sanne is built on macOS:

1. Input pipeline (trackpad + Magic Mouse multi-touch)
2. Gesture recognition & zone routing
3. Window management engine
4. Action execution
5. Configuration & defaults
6. Permissions, process model, reliability
7. Package structure & major modules

This is an implementation blueprint, not product marketing.

---

## 2. Resolved product decisions (from PRD open questions)

| Question | Decision | Rationale |
|----------|----------|-----------|
| Titlebar swipe-up | **Maximize (fill visible frame)** not native fullscreen | Matches Rectangle/Swish muscle memory; pinch-out → native fullscreen |
| Free-space 3/4 finger | **Defer to macOS by default** | Zones are Sanne’s signature; avoid fighting Mission Control |
| Hyper key | **v1: map a non-Caps key or “fn as Hyper” option**; Caps Lock Hyper is P1 via HID/IOKit path | Caps Lock remap is fragile; don’t block MVP |
| Business model | **Free and open source (MIT recommended)** | No license keys, trials, or paid tiers |
| Bundle ID | **`app.sanne.Sanne`** (placeholder until domain confirmed) | Reverse-DNS; update when trademark/domain land |
| UI stack | **AppKit agent + SwiftUI settings** | Overlays/event timing need AppKit; settings faster in SwiftUI |

---

## 3. System overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        Sanne.app (main)                          │
│  ┌──────────────┐  ┌──────────────┐  ┌────────────────────────┐ │
│  │ Menu bar UI  │  │ Preferences  │  │ Onboarding / Tutorial  │ │
│  └──────┬───────┘  └──────┬───────┘  └───────────┬────────────┘ │
│         │                 │                      │              │
│         └─────────────────┼──────────────────────┘              │
│                           ▼                                     │
│                  ┌─────────────────┐                            │
│                  │  AppController  │  lifecycle, pause, perms   │
│                  └────────┬────────┘                            │
│         ┌─────────────────┼─────────────────┐                   │
│         ▼                 ▼                 ▼                   │
│  ┌────────────┐   ┌──────────────┐   ┌─────────────┐            │
│  │ ConfigStore│   │ GestureEngine│   │ActionRunner │            │
│  └────────────┘   └──────┬───────┘   └──────▲──────┘            │
│                          │                  │                   │
│              ┌───────────┴──────────┐       │                   │
│              ▼                      ▼       │                   │
│     ┌────────────────┐    ┌─────────────────┴──┐                │
│     │ TouchInput     │    │ ZoneClassifier     │                │
│     │  (MT / events) │    │ (cursor → zone)    │                │
│     └───────┬────────┘    └────────┬───────────┘                │
│             │                      │                            │
│             ▼                      ▼                            │
│     ┌────────────────────────────────────┐                      │
│     │     WindowManager + SnapPreview    │                      │
│     │  (AX + CGWindow + overlay window)  │                      │
│     └────────────────────────────────────┘                      │
└─────────────────────────────────────────────────────────────────┘
```

**Single process** for v1 (menu bar agent). No XPC helper unless notarization/sandbox later requires it. Prefer simplicity: one binary, one privilege surface (Accessibility).

---

## 4. Process model & lifecycle

### 4.1 App type

- **LSUIElement** (`Application is agent (UIElement)` = YES) — no Dock icon by default
- Optional “Show in Dock when preferences open”
- Launch at login via `SMAppService` (macOS 13+)

### 4.2 States

| State | Behavior |
|-------|----------|
| `needsPermission` | Touch pipeline idle; menu bar badge; open System Settings deep link |
| `running` | Full pipeline active |
| `paused` | Pipeline detached; config retained; hotkey/menu to resume |
| `safeMode` | Launch with held Option: load defaults only, skip user config |

### 4.3 Sleep / wake

Subscribe to:

- `NSWorkspace.willSleepNotification` / `didWakeNotification`
- `NSWorkspace.screensDidSleep/Wake`
- Display reconfigure (`CGDisplayRegisterReconfigurationCallback`)

On wake:

1. Tear down MT device callbacks if stale
2. Re-enumerate multitouch devices
3. Re-verify Accessibility trust (`AXIsProcessTrusted`)
4. Resume gesture recognition after short debounce (100–200 ms)

### 4.4 Competing apps

On launch and periodically (every 60s while running), scan running apps for known bundle IDs:

| App | Bundle ID (typical) |
|-----|---------------------|
| BetterTouchTool | `com.hegenberg.BetterTouchTool` |
| Multitouch | (verify at build time) |
| Swish | (verify) |
| TapToClick | (verify) |
| Middle | (verify) |

Show non-blocking menu bar warning + Preferences banner. Do not force-quit others.

---

## 5. Permissions

| Permission | API | Required for |
|------------|-----|--------------|
| **Accessibility** | `AXIsProcessTrustedWithOptions` | Window move/resize/close, synthetic clicks may need it; zone hit-testing via AX |
| **Input Monitoring** | TCC Input Monitoring | Global key remaps / Hyper (if using event taps on key-down) |

**v1 strategy:**

- **Accessibility is hard-required** before enabling window + gesture features.
- Prefer generating clicks via `CGEvent` post; may still need Accessibility on recent macOS.
- Input Monitoring only requested when user enables Keyboard remaps / Hyper — progressive permission.

**Onboarding flow:** guided UI → open Privacy pane → poll trust until granted → continue tutorial.

---

## 6. Input pipeline

### 6.1 Goals

- Low latency (&lt; 16 ms recognition path for taps when possible)
- Device-aware (trackpad vs Magic Mouse)
- Survives reconnect / Bluetooth drop
- Isolate private API usage behind a protocol

### 6.2 Abstraction

```swift
protocol TouchDeviceSource: AnyObject {
    var deviceKind: DeviceKind { get } // .builtInTrackpad, .magicTrackpad, .magicMouse
    func start(handler: @escaping (TouchFrame) -> Void)
    func stop()
}

struct TouchFrame {
    let timestamp: TimeInterval
    let deviceID: String
    let deviceKind: DeviceKind
    let touches: [TouchPoint]
}

struct TouchPoint {
    let id: Int
    let normalizedPosition: CGPoint  // 0…1 surface coords
    let force: CGFloat?              // if available
    let phase: TouchPhase            // began, moved, stationary, ended, cancelled
    let majorAxis: CGFloat?          // for palm heuristics
    let minorAxis: CGFloat?
}
```

### 6.3 Multitouch acquisition (private API boundary)

Apple does not expose a public multi-touch stream for arbitrary gesture apps. Industry practice (Multitouch, BTT, Middle, TapToClick class of apps):

| Approach | Use |
|----------|-----|
| **MultitouchSupport.framework** (private) | Finger positions on Apple trackpads / Magic Mouse |
| **IOKit HID** | Device connect/disconnect, some button state |
| **CGEvent tap** | Keyboard, mouse buttons, scroll; not full MT fingers |

**Module:** `TouchInput/PrivateMT/`

```
TouchDeviceManager
  ├── MTDeviceEnumerator   // list devices, open/close
  ├── MTFrameDecoder       // normalize raw MT callbacks → TouchFrame
  └── DeviceIdentity       // map to Magic Mouse vs trackpad via product name / VID/PID
```

**Rules:**

1. All private symbols loaded **dynamically** (`dlopen` / `dlsym`) — never hard-link private frameworks if avoidable.
2. Feature flag: `usePrivateMultitouch = true` (default). If load fails → degrade gracefully:
   - Magic Mouse taps **unavailable** (show error)
   - Trackpad zone gestures may fall back to limited path or disable with message
3. Document OS version matrix; test every macOS beta.

### 6.4 Event ordering

```
TouchFrame
    → PalmRejector          // drop / demote broad contacts (Magic Mouse)
    → GestureRecognizer     // state machine per device
    → ZoneClassifier        // enrich with cursor zone at gesture start
    → RuleMatcher           // config rules: device + zone + fingers + modifiers + app
    → ActionRunner          // execute (possibly async window ops)
    → FeedbackService       // haptic + optional HUD
```

**Important:** Capture **cursor position and frontmost app at gesture begin**, not end — avoids wrong zone if user swipes off titlebar.

### 6.5 Modifier keys

Read at recognition time via `NSEvent.modifierFlags` (or HID):

- ⌘ ⌥ ⌃ ⇧ fn  
- Used both as rule constraints and as move/resize activators

### 6.6 Synthetic input (clicks)

```swift
enum SyntheticClick {
    case left, right, middle
    case leftDown, leftUp  // for drag patterns
}

// CGEvent(mouseEventSource:...) at current CGEvent location
// Middle button: .center
```

**Tap-to-click path (Magic Mouse):**

1. Detect short-duration contact in left/right zone under threshold movement
2. PalmRejector passes
3. Suppress or ignore the physical click if any (don’t double-fire)
4. Post `CGEvent` click
5. Light haptic (if Force Touch trackpad is separate; Magic Mouse has no haptic actuator — skip or use audio only if user enabled)

Magic Mouse has **no Taptic Engine** — haptics apply to trackpad Macs only.

---

## 7. Gesture recognition

### 7.1 Design

Deterministic **state machine** per device, not ML.

```
Idle
  → TouchBegan (n fingers)
      → PossibleTap | PossibleSwipe | PossiblePinch | PossibleHold
          → Recognized(gesture) | Failed → Idle
```

### 7.2 Core recognizers (v1)

| Recognizer | Signals |
|------------|---------|
| `TapRecognizer` | n fingers, duration &lt; T, movement &lt; D, all ended |
| `MultiTapRecognizer` | sequential taps within interval (double/triple) |
| `SwipeRecognizer` | n fingers, primary axis displacement &gt; threshold, velocity |
| `DiagonalSwipeRecognizer` | both axes above min; classify UL/UR/DL/DR |
| `PinchRecognizer` | 2-finger distance delta |
| `TouchHoldRecognizer` | n fingers stationary &gt; H |
| `TouchDragRecognizer` | hold then move (window move/resize, tap-drag) |
| `ContinuousSwipeTracker` | after initial swipe, keep tracking for thirds cycling |

### 7.3 Parameters (configurable, with defaults)

Stored per device kind:

| Param | Trackpad default | Magic Mouse default |
|-------|------------------|---------------------|
| Tap max duration | 200 ms | 220 ms |
| Tap max movement | 0.03 norm | 0.04 norm |
| Swipe min distance | 0.08 norm | 0.10 norm |
| Swipe direction lock ratio | 1.5× primary vs secondary | same |
| Pinch min scale delta | 0.12 | N/A or higher |
| Long swipe extra distance | +0.12 after first snap | +0.15 |
| Palm major-axis threshold | — | device-tuned |

Expose a single **Sensitivity** slider (−2…+2) that scales these together; Advanced shows raw values.

### 7.4 Magic Mouse surface zones (tap)

Normalize touch X:

| Region | X range (default) | Meaning |
|--------|-------------------|---------|
| Left | 0.00 – 0.45 | Primary click |
| Dead | 0.45 – 0.55 | Reject ambiguous |
| Right | 0.55 – 1.00 | Secondary click |

User-adjustable split + dead zone width.

### 7.5 Gesture ID schema

Stable IDs for config/defaults:

```
device.zone.fingers.kind.direction

Examples:
  trackpad.titlebar.2.swipe.left
  trackpad.titlebar.2.pinch.in
  mouse.surface.1.tap.left
  mouse.surface.3.touch.middle
  trackpad.free.3.tap
  mouse.top.2.touchdrag.moveWindow
```

---

## 8. Zone classification

### 8.1 Zones

```swift
enum CursorZone: String, Codable {
    case titlebar
    case dock
    case menubar
    case notch          // reserved
    case free           // desktop / window body / elsewhere
}
```

### 8.2 Titlebar detection

Primary path — **Accessibility**:

1. `CGEvent` / `NSEvent.mouseLocation` → screen point  
2. `AXUIElement` system-wide element at position (`AXUIElementCopyElementAtPosition`)  
3. Walk ancestors for role:
   - `AXWindow` + subrole/title bar region  
   - Heuristic: Y within top ~40–52 pt of window frame (scaled for display) AND element is window or title UI  

Fallback if AX fails:

- `CGWindowListCopyWindowInfo` topmost window under point  
- Treat top strip of that window bounds as titlebar  

### 8.3 Dock detection

- Prefer AX role `AXDockItem` / Dock application element  
- Fallback: Dock frame via `NSScreen` visibleFrame vs frame (bottom/left/right Dock orientation) + icon grid approximation  

Need **which app** under cursor for Dock gestures:

- AX title / `AXURL` / bundle id if available  
- Fallback: running apps order (weaker)

### 8.4 Menubar

- Point.y in menubar band of the screen containing cursor  
- Exclude status item deep hit-testing for v1 (treat whole menubar as zone)

### 8.5 Caching

- Cache last zone + window AX element for ~50 ms while fingers down  
- Invalidate on display change  

---

## 9. Rule matching & config model

### 9.1 Config schema (conceptual)

```json
{
  "version": 1,
  "presetId": "sanne.standard",
  "sensitivity": { "trackpad": 0, "magicMouse": 0 },
  "magicMouseTaps": {
    "enabled": true,
    "leftTap": true,
    "rightTap": true,
    "middleThreeFinger": true,
    "tapDrag": true,
    "gamingMode": false,
    "leftRightSplit": 0.5,
    "deadZone": 0.1
  },
  "rules": [
    {
      "id": "uuid",
      "enabled": true,
      "source": "default",
      "gesture": "trackpad.titlebar.2.swipe.right",
      "appBundleId": null,
      "requiredModifiers": [],
      "actions": [
        { "type": "window.snap", "params": { "layout": "rightHalf" } }
      ]
    }
  ],
  "keyboard": {
    "hyperKey": null,
    "snapWithArrows": true
  },
  "window": {
    "gap": 0,
    "restoreOnRepeat": true,
    "animate": true
  }
}
```

**Storage:**

- `~/Library/Application Support/Sanne/config.json`
- Atomic write (temp + replace)
- Defaults embedded in app bundle: `Presets/sanne.standard.json`

### 9.2 Matching algorithm

Given `RecognizedGesture G` + context `(zone, app, modifiers, device)`:

1. Filter rules where `enabled` and gesture ID matches (or pattern match)
2. Filter by `appBundleId` (specific rules beat `null` global)
3. Filter by required modifiers (exact or “at least these”)
4. Prefer higher specificity: app-specific &gt; global; more modifiers &gt; fewer
5. First action list wins (v1: no parallel multi-rule fire for same gesture)

### 9.3 Conflict with system gestures

For free-space multi-finger swipes that macOS also uses:

- **Standard preset:** no rules that steal 3/4 finger free-space system gestures  
- If user adds conflicting rule → UI warning: “May conflict with Mission Control”  
- Optional advanced: “Prefer Sanne over system” (document that system may still win for some gestures)

Zone gestures (titlebar/Dock/menubar) generally **do not** conflict with Mission Control.

---

## 10. Window management engine

### 10.1 Responsibilities

- Resolve target window (under cursor / focused)
- Read current frame
- Compute target frames for layouts
- Apply move/resize via Accessibility
- Maintain restore stack
- Drive snap preview overlay

### 10.2 Target window

| Mode | Selection |
|------|-----------|
| Zone titlebar gesture | Window under cursor (titlebar) |
| Keyboard snap | Focused window (`AXFocusedUIElement` → window) |
| Dock gesture | App’s main/normal windows |
| Move/resize drag | Window under cursor at drag start |

Skip:

- Fullscreen spaces windows (limited AX) — show HUD “Can’t move fullscreen window”
- System UI (Notification Center, loginwindow)

### 10.3 Layout geometry

```swift
enum Layout: String, Codable {
    case leftHalf, rightHalf, topHalf, bottomHalf
    case topLeft, topRight, bottomLeft, bottomRight
    case leftThird, centerThird, rightThird
    case leftTwoThirds, rightTwoThirds
    case maximize          // visible frame fill
    case almostMaximize    // inset by gap
    case center
    case centerLarge       // ~65% width/height centered
    case restore
}

func targetFrame(layout: Layout, screen: NSScreen, gap: CGFloat) -> CGRect
```

**Screen:** use the screen containing the window’s center (or cursor for multi-display moves).

**Visible frame:** `screen.visibleFrame` (respects Dock + menu bar).

**Multi-display move:** order screens by `frame.origin` (physical arrangement via `CGDisplayBounds`).

**Spaces move:** v1.0 uses public/private mix carefully:

- Prefer `CGWindow` + Spaces APIs used by Rectangle/Swish class tools  
- If unreliable on a given OS, gate Spaces gestures behind “Experimental” until stable  
- MVP can ship **display move** without Spaces move if Spaces API proves flaky

### 10.4 Applying frames

```
AXUIElementSetAttributeValue(window, kAXPositionAttribute, point)
AXUIElementSetAttributeValue(window, kAXSizeAttribute, size)
```

Order: often set position then size (or size then position) — test per OS; some apps need both twice.

**Animations:** optional short `NSAnimationContext` only on preview overlay; actual AX sets are instant (OS may animate).

### 10.5 Restore stack

Per window identity (`CGWindowNumber` + pid + creation heuristic):

```
lastUnsnappedFrame: CGRect?
lastLayout: Layout?
```

- First snap stores pre-snap frame  
- Second same layout or “restore” action → original frame  
- Swipe-down minimize uses standard `AXMinimizeButton` press or `kAXMinimizedAttribute`

### 10.6 Close / fullscreen

| Action | Mechanism |
|--------|-----------|
| Close | Press `AXCloseButton` or `⌘W` to app |
| Quit (deep pinch) | `NSRunningApplication.terminate` / force confirm if dirty is OS-handled |
| Minimize | `AXMinimizeButton` or attribute |
| Native fullscreen | `AXFullScreen` attribute (where supported) or green button with Option semantics |

### 10.7 Snap preview overlay

- Borderless, ignore-mouse, always-on-top `NSWindow` at `.screenSaver` or high window level  
- Draws rounded rect of **target** frame with 20–30% fill + border (vibrancy if possible)  
- Shown when swipe passes recognition threshold; updated if continuous swipe cycles layout  
- Removed on fingers-up (commit) or cancel  

**Performance:** single shared overlay window; reposition/resize only.

### 10.8 Modifier move / resize

| Mode | Activation | Behavior |
|------|------------|----------|
| Move | Configurable modifiers held + mouse move (or MM multi-finger touch) | Window follows delta |
| Resize | Different modifier combo | Resize from nearest corner/edge to cursor |

Implementation: on activation, capture window + start point; on mouse moved, apply AX position/size; on modifier release or gesture end, stop.

Use local `CGEvent` tap or `NSEvent.addGlobalMonitorForEvents` for mouse moved while active.

---

## 11. Action runner

### 11.1 Action protocol

```swift
protocol Action {
    func run(context: ActionContext) async throws
}

struct ActionContext {
    let cursor: CGPoint
    let zone: CursorZone
    let sourceGesture: GestureID
    let targetWindow: AXWindow?
    let targetApp: NSRunningApplication?
    let device: DeviceKind
}
```

### 11.2 Built-in actions (v1 modules)

| Type | Module |
|------|--------|
| `window.*` | WindowManager |
| `input.click` / `input.keystroke` | InputSynthesizer |
| `system.missionControl` etc. | SystemActions (distributed notifications / hotkey simulation) |
| `app.launch` / `app.activate` | NSWorkspace |
| `browser.*` | Keystroke presets (⌘T, ⌘W, ⌃⇥) scoped when front app is browser |
| `feedback.haptic` | NSHapticFeedbackManager |
| `feedback.hud` | HUDWindow |
| `script.shell` / `script.appleScript` | v1.x sandboxed runner |

### 11.3 Sequencing

Rules may list 1…N actions; run **serially**. Stop on hard failure; log soft failures.

---

## 12. Haptics & HUD

### 12.1 Haptics

- `NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)`  
- Only on devices with trackpad haptics  
- Respect “Reduce motion” / user toggle “Haptic feedback”

### 12.2 HUD (v1.x / optional P1)

- Center-bottom bezel style (volume-like)  
- Icon + short label (“Right Half”)  
- Auto-dismiss 0.6s  

MVP can ship **preview overlay only** without text HUD.

---

## 13. Magic Mouse tap subsystem (detail)

Dedicated module — high risk, high value.

```
MagicMouseTapController
  ├── ZoneModel (left/dead/right)
  ├── TapStateMachine
  ├── PalmRejector
  ├── DragSession (double-tap-hold)
  └── ClickEmitter
```

### 13.1 Palm rejection heuristics

Drop touches when:

- `majorAxis` large relative to typical fingertip  
- Contact area grows quickly without lift (resting palm)  
- &gt; 3 large contacts that aren’t a deliberate 3-finger middle-click chord  

Tune empirically on Magic Mouse 2/3.

### 13.2 Tap-drag

1. First tap ends (click may fire — or suppress if within double-tap window)  
2. Second tap begins within 300 ms  
3. Second tap held &gt; 150 ms without lift  
4. Enter drag: `leftDown` at cursor; subsequent movement is OS drag  
5. On lift: `leftUp`

### 13.3 Gaming mode (P1)

While physical right button held (HID secondary):

- Left-zone taps emit left clicks without releasing right  
- Requires reliable secondary-down detection via HID or CGEvent

### 13.4 Conflict with physical click

If user physically clicks while taps enabled:

- Physical click still works  
- Avoid double-click: if physical click detected within 30 ms of synthetic, suppress one  

---

## 14. Keyboard module

### 14.1 Shortcuts

- Register via `NSEvent` global monitor or `CGEvent` tap  
- Local shortcuts inside Preferences use standard SwiftUI/AppKit  

### 14.2 Arrow / WASD snap

When enabled and focus not in text field (heuristic: AX focused role not text area — imperfect):

- ⌃⌥ + arrows → halves (example binding — finalize in UX)  
- Or match Swish: dedicated modifier set in Advanced  

**Safer v1:** only fire snap shortcuts when modifiers match configured chord (never bare arrows).

### 14.3 Hyper key

**v1:** user picks a key (e.g. Right ⌘) to act as Hyper via event tap rewrite.  
**P1:** Caps Lock → Hyper via IOKit keyboard rebind (document SIP/security implications).

---

## 15. Package / module map

```
Sanne/
  App/
    AppDelegate.swift
    AppController.swift
    MenuBarController.swift
    Onboarding/
  TouchInput/
    TouchDeviceManager.swift
    TouchFrame.swift
    PrivateMT/          // isolated, well-commented
    PalmRejector.swift
  Gestures/
    GestureEngine.swift
    Recognizers/
    GestureID.swift
  Zones/
    ZoneClassifier.swift
    AXHitTester.swift
  Windowing/
    WindowManager.swift
    LayoutGeometry.swift
    SnapPreviewWindow.swift
    RestoreStore.swift
  Actions/
    ActionRunner.swift
    Actions/
  Config/
    ConfigStore.swift
    Models/
    Presets/sanne.standard.json
  InputSynth/
    ClickEmitter.swift
    KeystrokeEmitter.swift
  Keyboard/
    ShortcutMonitor.swift
    HyperKeyController.swift
  Feedback/
    Haptics.swift
    HUD.swift
  UI/
    Preferences/        // SwiftUI
    Tutorial/
  Utilities/
    Permissions.swift
    CompetingApps.swift
    Logging.swift
```

**Language:** Swift 5.9+  
**Min OS:** macOS 13  
**Dependencies:** prefer **zero** SPM deps for core; optional Sparkle (or GitHub Releases check) for updates.  
**License file:** root `LICENSE` (MIT). All contributions under the same terms (`CONTRIBUTING.md`).

---

## 16. Threading model

| Work | Thread |
|------|--------|
| MT callbacks | MT thread → hop to serial `pipeline` queue |
| Gesture state machines | `pipeline` serial queue |
| AX / UI / NSWindow | Main thread |
| Config disk IO | Cooperative background; apply on main |

Never call AX from MT callback thread directly.

```
MT → pipeline.async { recognize → match }
                 → MainActor { run actions / preview }
```

---

## 17. Logging & debugging

- `os.Logger` subsystem `app.sanne`  
- Categories: `touch`, `gesture`, `zone`, `window`, `config`  
- Debug menu (hidden, Option+click menu bar):  
  - Show current zone  
  - Show last gesture  
  - Flash titlebar hit region  
  - Dump devices  

No network logging in v1.

---

## 18. Testing strategy

### 18.1 Unit tests

- `LayoutGeometry` pure functions (screens, gaps, thirds)  
- Gesture ID parsing  
- RuleMatcher specificity  
- PalmRejector synthetic frames  
- Config migration versioning  

### 18.2 Integration (manual / scripted)

- Device matrix: MBP built-in, Magic Trackpad, Magic Mouse 2/3  
- Multi-monitor arrangements  
- Sleep/wake 50× stress  
- Apps: Safari, Chrome, Terminal, Xcode, Electron (Slack, VS Code), fullscreen  

### 18.3 Performance

- Idle: &lt; 1% CPU, &lt; 50 MB RSS  
- During swipe: no main-thread hitch &gt; 20 ms  

---

## 19. Security, notarization & open source release

- Hardened Runtime enabled  
- Exceptions only as required for Accessibility automation  
- Maintainers may **notarize + staple** release artifacts so Gatekeeper is happy — source remains public  
- No App Store (sandbox blocks required APIs)  
- Optional auto-update via Sparkle (EdDSA) or “check GitHub Releases”  
- CI (GitHub Actions): build, unit tests, attach unsigned artifacts on PRs; signed/notarized builds from maintainer secrets on tag  
- Never commit signing certificates or Apple API keys; use CI secrets only  
- `PRIVATE API` usage (MultitouchSupport) documented in-repo; dynamic load only  

---

## 20. Risks (technical)

| Risk | Mitigation |
|------|------------|
| MultitouchSupport breaks on OS update | Dynamic load; rapid patch; beta testing program |
| AX brittle on Electron apps | Fallbacks; test matrix; user “use focused window” option |
| Gesture latency / jank | Serial pipeline; avoid AX on every touch move (only on recognize + preview throttle 60 Hz) |
| Double-click with tap + physical | Debounce logic |
| Spaces API private/unstable | Feature-flag Spaces; ship display-move first |

---

## 21. Implementation sequence (engineering)

Aligned with [MVP_SCOPE.md](./MVP_SCOPE.md):

1. App skeleton + permissions + menu bar  
2. LayoutGeometry + WindowManager snap (keyboard-triggered)  
3. Snap preview overlay  
4. ZoneClassifier titlebar  
5. Private MT pipeline + 2-finger swipe recognizer  
6. Wire titlebar swipes → snap  
7. Magic Mouse tap left/right  
8. Middle-click + tap-drag  
9. Dock/menubar zones  
10. Config + defaults + toggles  
11. Customization UI  
12. Polish: wake, conflicts, tutorial  

---

## 22. Out of scope for this design (explicit)

- XPC privilege separation  
- Cloud sync  
- Plugin API  
- Non-Apple trackpads  
- Drawing gestures  
- Floating menu builder  

---

*End of technical design*
