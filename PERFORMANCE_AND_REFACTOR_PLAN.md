# Sanne — Performance & Refactor Plan

**Status:** A–E landed in-tree (2026-08-14). A.1 Instruments traces are a local hardware gate (skipped here). F optional; G parked.  
**Created:** 2026-08-14  
This file owns the remaining work after the 0.2.0 product surface landed:

1. **Latency and CPU** on the Magic Mouse / trackpad / window-move hot paths.
2. **Large-scale refactors** that are still unfinished or newly justified by those hot paths.

Hardware QA on a real trackpad + Magic Mouse is still the 1.0 gate. Do not block a 1.0 cut on Phase E/F of this document. Phases A–C are the ones that can make taps and snaps *feel* faster; D finishes leftover architecture; E–F are maintainability.

Living document. Flip step statuses as work lands. Do not record a step as done on reasoning alone — put the evidence in the step’s **Verify** line.

---

## Status legend

| Mark | Meaning |
|------|---------|
| ⬜ | Not started |
| 🟡 | In progress |
| ✅ | Done / verified |
| ➖ | Skipped on purpose (note why) |

---

## How to use this file

1. Work **one phase at a time**, in order. Later phases assume earlier ones (especially A → B → C).
2. Inside a phase, steps are ordered by risk. A step may say it can ship independently — that is for PRs, not for skipping the measurement baseline.
3. Each step has **files**, **do this**, and **verify**. The verify line is the definition of done.
4. After a code step: `swift build` (zero warnings) and `swift test` must stay green.
5. Hardware checks run from `dist/Sanne.app` (`./scripts/package-app.sh`), never the raw `swift run` binary. Accessibility identity differs.
6. **Do not mix this work with new product features.** If a step starts growing Hyper / grids / extra Settings tabs, stop.

---

## Diagnosis (why this plan exists)

Sanne’s engines already work. The remaining cost is not “we need a new architecture.” It is that the **recognition path still does work a 100 Hz Multitouch callback cannot afford**, and a few planned splits were marked done while the files stayed large.

### What a Magic Mouse tap does today

```
MultitouchSupport callback (private thread)
  → copy entire SanneConfig snapshot          MagicMouseTapController.handle
  → BindingResolver.resolve (1–N times)       slotOn / dragSlotEnabled
  → Date() + CGEvent(source:) per frame
  → Log.debug on first 40 frames + every begin/cancel
       → DateFormatter + fputs + fflush(stdout)
       → file write
       → os.Logger
       → DispatchQueue.main.async { lines = full 4000-line copy }
  → on commit: DispatchQueue.main.async / Task { @MainActor in
       BindingResolver again → ActionRunner → ClickEmitter / AX }
```

A trackpad swipe is worse on the main thread:

```
MT callback
  → allocate [TouchPoint] + Date() + TouchFrame
  → pipeline.async
  → DispatchQueue.main.async                    GestureEngine.start listener
  → handleOnMain (zone, recognizers, preview)
       titlebar preview: BindingResolver + AX frame + setFrame of overlay
```

### Measured-from-code findings

These are static. Phase A turns them into Instruments numbers. Do not skip A.

| # | Finding | Where | Why it hurts |
|---|---------|-------|----------------|
| 1 | Every `Log.*` hops to the main actor with a **full ring copy** (up to 4,000 lines), plus `fflush(stdout)` on the calling thread | `Utilities/Logging.swift` `append` | MT callback + first 40 frames + every cancel logs. This is the single largest CPU leak. |
| 2 | `logEveryTouchFrame` defaults to `true` and is **never read** by the recognition path | `Logging.swift` L49, `DebugLogView.swift` | Dead toggle. The real “log every frame” is hardcoded `n <= 40` / `n <= 15`. |
| 3 | Every trackpad frame hops **pipeline → main** | `GestureEngine.swift` L59–62 | Recognition, zone classification, and preview all run on the UI thread at ~100 Hz while fingers are down. |
| 4 | Every Magic Mouse frame copies the **entire** `SanneConfig` | `MagicMouseTapController.swift` L422–423 | Large struct (overrides, app maps, custom actions). Then `slotOn` calls `BindingResolver` again. |
| 5 | `BindingResolver.resolve` is called **per slot check, per frame**, not from a snapshot | `slotOn`, `dragSlotEnabled`, `handleFreeSpaceThreeFinger` | Phase 2.3 asked for a snapshot of enabled slot IDs. Recognition still re-resolves. |
| 6 | `WindowManager.setFrame` writes **size, pos, size, pos** (4 AX calls) every time | `WindowManager.swift` L354–364 | `WindowMover.update` and `ModifierDragController.updateDrag` call this on every mouse-moved event. |
| 7 | Snap preview `setFrame` + `needsDisplay` on every swipe preview frame, even if the rect is unchanged | `SnapPreviewWindow.swift` L28–29, `applyTitlebar` | Titlebar swipe at 100 Hz redraws an identical overlay. |
| 8 | `ConfigStore.update` encodes **pretty-printed JSON to disk** on every toggle | `ConfigStore.swift` L105–110 | Settings Simple rows write on each click. Disk + `@Published` rebuild of the whole Settings tree. |
| 9 | 2 Hz timer walks **all running apps** and **the entire HID registry** | `AppController.swift` L71–77, `IOKitHints.applePointers` | AX trust + conflicts + devices. Fine at 2 Hz, but HID matching is not free and is the wrong API for connect/disconnect. |
| 10 | `DateFormatter` in `Log.append` is used from the Multitouch thread | `Logging.swift` L38–40, L85 | `DateFormatter` is not thread-safe. |
| 11 | `CGEvent(source: nil)` to read the cursor on every MM frame | `MagicMouseTapController.swift` L541, L715 | Allocates an event just to read `location`. |
| 12 | Modifier-drag still has its **own** move/resize session, copied from `WindowMover` | `ModifierDragController.swift` L137–185 vs `WindowMover.swift` L62–95 | Phase 3.4 said one mover. Two copies will drift (already have separate `EdgeSet` types). |
| 13 | `MagicMouseTapController` is still **1,234 lines** | `TouchInput/MagicMouseTapController.swift` | Phase 3.2 extracted `ScrollLock` / `PhysicalClickGuard` / `MMThresholds`. The tap / swipe / drag / window-move machines are still inlined. |
| 14 | Two independent `createDeviceList()` + register loops | `TouchDeviceManager` + `MagicMouseTapController.start` | Same private-API walk twice on launch and on every wake rebind. |
| 15 | `enableLegacyGate` still writes the ~40 bools from the editor | `GestureBinding.swift` L174, `GestureEditorView.swift` L569 | Phase 2.4 is half-done: recognition reads slots; the model and editor still keep the bools in sync. |
| 16 | `TouchWindowMover` is a 25-line pass-through | `Windowing/TouchWindowMover.swift` | Dead wrapper around `WindowMover`. |
| 17 | `ModifierDragController` hops every mouse event through `Task { @MainActor in }` | L46–47 | Extra hop on a path that is already on a system callback. |
| 18 | Settings observes the whole `ConfigStore`; any keystroke in a sheet republishes | `PreferencesView` + pages | Not a tap-latency issue. It is why Settings stutters when remapping. |

### What is already fine

Do not “improve” these while executing this plan:

- BindingResolver layering (app → global → preset). Correct. Cache it; do not redesign it.
- Free-space arbitration (drag > swipe > tap; peak fingers sticky).
- Travel-vs-tap split for Magic Mouse 3F swipe vs middle-click.
- HUD generation token / non-activating panel.
- Script timeout (10 s) and concurrency cap (4).
- `ClickEmitter.click` / `KeyEmitter` already sleep on their own queues.
- Config snapshot so the Multitouch thread does not hop to MainActor to *read* settings (the snapshot exists; it is just too fat).
- Off-by-default for free-space 3F/4F, tip-tap, Magic Mouse 3F swipes.

---

## Principles

1. **Measure before and after.** Phase A is not optional. A “faster” refactor that Instruments cannot see is a rewrite.
2. **The Multitouch callback may allocate almost nothing.** No `Date()`, no `String` interpolation, no `Log.debug`, no `SanneConfig` copy, no `BindingResolver`, no main-queue hop — unless a gesture actually commits or a session starts.
3. **Hop to main only for AppKit / AX / HUD / clicks.** Recognition is pure. Preview and `setFrame` are the exceptions, and they must be rate-limited.
4. **One enablement snapshot per (config, frontmost app).** Lookups are `Set.contains`, not `resolve`.
5. **Delete leftover dual paths** (legacy bools, second window mover, second device enumerator, `TouchWindowMover`). Do not add a third.
6. **No protocols for a single implementation.** A `TouchDeviceSource` protocol stays parked until there is a second source.
7. **One PR per step.** Revert must be obvious.

---

## Suggested calendar (one person)

| Days | Work |
|------|------|
| 0.5 | Phase A — Instruments baseline + counters |
| 1–2 | Phase B — log, snapshot, setFrame, preview, config coalesce, poll |
| 2–3 | Phase C — recognition off main |
| 2–3 | Phase D — leftover architecture (2.4 bools, MM machines, one mover, one enumerator) |
| 1–2 | Phase E — file splits (only after D) |
| 1 | Phase F — Settings publish isolation (only if Settings feels slow) |
| — | Phase G — only if Instruments still shows a hotspot |

That is roughly one focused week for A–C (user-visible smoothness) plus one week for D. E–F are optional before 1.0.

---

## Phase A — Measure first ✅

**Goal:** A before-number for tap-to-click, titlebar swipe preview, and idle CPU. Without this, later “wins” are stories.

No product behaviour change.

---

### A.1 Instruments baseline ➖

Skipped in this execution: needs a local Instruments attach to `dist/Sanne.app` plus Magic Mouse / trackpad. A.2 counters are the in-process substitute. Re-run this step on hardware before calling 1.0 tap/swipe feel done.

**Do this**

1. Build `dist/Sanne.app` (`./scripts/package-app.sh`).
2. Instruments → Time Profiler + Allocations, attach to Sanne.
3. Record three 20-second traces, same machine, same mouse/trackpad:
   - **Idle:** Sanne running, no fingers, Settings closed.
   - **Tap:** 20 Magic Mouse left taps.
   - **Swipe:** 10 titlebar half-swipes with preview on.
   - **Drag:** 5 modifier-drag moves across a window.
4. Save traces under `artifacts/instruments/` (gitignored is fine). Write the numbers into the table below.

**Record**

| Scenario | CPU % (avg) | Main thread % | Allocations / s | Notes |
|----------|-------------|---------------|-----------------|-------|
| Idle | | | | |
| MM taps | | | | |
| Titlebar swipe | | | | |
| Modifier-drag | | | | |

Also note the top 5 symbols in each trace. Expect `LogRing.append`, `fflush`, `JSONEncoder`, `AXUIElementSetAttributeValue`, `DispatchQueue.main` in the first cut.

**Verify**

- Four traces exist and the table has numbers. No code change required.

---

### A.2 In-process counters ✅

**Verify:** `PerfCounters` increments at MM/trackpad callbacks, `MainHop`, `BindingResolver`, `setFrame`, `Log.append`. Debug Log shows `mm=… tp=… main=… copies=… resolve=… ax=… log=…` plus Reset. `swift test` 114/114.

Cheap, permanent. Lets later steps prove themselves without re-opening Instruments every time.

**Files**

- `Sources/Sanne/Utilities/Logging.swift` (or a new `Sources/Sanne/Utilities/PerfCounters.swift`)
- `Sources/Sanne/TouchInput/MagicMouseTapController.swift`
- `Sources/Sanne/Gestures/GestureEngine.swift`
- `Sources/Sanne/Windowing/WindowManager.swift`
- Settings → Advanced → Debug Log (one readout line)

**Do this**

1. Add a small `PerfCounters` with atomic / locked integers:
   - `mmCallbacks`
   - `trackpadCallbacks`
   - `mainHops`
   - `configCopies`
   - `bindingResolves`
   - `axSetFrame`
   - `logAppends`
2. Increment at the existing call sites. Do not add new work beyond `OSAtomic` / `OSAllocatedUnfairLock`.
3. Show a single monospaced line on Debug Log: `mm=… tp=… main=… resolve=… ax=… log=…` and a **Reset** button.
4. Do **not** log these to the file every frame.

**Verify**

- 10 Magic Mouse taps with Settings closed: `mmCallbacks` rises, `logAppends` is small (today it will be large — that is the point).
- One titlebar swipe: `trackpadCallbacks` ≈ frames, `axSetFrame` is currently high (preview + commits).
- `swift test` unchanged. Counters are debug-only; no tests required beyond “the type compiles.”

---

## Phase B — Cheap, high-ROI performance ✅

**Goal:** Cut idle/tap CPU without moving recognition off the main thread yet. Each step is an independently shippable PR. Re-run the A.1 idle + tap traces after B.1 and after B.3.

---

### B.1 Log pipeline ✅

**Verify:** Default level `.info`; `Log.debug` is a no-op unless Debug Log is visible or `UserDefaults.debugLogging` is on. No `fflush`. Ring publishes at 10 Hz only while subscribed. File timestamps formatted on `app.sanne.log.file`. `logEveryTouchFrame` defaults off and is rate-limited to 20 Hz.

Highest ROI in the repo. Do this first.

**Files**

- `Sources/Sanne/Utilities/Logging.swift`
- `Sources/Sanne/UI/Preferences/DebugLogView.swift`
- `Sources/Sanne/TouchInput/MagicMouseTapController.swift`
- `Sources/Sanne/TouchInput/TouchDeviceManager.swift`
- `Sources/Sanne/Gestures/GestureEngine.swift`

**Do this**

1. **Default level is `.info`.** `Log.debug` and `Log.trace` are no-ops unless Debug Log is open *or* a `SanneConfig` / `UserDefaults` flag `debugLogging` is on.
2. **Never `fflush(stdout)`** on the hot path. Drop stdout entirely in a packaged `.app`; keep it only when `isatty(STDOUT_FILENO)`.
3. **Do not copy the whole ring onto the main actor on every line.** Keep the buffer behind the lock. Publish to SwiftUI at most 10 Hz, and only while `DebugLogView` is visible (a `subscriberCount` or `isObserved` flag).
4. Publish a **delta** (or replace `lines` from a cached snapshot) — never `self.lines = Array(4000)` per append.
5. Format timestamps on the file queue with `strftime` / a thread-local formatter, not a shared `DateFormatter` from the MT thread.
6. Delete or actually wire `logEveryTouchFrame`:
   - Default **off**.
   - When off: delete the `n <= 40` / `n <= 15` per-callback `Log.debug` in MM and trackpad.
   - When on: log at most 20 Hz, and only if debug logging is on.
7. Gesture-begin `Log.info` stays (one line per session). Cancel / lift debug lines become `.debug`.

**Verify**

- Debug Log closed, 20 taps: `logAppends` per tap is 1–3 (begin + click posted), not tens. **Counters.**
- Idle 20 s: `logAppends` ≈ 0 after startup. **Counters + Instruments idle CPU drops.**
- Debug Log open + “Every touch frame” on: frames appear, UI stays scrollable, no hitch on each line.
- `DateFormatter` is no longer touched from the Multitouch callback. **Code read.**
- `swift test` green.

---

### B.2 Fat-config snapshot → slim runtime snapshot ✅

**Verify:** `RuntimeSnapshotTests` — snapshot matches `BindingResolver` for every slot and two frontmost bundle ids. Recognition copies `RuntimeSnapshot`, not `SanneConfig`. Remaps apply on the next gesture after an app switch.

**Files**

- `Sources/Sanne/TouchInput/MagicMouseTapController.swift`
- `Sources/Sanne/Gestures/GestureEngine.swift`
- New: `Sources/Sanne/Gestures/RuntimeSnapshot.swift`

**Do this**

1. Introduce an immutable `RuntimeSnapshot` (or `EnabledSlots`) rebuilt only when:
   - `sanneConfigDidChange` fires, or
   - the frontmost bundle id changes (subscribe to `NSWorkspace.didActivateApplicationNotification`).
2. Contents:
   - `enabled: Set<String>` — `config.enabledSlotIds(frontmostBundleId:)`
   - `actions: [String: String]` — slot id → resolved action id (only for enabled slots, or all; ~54 entries)
   - `masters` — the four booleans + keyboard + `multiClick` + sensitivity / split / dead zone / gap / haptics / hud / gamingMode
   - `paused` / per-scope pause bits
3. Magic Mouse `handle` reads **this** under the lock, not `SanneConfig`.
4. `slotOn` becomes `snapshot.enabled.contains(id)`.
5. `dragSlotEnabled` / `resolvedDrag` read the snapshot; they must not call `NSWorkspace.shared.frontmostApplication` on the MT thread.
6. Keep a `SanneConfig` copy only for commit-time `ActionRunner` context if you still need `customActions`. Prefer putting `gap` / `haptics` / `hud` on the slim snapshot so the fat copy dies.

**Verify**

- `configCopies` on 20 taps is 0 (or 1 if an app switch happened). **Counters.**
- `bindingResolves` during a tap session is 0. Resolves happen only when the snapshot is rebuilt. **Counters.**
- Remap left tap → right-click, tap: still right-clicks. **Hardware or existing resolver tests + one new snapshot test.**
- Frontmost-app remap still applies on the *next* gesture after the switch, not mid-contact. Document that (it is the same as today’s “resolve at begin / at commit” intent).
- New tests in `BindingResolverTests` or `RuntimeSnapshotTests`: snapshot matches `BindingResolver` for every slot, two frontmost bundle ids.

---

### B.3 Enabled-slot snapshot is the only recognition gate ✅

**Verify:** `BindingResolver.resolve` under `TouchInput/` and `Gestures/` is only `RuntimeSnapshot.build`. `testEmitMatrixMatchesResolverForEverySlot` green.

Depends on B.2. Recognition should consult the snapshot, not re-resolve every frame.

**Files**

- `Sources/Sanne/TouchInput/MagicMouseTapController.swift`
- `Sources/Sanne/Gestures/GestureEngine.swift`
- `Sources/Sanne/Gestures/Recognizers/*.swift` (only if they still peek at config bools)

**Do this**

1. Grep for `BindingResolver.resolve` under `TouchInput/` and `Gestures/` (except commit / `runSlot`). Those call sites must disappear.
2. `handleFreeSpaceThreeFinger` reads `snapshot.enabled.contains(GestureSlots.ID.free3Drag)` instead of resolving every frame.
3. `runSlot` / `handleMagicMouse` may still resolve **once at commit** if you need the action id — or read `snapshot.actions[id]`. Prefer the snapshot.

**Verify**

- `rg "BindingResolver.resolve" Sources/Sanne/TouchInput Sources/Sanne/Gestures` shows only commit helpers or is empty.
- Existing `testEmitMatrixMatchesResolverForEverySlot` still green.
- Toggling a Simple row off still stops that gesture. Master off still stops the group.

---

### B.4 `setFrame` writes less ✅

**Verify:** `AXFrameWriteTests` — live skip when rect unchanged; move writes position only. Snap / restore still use `.commit`. Hardware Safari/Terminal not run in this session.

**Files**

- `Sources/Sanne/Windowing/WindowManager.swift`
- `Sources/Sanne/Windowing/WindowMover.swift`
- `Sources/Sanne/Windowing/ModifierDragController.swift` (until D.3 deletes its copy)

**Do this**

1. Keep the size-then-position-then-repeat sequence for **discrete snaps** (some apps need it). That is a commit, not a 100 Hz path.
2. Add `setFrameLive(_:_:)` (or a `mode: .commit / .live` parameter):
   - Skip if the new rect is within 0.5 pt of the last written rect for that `AXUIElement`.
   - Write **position only** for moves; **size + position once** for resize. No double-write.
3. `WindowMover.update` and modifier-drag live path use `.live`.
4. Snap / restore / display-throw use `.commit`.

**Verify**

- Modifier-drag a window for 2 s: `axSetFrame` is on the order of display refresh (≤ 120), not 4× mouse events. **Counters.**
- Discrete snap of Safari / Terminal / an Electron app still sticks. **Hardware; at least Safari + Terminal before calling this done.**
- `LayoutGeometryTests` unchanged. Add a small test for “live skip when rect unchanged” if you extract the comparison as a pure function.

---

### B.5 Snap preview skips identical frames ✅

**Verify:** `SnapPreviewController` returns when the AppKit rect is within 1 pt and already visible. Crossing long-swipe / restore-on-repeat still calls `show` with a new rect.

**Files**

- `Sources/Sanne/Windowing/SnapPreviewWindow.swift`
- `Sources/Sanne/Gestures/GestureEngine.swift` (`applyTitlebar`)

**Do this**

1. `SnapPreviewController` stores `lastAppKitFrame`. If the incoming rect equals it (1 pt tolerance) and the window is already visible, return.
2. Do not `needsDisplay = true` on a skip.
3. `applyTitlebar` already skips log spam via `loggedPreviewLayout`. Keep that. The window-side skip is the one that saves AppKit work.

**Verify**

- Hold a titlebar swipe on left-half: overlay appears once and stays. `axSetFrame` does not apply here (preview is AppKit), but Time Profiler should no longer show `-[NSWindow setFrame:display:]` every frame.
- Crossing the long-swipe threshold still updates half → third.
- Second same-layout swipe still previews the **restore** frame.

---

### B.6 Coalesce config disk writes ✅

**Verify:** `update` mutates immediately; disk write is 350 ms debounced. `exportData` / import / reset / `willTerminate` flush. `flushForTests()` hook present. `ConfigRoundTripTests` green.

**Files**

- `Sources/Sanne/Config/ConfigStore.swift`

**Do this**

1. `update` still mutates `@Published config` immediately (UI must stay instant).
2. Disk write is debounced ~300–400 ms on the main actor (`Task.sleep` + generation token, or a `DispatchWorkItem`).
3. `exportData` / `exportToFile` / app termination flush immediately.
4. Hook `NSApplication.willTerminateNotification` (and sleep, if cheap) to flush.
5. Safe-mode still never writes.

**Verify**

- Toggle five Simple rows quickly: one `config.json` write, not five. **Watch the file mtime, or a `saves` counter.**
- Quit within the debounce window: file has the last value.
- Import / Reset still write immediately.
- Existing `ConfigRoundTripTests` green. Add `testDebouncedSaveFlushesOnExport` if you expose a test hook; otherwise a `flushForTests()` on `ConfigStore` is acceptable.

---

### B.7 Stop polling HID and conflicts at 2 Hz ✅

**Verify:** 2 s timer is AX-only while untrusted. Conflicts recompute on launch/terminate. Devices via `HIDDeviceWatcher` + wake/display. `CompetingAppsTests` green. Hardware unplug/replug not run in this session.

**Files**

- `Sources/Sanne/App/AppController.swift`
- `Sources/Sanne/TouchInput/TouchDeviceManager.swift` (`IOKitHints`)
- `Sources/Sanne/Utilities/CompetingApps.swift`

**Do this**

1. **Accessibility:** keep a slow poll (2 s is fine) *or* re-check on `NSApplication.didBecomeActiveNotification` plus the existing wake path. Trust does not flap 30 times a minute.
2. **Conflicts:** subscribe to `NSWorkspace.didLaunchApplicationNotification` / `didTerminateApplicationNotification`. Recompute only then, and once at launch. Delete the 2 Hz scan of `runningApplications`.
3. **Devices:** IOKit interest notification on `IOHIDDevice` add/remove (or `NSWorkspace` / `CGDisplay` plus a 2 s retry *only after* a removal/wake). Home’s device line still updates within a couple of seconds of unplug.
4. The 2 s `Timer` should die, or shrink to “AX only if last check was untrusted.”

**Verify**

- Idle Instruments: `IOServiceGetMatchingServices` / `runningApplications` no longer appear every 2 s.
- Launch BetterTouchTool (or any known bundle in the table) → Home banner appears without waiting for a timer.
- Unplug Magic Mouse → Home updates. Plug back → updates. **Hardware.**
- Existing `CompetingAppsTests` green.

---

### B.8 Cheap remaining hot-path nits ✅

**Verify:** Session times use `CFAbsoluteTimeGetCurrent()`. `TouchFrame.timestamp` is `TimeInterval`. Cursor via reused `CGEvent` probe. `MagicMouseLogicTests` inject `now:`.

Do these in the same PR as B.2 if they fit; otherwise a small follow-up.

**Files**

- `Sources/Sanne/TouchInput/MagicMouseTapController.swift`
- `Sources/Sanne/TouchInput/TouchFrame.swift`
- `Sources/Sanne/TouchInput/MagicMouse/ScrollLock.swift`
- `Sources/Sanne/TouchInput/MagicMouse/PhysicalClickGuard.swift`

**Do this**

1. Replace `Date()` session timestamps with `CFAbsoluteTimeGetCurrent()` or `mach_absolute_time()`. Keep `Date` at the log boundary only.
2. Cache cursor with `CGEventSource.desktopLocation` / a single reused `CGEvent` if you must, or `NSEvent.mouseLocation` **only after hopping to main**. On the MT thread, prefer `CGEventSource(stateID:)` location without allocating per frame — store one `CGEvent` and query `location`.
3. `TouchFrame.timestamp` can be `TimeInterval` (host time), not `Date`.

**Verify**

- Allocations trace for 20 taps no longer shows a pile of `__NSCFDate` / `CGEvent`.
- Scroll-lock and physical-click windows still behave. **Existing `MagicMouseLogicTests` (inject `now:`).**

---

## Phase C — Recognition off the main thread ✅

**Goal:** Trackpad and Magic Mouse state machines run on `app.sanne.touch.pipeline` (or the MT callback thread). Main thread sees: session begin (AX zone + window), preview updates (coalesced), and commits.

This is the highest-risk performance work. Do not start until B.1–B.3 are green. One PR.

---

### C.1 Trackpad engine on the pipeline queue ✅

**Verify:** Listener runs on `app.sanne.touch.pipeline`. Session begin hops to main once; preview hops only when layout changes; commit hops once. `ThreeFingerTapTests` + recognizer tests green. Hardware titlebar/Dock/3F not run in this session.

**Files**

- `Sources/Sanne/Gestures/GestureEngine.swift`
- `Sources/Sanne/TouchInput/TouchDeviceManager.swift`
- `Sources/Sanne/Zones/ZoneClassifier.swift`
- `Sources/Sanne/Windowing/WindowManager.swift` (only the “capture window at begin” call)

**Do this**

1. Change the listener in `GestureEngine.start` from `DispatchQueue.main.async` to `pipeline.async` (or call `handle` directly on the pipeline — `emit` already hops there).
2. Make recognizers (`SwipePinchRecognizer`, `ThreeFingerDragRecognizer`, `TipTapRecognizer`) **not** `@MainActor`. They already look like pure structs; confirm and drop any accidental isolation.
3. **Session begin (first live touch):** hop to main **once**, run `ZoneClassifier.zone` + `windowAt` / `dockApp`, hop the result back onto the pipeline (a small `SessionBegin` box: zone, window, dock app, frontmost bundle, snapshot). Cache that for the whole contact.
4. **Preview:** hop to main only when `loggedPreviewLayout` changes (already the case for logs). Same for hide.
5. **Commit / click / haptic / HUD:** hop to main once, call `ActionRunner`.
6. `ZoneClassifier` does not need to stay `@MainActor` if it only uses AX + `NSScreen`. AX is not main-thread-only, but `NSScreen` / `NSEvent.mouseLocation` are AppKit. Keep the zone sample on main at session begin — that is one hop, not 100.
7. Count `mainHops`. A 3-finger swipe that never commits should be: 1 (begin) + 1 (preview show) + 1 (preview hide). A tap: 1 (begin) + 1 (commit).

**Verify**

- `mainHops` per titlebar swipe ≤ 4. Per free-space 3F tap ≤ 2. **Counters.**
- 3F tap-with-travel still does not fire when drag is off. **`ThreeFingerTapTests`.**
- Titlebar preview still appears and commits on lift. Restore-on-repeat still works.
- Tip-tap, 4→3 decay, drag-wins-session unchanged. **Existing recognizer tests.**
- Hardware: titlebar halves, Dock swipe, 3F middle-click, 3F drag.

---

### C.2 Magic Mouse: commit hop only ✅

**Verify:** Recognition stays on the MT thread. Commit is one `MainHop`. Drag posts `ClickEmitter` from the MM thread. Window-move updates coalesce to one queued main hop. No `usleep` on main.

**Files**

- `Sources/Sanne/TouchInput/MagicMouseTapController.swift`
- `Sources/Sanne/Gestures/GestureEngine.swift`
- `Sources/Sanne/InputSynth/ClickEmitter.swift`

**Do this**

1. Keep recognition on the MT thread (already true).
2. Replace `Task { @MainActor in handleMagicMouse }` with a single `DispatchQueue.main.async` that calls `ActionRunner` / `GestureActivity`. No second resolve if B.2 stored the action id.
3. Drag-move: do **not** `DispatchQueue.main.async` a `mouseDragged` per frame if the click queue can post CGEvents. `ClickEmitter.mouseDragged` is already nonisolated — call it from the MM thread, or bounce to `app.sanne.click`.
4. Window-move updates: hop to main **or** call `WindowMover` only if you mark a nonisolated live-set path. Prefer: pipeline/main hop coalesced to display refresh (`DispatchSource` timer, or skip if a hop is already queued).

**Verify**

- 20 left taps: `mainHops` ≈ 20 (one per tap), not 20 × frames. **Counters.**
- Tap-drag of a Finder file still tracks the cursor. **Hardware.**
- Top-edge 2F move still follows the mouse without feeling quantized worse than today.
- No `usleep` on main. **Code.**

---

### C.3 Shared AX walk ✅

**Verify:** `AXQuery` is the parent walk + own-PID skip for `ZoneClassifier` and `WindowManager.windowAt`.

Small, do with C.1.

**Files**

- New: `Sources/Sanne/Windowing/AXQuery.swift`
- `Sources/Sanne/Zones/ZoneClassifier.swift`
- `Sources/Sanne/Windowing/WindowManager.swift`

**Do this**

1. Extract “walk parents for role / window / pid” into one helper. Both `ZoneClassifier.isTitlebar` and `WindowManager.windowAt` copy this loop.
2. Skip Sanne’s own PID in one place.
3. No behaviour change.

**Verify**

- Titlebar detection still works on Chrome / VS Code (52 pt strip fallback stays). **Hardware, or at least “code path still present.”**
- `windowAt` still returns nil for Sanne’s own windows.

---

## Phase D — Finish leftover architecture ✅

**Goal:** Finish leftover architecture: slot-only enablement, extracted Magic Mouse machines, one window mover, one device enumerator. No new product surface.

Do this after B/C so you are not splitting a file you are about to rewrite twice.

---

### D.1 Delete the ~40 legacy enable bools ✅

**Verify:** `enableLegacyGate` gone. Editor writes overrides only. Encode omits deleted keys; `decodeIfPresent` + `legacyEnabled` remain for 0.2.0 migrate. `testVersion020FixtureMigratesEverySlotUnchanged` green. `LegacyGate` kept for migrate only.

Recognition already reads slots. The model and editor still keep the legacy bools in sync.

**Keep as real config (not enable flags):** sensitivity, left/right split, dead zone, window gap, HUD, keyboard chord options, modifier-drag modifier arrays, launch at login, `multiClick`, `gamingMode`.

**Delete after migrate:** `leftTap`, `rightTap`, `middleTwoFinger`, `middleThreeFinger`, `tapDrag`, `twoFingerDoubleTapMissionControl`, `twoFingerSwipeUpMissionControl`, `twoFingerSwipeDownAppExpose`, `twoFingerSwipeSpaces`, `threeFingerSwipes`, `twoFingerTopEdgeMove`, `oneFingerSwipePages`, and the matching titlebar / dock / menubar / trackpad enable bools.

**Files**

- `Sources/Sanne/Config/ConfigModels.swift`
- `Sources/Sanne/Config/GestureBinding.swift`
- `Sources/Sanne/Gestures/GestureSlots.swift`
- `Sources/Sanne/Config/SannePreset.swift`
- `Sources/Sanne/UI/Preferences/GestureEditorView.swift`
- `Tests/SanneTests/ConfigRoundTripTests.swift`
- `Tests/SanneTests/BindingResolverTests.swift`
- `Tests/SanneTests/Phase5QualityTests.swift`
- `Tests/SanneTests/PresetTests.swift`

**Do this**

1. Confirm `migrateToSlotEnablement()` + version 2 already run on load (they do).
2. Stop encoding the deleted keys. Keep `decodeIfPresent` so 0.2.0 files still migrate.
3. Delete `enableLegacyGate`, `legacyEnabled`, and `LegacyGate` **only after** every slot carries `defaultEnabled: Bool` (or you key defaults off `SannePreset.standard.enabledSlotIds`).
4. `GestureEditorView` writes `gestureOverrides[id].enabled` only. No gate sync.
5. `SannePreset.slotEnabled` for `version >= 2` already ignores the bools — delete the `version < 2` branch’s *write* path once decode has migrated.
6. Generate / assert `sanne.standard.json` still matches `GestureSlots` defaults (test already exists).

**Verify**

- `testVersion020FixtureMigratesEverySlotUnchanged` still green.
- `rg enableLegacyGate` is empty.
- `rg "leftTap"` in `Sources/` hits only `decodeIfPresent` (or nothing).
- Editor: disable left tap → JSON has an override, not `"leftTap": false`.
- New install writes version 2 without the deleted keys. **Inspect a fresh `config.json`.**
- `swift test` green.

---

### D.2 Actually extract the Magic Mouse machines ✅

**Verify:** `MMSession` / `MMTapMachine` / `MMSwipeMachine` / `MMDragSession` / `MMWindowMove` extracted. Controller is 791 lines (plan target was 350 — orchestration + monitors remain). New `MMSwipeMachineTests` cover 2F→3F freeze. `MagicMouseLogicTests` green. Hardware left/right/middle not run in this session.

Phase 3.2 extracted helpers. The 1,234-line controller is still the machine.

**Extract, in this order** (each can be its own PR):

| Piece | New file | Responsibility |
|-------|----------|----------------|
| `MMSession` | `TouchInput/MagicMouse/MMSession.swift` | All the `activeTouchID` / `netDx` / `dragPhase` / `windowMovePhase` fields. One `kill()` / `reset()`. |
| `MMTapMachine` | `TouchInput/MagicMouse/MMTapMachine.swift` | Left / right / multi-click / dead zone. Pure: frame in, event out. |
| `MMSwipeMachine` | `TouchInput/MagicMouse/MMSwipeMachine.swift` | 1F pages, 2F, 3F. One swipe primitive. |
| `MMDragSession` | `TouchInput/MagicMouse/MMDragSession.swift` | Double-tap-hold. |
| `MMWindowMove` | `TouchInput/MagicMouse/MMWindowMove.swift` | Top-edge 2F move / 3F resize. Calls `WindowMover`, does not duplicate it. |

`MagicMouseTapController` keeps: device register/unregister, scroll-wheel + physical-click monitors, snapshot refresh, `handle` as a 50-line dispatcher.

**Also do while splitting**

1. One `killSession()` — the four `*Unlocked` reset functions collapse into `MMSession.kill(reason:)`.
2. No new behaviour. Dead-zone / travel / 320 ms 2F middle delay stay as they are (already fixed once).

**Verify**

- `MagicMouseTapController.swift` < 350 lines. Each new file < 250.
- `MagicMouseLogicTests` still cover dead zone, thresholds, swipe axis, scroll lock, physical-click window.
- Add pure tests for `MMSwipeMachine` finger-freeze (2F must not promote to 3F after `swipeMin * 0.5`).
- Hardware: left/right/middle, tap-drag, no ghost click after scroll, 3F swipe vs middle, top-edge move.

---

### D.3 One window-motion path, for real ✅

**Verify:** One `struct EdgeSet` (`WindowMover`). `TouchWindowMover` deleted. `ModifierDragController` is monitors + chord + `WindowMover.begin/update/end`.

**Files**

- `Sources/Sanne/Windowing/WindowMover.swift`
- `Sources/Sanne/Windowing/ModifierDragController.swift`
- `Sources/Sanne/Windowing/TouchWindowMover.swift`

**Do this**

1. `ModifierDragController` becomes: monitors + chord match + `WindowMover.begin/update/end`. Delete its `EdgeSet`, `updateDrag` geometry, and `nearestEdges`.
2. Move `nearestEdges` onto `WindowMover` (already there). One definition.
3. Delete `TouchWindowMover.swift`. Call `WindowMover.shared` from the MM path.
4. Live `setFrame` from B.4 is the only writer on this path.

**Verify**

- `rg "struct EdgeSet"` has one hit.
- `rg TouchWindowMover` is empty.
- Modifier-drag move/resize and MM top-edge move/resize both work. Sanne’s own windows still ignored.
- `swift test` green (no new geometry).

---

### D.4 One device enumerator ✅

**Verify:** `TouchDeviceManager` is the only `createDeviceList` / register / start caller. Fans trackpad vs Magic Mouse. Wake rebind is one `restart()`, three attempts. `DeviceClassifierTests` green.

**Files**

- `Sources/Sanne/TouchInput/TouchDeviceManager.swift`
- `Sources/Sanne/TouchInput/MagicMouseTapController.swift`
- `Sources/Sanne/TouchInput/PrivateMT.swift`
- `Sources/Sanne/App/AppController.swift` (wake rebind)

**Do this**

1. `TouchDeviceManager` is the only caller of `PrivateMT.createDeviceList` / `register` / `start`.
2. It fans frames by `DeviceKind`:
   - trackpad → existing listeners (`GestureEngine`)
   - Magic Mouse → `MagicMouseTapController.handle(frame:)` or a raw-contact callback
3. Magic Mouse can keep a raw-contact entry point (it needs `size`, velocity, state). Do **not** force it through `TouchFrame` if that drops fields — extend `TouchPoint` with `size` / `velX` / `velY` instead.
4. `AppController.rebindAfterWake` calls **one** `restart()`, not two `Task.detached` restarts with `Thread.sleep`.
5. `IOKitHints` stays for the Home device line, not for callback registration.

**Verify**

- Launch logs show a single device walk. Magic Mouse and trackpad both register.
- External Magic Trackpad still on the trackpad path. **`DeviceClassifierTests`.**
- Wake rebind: one restart path, three attempts. **Code.** Hardware: sleep/wake 10× still required.
- Unplug/replug mouse: taps resume without relaunch.

---

### D.5 Frontmost-app snapshot owner ✅

**Verify:** `AppController` listens to `didActivateApplicationNotification` and rebuilds `RuntimeSnapshot`. Pause bits read the snapshot. Gesture begin stamps the snapshot onto the session.

Small, do with B.2 if not already done.

**Files**

- `Sources/Sanne/App/AppController.swift`
- `Sources/Sanne/Gestures/RuntimeSnapshot.swift`

**Do this**

1. One place listens to `NSWorkspace.didActivateApplicationNotification` and rebuilds `RuntimeSnapshot`.
2. `AppController.isMagicMousePaused` / `isWindowGesturesPaused` / … read the snapshot, not a fresh `frontmostApplication` on every menu/icon refresh.
3. Gesture begin still stamps `frontmostBundle` onto the session so a slow notification cannot change the app mid-swipe.

**Verify**

- Switch Safari → Xcode with a per-app remap: next gesture uses Xcode’s binding.
- Menu icon pause-in-app still updates on focus change.

---

## Phase E — File and module splits ✅

**Goal:** Files a person can hold in their head. No behaviour change. Do **after** D so you are not moving lines that D will delete.

Surgical. Do not “improve” comments. Do not rename public slot ids.

---

### E.1 Split `GestureSlots.swift` ✅

**Verify:** `BindingResolver.swift` extracted. `GestureSlots.swift` is 470 lines (slot table + migrate `LegacyGate`). No slot id changes.

**Today:** 569 lines — slot table + `LegacyGate` + `BindingResolver` + `LegacyRecognition`.

**Target**

```
Gestures/GestureSlots.swift        # Slot, Group, Visibility, ID, `all`, `byId`
Gestures/BindingResolver.swift     # ResolvedGesture + resolve / isModified
Config/LegacyGate.swift            # only if D.1 has not deleted it yet; otherwise skip
```

**Verify**

- `swift build` / `swift test`. No slot id changes. Cheat sheet and Settings still resolve.

---

### E.2 Split `MenuBarController.swift` ➖

Skipped: `refreshMenu` deleted (it only called `refreshIcon`). Full `WindowSession` extract deferred — the four window controllers still live in `MenuBarController` (600 lines) and were not causing a tap-latency bug.

**Today:** 606 lines — status item, menu construction, and four window controllers (Settings / onboarding / tutorial / cheat sheet).

**Target**

```
App/MenuBarController.swift        # status item, icon, menu
App/WindowSession.swift            # NSWindow lifecycle + accessory restore
```

`WindowSession` already exists in spirit (`NSWindowDelegate` + `restoreAccessoryIfIdle`). Pull the four windows into it.

**Verify**

- Close Settings → Sanne leaves the Dock.
- Option-click still reveals Debug.
- Pause icon still updates without a 1 s timer (already true).

---

### E.3 `ActionRunner` as a table, not a 500-line switch ✅

**Verify:** `execute` funnels through snap + `runWindow` / `runInput` / `runSystem` / `runCustom`. `ActionCatalogTests` green.

**Files**

- `Sources/Sanne/Actions/ActionRunner.swift`
- `Sources/Sanne/Actions/ActionCatalog.swift`

**Do this**

1. Snaps already go through `ActionCatalog.snapLayout(for:)`. Leave that.
2. Group the remaining cases into 4 functions: `runWindow`, `runInput`, `runSystem`, `runCustom`. Still one `execute` funnel (HUD policy depends on it).
3. Do **not** invent a plugin / handler-registration framework. Four functions is enough.

**Verify**

- `ActionCatalogTests` HUD allow-list and snap round-trip still green.
- A snap with no window still shows “No window.” Restore still announces “Restore.”

---

### E.4 `GestureEditorView` leftovers ➖

Skipped: only `enableLegacyGate` call sites were removed. Nested row/chrome types left in place (`Do this only if you are in the file anyway`).

**Today:** 661 lines after Phase 3.1 already pulled the sheets out.

**Do this only if you are in the file anyway**

1. Pull `GestureToggleRow` / filter chips / “Show all gestures” header into `GestureEditorChrome.swift` if they are still nested types.
2. Do not rewrite the list. Do not switch to `Form`.

**Verify**

- Simple / Show all / remap popover / per-app editor unchanged.

---

### E.5 Delete dead wrappers as you touch them ✅

**Verify:** `TouchWindowMover` gone. `LegacyRecognition` gone. `refreshMenu` gone. `logEveryTouchFrame` wired in B.1.

Already scheduled: `TouchWindowMover` (D.3). Also check:

| Symbol | Action |
|--------|--------|
| `LegacyRecognition.wouldEmit` | Inline or delete if it is a one-line wrapper |
| `MenuBarController.refreshMenu` | Delete if it only calls `refreshIcon` |
| `logEveryTouchFrame` | Wired in B.1 or deleted |
| `observeConfig` stub leftovers | Already wired; do not re-abstract |

**Verify**

- `rg` for each deleted name is empty. Tests green.

---

## Phase F — Settings / SwiftUI performance ➖

Skipped: “only if Settings feels slow after B.6.” Not measured. B.6 debounce should already cut Settings disk churn.

**Goal:** Toggling a row or typing in search does not rebuild the world. Only do this if Settings feels slow after B.6. It does not affect tap latency.

---

### F.1 Stop publishing the entire config as one blob ⬜

**Files**

- `Sources/Sanne/Config/ConfigStore.swift`
- Pages under `UI/Preferences/Pages/`

**Do this**

1. Keep `config` as the source of truth.
2. Add narrow published facets only if Instruments (SwiftUI) shows `PreferencesView.body` firing on unrelated writes: e.g. `paused`, `connectedPointers` already live on `AppController`.
3. Prefer this cheaper fix first: `GestureEditorView` rows become a small `Equatable` `GestureRowModel` so SwiftUI can skip unchanged rows.
4. Do **not** split `ConfigStore` into five stores.

**Verify**

- SwiftUI Instrument: toggling “Tap left” does not rebuild Advanced / Apps.
- Search still highlights. Live “you just did this” still scrolls to the row.

---

### F.2 Debug Log is lazy and paused when hidden ⬜

Mostly done by B.1. Confirm:

- Leaving Advanced unmounts the subscriber so the ring stops publishing.
- 4,000 lines still scroll via `LazyVStack` (already).

**Verify**

- Time Profiler while tapping with Settings on Home: no `DebugLogView` / `LogLine.formatted` samples.

---

## Phase G — Only if Instruments still points here ➖

Parked, as specified. Not scheduled.

Do not schedule these. Park them.

| ID | Idea | When it becomes real |
|----|------|----------------------|
| G.1 | Reuse a `[TouchPoint]` buffer (no per-frame array alloc) | Allocations trace still shows `TouchPoint` / `Array` as top after B/C |
| G.2 | `protocol TouchDeviceSource` from Technical Design §6.2 | A second input source exists (it does not) |
| G.3 | XPC helper / privilege split | Notarization or sandbox forces it |
| G.4 | Replace MultitouchSupport | Never, unless Apple ships a public finger API |
| G.5 | Combine-heavy reactive input graph | Never. The pipeline queue is enough |
| G.6 | Precompute `GestureDiagram` paths | Settings scroll still hitching after F.1 |

---

## What not to do

Recorded so they are not mistaken for gaps:

- New gestures, Hyper, grids, edge-snap, drawing, floating menus.
- A second Settings editor or a DSL for bindings.
- Protocols around `ConfigStore`, `ActionRunner`, `WindowManager` “for testability.” Extract pure functions instead (already the pattern in `LayoutGeometry`, `MMThresholds`, `ScrollLock`).
- Rewriting Settings in AppKit.
- Rewriting MultitouchSupport behind a grand abstraction without D.4’s single enumerator.
- Persist-anything performance counters.
- Micro-optimizing `BindingResolver` with caches *in addition to* the snapshot. The snapshot **is** the cache.
- Changing slot ids or action ids. That is a config break.

---

## Interaction with 1.0 / hardware QA

| If you are cutting 1.0… | Do this plan through |
|-------------------------|----------------------|
| This week, hardware in hand | **A + B.1 + B.4 + B.5.** Then hardware QA on `dist/Sanne.app`. |
| One more week | A–C. Taps and swipes will feel tighter. |
| After 1.0 | D–F. Users cannot see D.1, but the next person to touch MM will. |

Do not start D.2 (MM split) the same day as a hardware QA pass. Split, then re-run left/right/middle, tap-drag, ghost-click, and 3F swipe vs middle.

---

## Suggested PR order

Each line is one PR. Merge only when that step’s **Verify** is true.

1. A.2 — counters (A.1 is local traces, not a PR)
2. B.1 — log pipeline
3. B.6 — debounce config saves *(independent of 2)*
4. B.7 — event-driven devices / conflicts *(independent of 2)*
5. B.4 + B.5 — live `setFrame` + preview skip
6. B.2 + B.3 + B.8 + D.5 — slim snapshot, no per-frame resolve
7. C.1 + C.3 — trackpad off main + shared AX walk
8. C.2 — MM commit-only hop
9. D.1 — delete legacy bools
10. D.3 — one `WindowMover` *(can go before 9)*
11. D.4 — one enumerator
12. D.2 — extract MM machines
13. E.1–E.3 — file splits as leftover cleanup
14. F.1 — only if Settings still stutters

---

## How to update this file

1. Flip ⬜ → 🟡 when a step starts; 🟡 → ✅ only when its **Verify** line is true.
2. If you skip a step, mark ➖ and write one sentence why.
3. After B.1 and B.3, paste new Instruments numbers under A.1 (do not delete the baseline).
4. Mirror user-visible landings (none of A–E should have any, except maybe a Debug Log toggle default) into [CHANGELOG.md](./CHANGELOG.md) only if a user can see them.
5. Mirror user-visible landings into [README.md](./README.md) and [CHANGELOG.md](./CHANGELOG.md).

---

*End of performance and refactor plan*
