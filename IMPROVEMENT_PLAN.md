# Sanne — UX, Feature & Maintainability Plan

**Status:** Phases 0–4.2 code landed in tree (2026-08-14). Hardware QA (5.2) and the compatibility matrix (5.3) remain.  
**Created:** 2026-08-14  
**Companion to:** [PRD.md](./PRD.md) · [UX_WIREFRAMES.md](./UX_WIREFRAMES.md) · [TECHNICAL_DESIGN.md](./TECHNICAL_DESIGN.md) · [PROGRESS.md](./PROGRESS.md) · [MVP_SCOPE.md](./MVP_SCOPE.md)

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

1. Work **one phase at a time**, in order. Later phases assume earlier ones.
2. Inside a phase, steps are ordered. A step may say it can ship independently — that is for PRs, not for skipping ahead.
3. Each step has **files**, **do this**, and **verify**. The verify line is the definition of done.
4. After a code step: `swift build` (zero warnings) and `swift test` must stay green.
5. Hardware checks run from `dist/Sanne.app` (`./scripts/package-app.sh`), never the raw `swift run` binary. Accessibility identity differs.

---

## Diagnosis (why this plan exists)

Sanne already has the hard engines: Magic Mouse taps, titlebar snap, remaps, HUD, per-app bindings, scripts. The 0.2.0 product promise — “install it, gestures work, every default is editable” — is blocked by the surface around those engines.

| Surface | Reality |
|---------|---------|
| Settings | 11 sidebar items. Designed ([UX_WIREFRAMES.md](./UX_WIREFRAMES.md) §4): 8. Debug Log and All bindings sit next to Home. |
| Gestures | 54 remappable slots + 63 actions. Day-one users see all of them. |
| Config | Three live systems: ~40 legacy bools, global remaps, per-app remaps + pause. |
| First run | Onboarding only if Accessibility is missing, then auto-closes on grant. Tutorial is a race the user usually loses. |
| Menu bar | Template hand icon. Dims only on global pause. No permission badge, no quick toggles. |
| Tests | 35 pure-logic tests. Zero for `LayoutGeometry`, `WindowManager`, `ZoneClassifier`, or the 1,313-line Magic Mouse controller. |
| Hardware | 0.2.0 shipped with hardware QA skipped ([PLAN_PROGRESS.md](./PLAN_PROGRESS.md) step 9). |

The two delight moments from [MVP_SCOPE.md](./MVP_SCOPE.md) — silent Magic Mouse tap, titlebar swipe to snap — are implemented. Almost everything else is either a second way to do those, or a power feature sitting on the front door.

### Principles

1. **Day-one UI shows ~8 gestures, not 54.** Power stays one click away.
2. **One enablement story.** A gesture is on or off in one place.
3. **One action path.** Keyboard, mouse, and trackpad all go through `ActionRunner`.
4. **Do not add BTT surface until the existing product is simple.** No Hyper, no drawing, no edge-snap, no 3×3 grid until Settings is 8 tabs and first-run works.
5. **Hardware QA is a feature.** New gestures stay off until a real trackpad + Magic Mouse pass.

### What not to change yet

These are sound. Do not “improve” them while executing this plan:

- BindingResolver layering (app → global → Standard)
- HUD policy in `ActionCatalog.announcesInHUD`
- Off-by-default for free-space 3F/4F, tip-tap, Magic Mouse 3F swipes
- Script timeout (10 s) and concurrency cap (4)
- Gesture diagrams (`GestureDiagram.swift`)
- Titlebar snap preview

---

## Suggested calendar (one person)

| Week | Work |
|------|------|
| 1 | Phase 0.1–0.2 — first-run + menu bar + accessory restore |
| 2 | Phase 0.3–0.4 — wake retry + device identity + config honesty |
| 3–4 | Phase 1.1–1.4 — sidebar + Simple pages + one catalog + Home |
| 5 | Phase 1.5–1.7 — Apps rewrite + tutorial + remap popover |
| 6 | Phase 2 — slot-only enablement + migrate |
| 7–8 | Phase 3.1–3.3 — split views + split MM controller + engine cleanup |
| 9 | Phase 3.4–3.6 — window path + keyboard slots + ActionRunner |
| 10 | Phase 4 slice — Minimal preset + search + a11y + restore action |
| 11 | Phase 5 — tests + hardware QA + 1.0 checklist |

That is a v1.0. Notarized 0.2.0 already exists; 1.0 should be the same engines, a product a non-BTT user can inhabit.

---

## Phase 0 — Stop the leaks

**Goal:** First-run works. Menu bar tells the truth. Sleep/wake and device identity are honest. Config cannot silently destroy itself.

**No new features.** Each step is an independently shippable PR.

---

### 0.1 First-run actually happens ✅

**Bug:** `AppController.start()` only shows onboarding when Accessibility is missing (`AppController.swift`). When trust flips, a 1 Hz timer in `SanneApp.swift` closes the window before **Start Tutorial**. Already-trusted installs (rebuild, login item) get no welcome and no tutorial. `TutorialPrefs.completed` is written and never read.

**Files**

- `Sources/Sanne/App/AppController.swift`
- `Sources/Sanne/App/SanneApp.swift`
- `Sources/Sanne/App/MenuBarController.swift`
- `Sources/Sanne/UI/Onboarding/OnboardingView.swift`
- `Sources/Sanne/UI/Help/GestureCatalog.swift` (`TutorialPrefs`)
- `Sources/Sanne/UI/Help/TutorialView.swift`

**Do this**

1. Persist `hasCompletedWelcome` in `UserDefaults` (or `SanneConfig`). First launch of a *new* config — `ConfigStore.load` already knows this: no file → bundled Standard — is the trigger, **not** “AX is missing.”
2. Show onboarding whenever `hasCompletedWelcome == false`, including when AX is already granted.
3. Stop auto-closing the onboarding window when AX becomes trusted. Keep the sheet open. Transition the primary button to **Start Tutorial**.
4. While waiting for AX: one primary **Open System Settings**. Drop the second **Request Permission** button. Keep the binary path as a caption only (needed for `swift run`).
5. Offer **Quit** while waiting for AX (wireframe §3 step 2).
6. After AX: **Start Tutorial** is the default action. **Skip** stays available and sets `hasCompletedWelcome = true`.
7. If AX was already granted at launch and `TutorialPrefs.completed == false` and welcome was already dismissed, offer the tutorial **once** from Home (banner or first-open sheet). Do not offer every launch.
8. Honor `TutorialPrefs.completed` for that one-shot offer.

**Verify**

- Fresh config, no AX → welcome stays up after granting AX → Start Tutorial works. **Code:** AX grant no longer closes welcome; Start Tutorial is the post-AX default. Hardware first-run on a clean account still needed for 5.2.
- Fresh config, AX already granted → welcome still appears → Start Tutorial works. **Code:** `hasCompletedWelcome`, not AX, is the trigger.
- Skip welcome → Home offers tutorial once → dismiss → never again. **Tests:** `FirstRunPrefsTests`.
- Completed tutorial → no repeat offer. **Tests:** `FirstRunPrefsTests`.
- `swift build` / `swift test` green. **66 tests, 2026-08-14.**

---

### 0.2 Menu bar tells the truth ✅

**Bug:** The entire menu is rebuilt every second (`SanneApp.swift`). Opening Debug cannot stay open reliably. Icon only dims on global `paused`. Settings / Cheat Sheet never restore `.accessory`, so Sanne stays in the Dock. **Debug Log…** opens Settings Home, not the Debug tab. About is an `NSAlert`, not the About pane. Designed quick toggles (Magic Mouse / Titlebar) are missing.

**Files**

- `Sources/Sanne/App/SanneApp.swift`
- `Sources/Sanne/App/MenuBarController.swift`
- `Sources/Sanne/App/AppController.swift`
- `Sources/Sanne/UI/Preferences/PreferencesView.swift` (tab selection hook)

**Do this**

1. Delete the 1 Hz `buildMenu()` timer. Rebuild the menu and icon when `AppController` / `ConfigStore` published state changes (`sanneConfigDidChange`, AX, conflicts, pause).
2. Icon states:
   - Running: template `hand.draw`
   - Global pause: slash overlay or `appearsDisabled`
   - Missing Accessibility: warning badge (not only a status-line string)
3. Restore wireframe §2.2 quick toggles: **Magic Mouse Taps**, **Titlebar Window Gestures** (checkmarks). These write the existing masters.
4. Conflict row: keep the app name, add **Pause Sanne**.
5. Hide the Debug submenu behind Option-click on the status item (matches [TECHNICAL_DESIGN.md](./TECHNICAL_DESIGN.md) §17). When Option is not held, Debug is absent.
6. **Debug Log…** must select the Debug tab (after Phase 1 this lives under Advanced — until then, select `.debug`).
7. Implement `NSWindowDelegate` on Settings, Cheat Sheet, Tutorial, Onboarding. On close, call `restoreAccessoryIfIdle()`. Closing Settings must not leave a Dock icon.
8. Status line: “Needs Accessibility” / “Paused” / “Off in {app}” / “Running”. Drop the dead `multitouchError` branch until errors are actually set (Phase 0.3).
9. Keep **Settings…** as the menu label (current). Do not mix with “Preferences…” in new copy.

**Verify**

- Pause / resume updates the icon immediately with no 1 s lag. **Code:** 1 Hz timer deleted; icon refreshes on `objectWillChange` / `sanneConfigDidChange`.
- Option-click shows Debug; normal click does not. **Code:** `menuNeedsUpdate` + `NSEvent.modifierFlags`.
- Debug Log… opens the Debug pane. **Code:** `PreferencesRoute.debug` → Advanced → Debug Log.
- Close Settings → Sanne leaves the Dock (agent again). **Code:** `NSWindowDelegate.windowWillClose` → `restoreAccessoryIfIdle()`.
- Missing AX shows a badge, not only a disabled title. **Code:** composite warning-triangle template image.
- Menu does not rebuild while the user has it open. **Code:** single `NSMenu`; items rebuilt only in `menuNeedsUpdate`.

---

### 0.3 Wake and devices ✅

**Bug:** One `didWake` attempt, ~300 ms, no retry. Trackpad failure is treated as success (`multitouchError` is assigned `nil` on every path). External Magic Trackpad is classified as a mouse (`PrivateMT.isMagicMouseDevice`) and owned by neither controller. `IOKitHints.applePointers()` is written and never called. Home never lists devices.

**Files**

- `Sources/Sanne/App/AppController.swift`
- `Sources/Sanne/TouchInput/TouchDeviceManager.swift`
- `Sources/Sanne/TouchInput/PrivateMT.swift`
- `Sources/Sanne/TouchInput/MagicMouseTapController.swift`
- `Sources/Sanne/UI/Preferences/PreferencesView.swift` (status card)

**Do this**

1. Subscribe to `NSWorkspace.screensDidSleepNotification` / `screensDidWakeNotification` in addition to `willSleep` / `didWake`.
2. Register `CGDisplayRegisterReconfigurationCallback` (or `NSApplication.didChangeScreenParametersNotification`). On display change, invalidate zone cache and re-resolve screens for snap.
3. Wake rebind: 3 attempts with backoff (e.g. 200 ms, 800 ms, 2 s). Bluetooth Magic Mouse is often late after lid-open.
4. On real failure, set `multitouchRunning = false` and `multitouchError` to the last error. Do not lie green.
5. Classify devices with `IOKitHints` + `MTDeviceIsBuiltIn` + Force Touch + product name:
   - Built-in trackpad → trackpad path
   - Magic Trackpad (external, Force Touch, not opaque) → trackpad path
   - Magic Mouse → Magic Mouse path
6. One enumerator fans frames to the right handler. External Magic Trackpad must never be skipped as “must be a mouse.”
7. Home status card shows connected devices: “Built-in Trackpad · Magic Mouse” or “No Magic Mouse connected.”
8. Magic Mouse page empty state when no mouse: **“Connect a Magic Mouse to configure taps.”** Diagram dimmed (wireframe §9). Tuning stays editable so a laptop user can prepare.

**Verify**

- Sleep 10× from `dist/Sanne.app`. Taps and titlebar snap work after wake without relaunch. **Code:** 3-attempt backoff 200 ms / 800 ms / 2 s; screens sleep/wake + display-change observers. Hardware 10× still needed for 5.2.
- Laptop + Magic Trackpad: trackpad zone gestures work on the external pad. **Code + tests:** `TouchDeviceClassifier` treats Force Touch + not opaque as `.magicTrackpad`; `TouchDeviceManager` registers it.
- Laptop + Magic Mouse: taps work; trackpad still works. **Code:** mouse and trackpad classifiers are exclusive.
- Mouse-only Mac: Home does not claim “Multitouch active” as a trackpad success. **Code:** `multitouchRunning` is false when 0 trackpad devices; Home lists `IOKitHints.applePointers()`.
- Unplug Magic Mouse → Home updates within a few seconds. **Code:** 2 s poll of `IOKitHints`.

---

### 0.4 Pause and config honesty ✅

**Bugs**

- `paused` is persisted. Pause, quit, relaunch → app looks dead.
- `DockGestureConfig` / `MenubarGestureConfig` have no tolerant `init(from:)`. A partial JSON resets the whole section.
- `ConfigStore.load` swallows decode errors and overwrites the bad file.
- `AppOverride.disabled` means “the override is active.” Settings binds it to a toggle labeled **Active**.
- `observeConfig()` is an empty stub. Import / reset do not re-apply the login item.
- `presetId` is written and never used. `version` is always 1 and never migrated.

**Files**

- `Sources/Sanne/Config/ConfigModels.swift`
- `Sources/Sanne/Config/ConfigStore.swift`
- `Sources/Sanne/App/AppController.swift`
- `Sources/Sanne/UI/Preferences/PreferencesView.swift`
- `Tests/SanneTests/ConfigRoundTripTests.swift`

**Do this**

1. Do **not** persist `paused` across launch (reset to `false` in `start()`), **or** treat it as session-only and stop encoding it. Prefer reset-on-start so a shared export cannot pause someone else’s install.
2. Add the same `decodeIfPresent` tolerant decoder used by `MagicMouseTapConfig` to `DockGestureConfig` and `MenubarGestureConfig`.
3. On decode failure: copy `config.json` → `config.json.bak`, log the error, load Standard. Never silently overwrite without a backup.
4. Rename `AppOverride.disabled` → `isActive`. Decode both keys. Update the Apps toggle binding and help text.
5. Wire `observeConfig()` (or call from `importData` / `resetToStandard`): `LaunchAtLogin.apply(desired: config.launchAtLogin)`.
6. Leave `presetId` / `version` alone until Phase 2 (migrate) and Phase 4 (presets). Note them as dead; do not invent a preset engine here.

**Verify**

- Pause → quit → relaunch → running. **Code:** `start()` resets `paused` to false.
- A JSON with only `{ "dockGestures": { "enabled": false } }` keeps other dock flags at defaults instead of resetting the section. **Tests:** `testPartialDockJSONKeepsOtherDockFlags`.
- Corrupt JSON → `.bak` exists, app launches on Standard, original bytes preserved in the bak. **Tests:** `testCorruptConfigBackupPreservesOriginalBytes`.
- Import a config with `launchAtLogin: true` from `Sanne.app` registers the login item. **Code:** `observeConfig()` calls `LaunchAtLogin.apply`.
- Existing tests plus new decode cases. 35+ tests green. **66 tests, 2026-08-14.**

---

## Phase 1 — Consolidate the product surface

**Goal:** A stranger can find the eight defaults without opening All bindings. Settings matches the designed IA. Cheat sheet matches reality.

Highest-leverage UX work. Engines stay; the map changes.

---

### 1.1 Collapse Settings to 8 pages ✅

**Today:** Home, All bindings, Magic Mouse, Windows, Keyboard, Apps, Dock, Menubar, Trackpad, Debug Log, About (11).

**Target**

```
Home
Magic Mouse
Trackpad
Windows          ← titlebar + Dock + Menubar + modifier-drag
Keyboard
Apps
Presets          ← export / import / reset / later Minimal
Advanced         ← All bindings, Debug Log, About, launch-at-login, HUD, haptics
```

**Files**

- `Sources/Sanne/UI/Preferences/PreferencesView.swift` (`Tab` enum, sidebar, page switch)
- `Sources/Sanne/App/MenuBarController.swift` (window title “Sanne Settings”)

**Do this**

1. Replace `Tab` cases. Dock and Menubar become **sections** on the Windows page (same `deviceZonePage` / `GestureEditorView(fixedGroup:)` pattern, stacked).
2. All bindings, Debug Log, and About move under Advanced (segmented control or inner list). Default Advanced landing: About.
3. New Presets tab: move Home’s Backup section (Export / Import / Reset) here. Confirm Reset and name what it wipes (custom scripts, app remaps, login, HUD).
4. Window title: **Sanne Settings**.
5. Keep the manual `HStack` + sidebar `List` (do not switch to `NavigationSplitView` — Form height still clips on macOS).

**Verify**

- Sidebar has 8 items. Dock / Menubar / Debug / About / All bindings are gone from the top level.
- Windows page scrolls: titlebar master + map + titlebar slots + Dock section + Menubar section + modifier-drag + gap.
- Advanced can still reach All bindings, Debug Log, and About.
- Reset lives on Presets and asks for confirmation.

---

### 1.2 Simple by default on every device page ✅

**Problem:** Every device page is the full remap list immediately, including 10 off-by-default gestures. Wireframe: Simple = toggles + diagrams + sensitivity; Advanced = full rule list.

**Files**

- `Sources/Sanne/UI/Preferences/PreferencesView.swift` (page headers)
- `Sources/Sanne/UI/Preferences/GestureEditorView.swift`
- `Sources/Sanne/Gestures/GestureSlots.swift` (mark defaults-visible vs advanced)

**Do this**

1. Add `Slot.visibility`: `.simple` (on by default, day-one) vs `.advanced` (off by default or power).
2. Simple Magic Mouse (day one): left tap, right tap, 3-finger middle, tap-drag, 1-finger page swipe. Plus master + sensitivity + L/R split. Multi-click stays an Options row.
3. Simple Trackpad: 3-finger tap, 3-finger drag, sensitivity. Tip-tap / 3F–4F swipes stay behind the disclosure.
4. Simple Windows / titlebar: halves, maximize, minimize, pinch close, pinch fullscreen. Quarters / thirds / 3F display behind disclosure.
5. Simple Dock: swipe up / down. Pinch new window visible; pinch quit behind disclosure.
6. Simple Menubar: swipe L/R. Hide others / unminimize behind disclosure.
7. Each page: **Show all gestures (N)** disclosure expands today’s `GestureEditorView` list for that group, including remaps.
8. Off-by-default 3F/4F/tip-tap/MM 3F stay hidden until expanded. Keep the System Settings conflict hint, but only when the user enables a conflicting chord (already mostly true; remove the always-on tip-tap wall of captions).

**Verify**

- Cold open of Magic Mouse shows ~5 gesture rows, not 17.
- Expanding “Show all” reveals the rest and remap capsules.
- Enabling 3F swipes still shows the macOS conflict hint.
- A remap on an advanced slot still appears under Show all + Modified filter.

---

### 1.3 One gesture catalog ✅

**Problem:** `GestureSlots` (54 slots) and `GestureCatalog` (cheat sheet) disagree. Cheat sheet omits 1-finger MM page swipes, still says “Middle-click” after a remap, and 12 IDs draw a keyboard tile (`CheatSheetView.swift`).

**Files**

- `Sources/Sanne/UI/Help/GestureCatalog.swift`
- `Sources/Sanne/UI/Help/CheatSheetView.swift`
- `Sources/Sanne/Gestures/GestureSlots.swift`
- `Sources/Sanne/UI/Theme/GestureDiagram.swift`

**Do this**

1. Drive the cheat sheet from `GestureSlots.all` + `BindingResolver.resolve`.
2. Each row: diagram, gesture title, **effective** action title, enable state. Disabled rows are dimmed.
3. “Edit in Settings” on a row opens Settings on that device page (and scrolls/highlights if cheap).
4. Keep only extras that are not slots: keyboard snap, modifier-drag, “same snap twice → restore.”
5. Fix `GestureDiagram.from(slotId:)` so every slot has a diagram. No keyboard-tile fallback for trackpad/MM slots.
6. Delete the parallel `GestureCatalog.Entry` IDs once the sheet compiles against slots. Keep `TutorialPrefs` (move it to its own small file if needed).

**Verify**

- Remap 3-finger tap → Close Tab. Cheat sheet says Close Tab.
- 1-finger MM page swipes appear.
- No cheat-sheet row draws a keyboard for a trackpad or mouse gesture.
- Search still works.

---

### 1.4 Home as status, not a junk drawer ✅

**Files**

- `Sources/Sanne/UI/Preferences/PreferencesView.swift` (`general`)

**Do this**

1. Keep: status card, connected devices (from 0.3), Pause, four masters, Tutorial / Cheat Sheet, conflict banner with **Pause Sanne**.
2. Move launch at login, haptics, HUD (“Action name overlay”), snap preview → Advanced (or Windows for preview).
3. Move Export / Import / Reset → Presets (1.1).
4. AX recovery: one button that both prompts and opens System Settings.
5. Status card uses real device counts. Do not show a green “Multitouch active” on a mouse-only Mac if the trackpad path failed (0.3).
6. If `TutorialPrefs.completed == false`, a quiet Home banner: **Take the 60-second tutorial**.

**Verify**

- Home is one screen without scrolling on a 560 pt window (or only the conflict/tutorial banners push it).
- Export is not on Home.
- Pause is the hero control.

---

### 1.5 Apps page rewrite ✅

**Problem:** One row drives pause and remaps. Unlabeled **Active** switch is bound to `disabled`. Add-app errors print on Home’s Backup caption.

**Files**

- `Sources/Sanne/UI/Preferences/PreferencesView.swift` (`apps`)
- `Sources/Sanne/UI/Preferences/AppGestureOverridesButton.swift`
- `Sources/Sanne/UI/Preferences/OrphanAppGestureRemapsSection.swift`

**Do this**

1. One row per app: icon (if available), name, subtitle = pause scope + remap count, chevron.
2. Visible control: **Pause Sanne while frontmost** (scope picker). No unlabeled switch.
3. **Customize gestures…** stays a clearly separate control.
4. Keep the orphan “Gesture bindings only” section (deleting a pause row must not hide remaps).
5. Surface add/import errors **on this page**, not Home.
6. “Add frontmost app” while Settings is frontmost must not pick `candidates.first`. Prefer: picker of running regular apps, or “Add application…” only.

**Verify**

- Add Safari → row shows “Pause: All Sanne · 0 remaps.”
- Add a remap → count updates.
- Delete pause row → remaps remain under “Gesture bindings only.”
- Failed add shows an error on Apps.

---

### 1.6 Tutorial, device-branched ✅

**Files**

- `Sources/Sanne/UI/Help/TutorialView.swift`
- `Sources/Sanne/TouchInput/TouchDeviceManager.swift` (device list from 0.3)

**Do this**

1. Detect whether a Magic Mouse is connected at tutorial open.
2. **Trackpad-only path:** skip MM tap. Steps: welcome → titlebar snap → 3-finger middle-click → Dock swipe up (optional) → done. One line of “Connect a Magic Mouse for silent taps.”
3. **Magic Mouse path:** welcome → left tap → titlebar snap → middle-click (2F or 3F) → done.
4. One gesture per screen. Show `GestureDiagramView` at ~80 pt, not only an SF Symbol well.
5. Delete the “Keyboard & more” bullet dump. Keyboard / modifier-drag / remap belong on the done screen as a single sentence: “⌃⌥ arrows snap. Remap anything in Settings.”
6. Keep Skip / Skip step / live signals / auto-advance.

**Verify**

- Unplug mouse → no “Waiting for a left tap” step.
- Plug mouse → tap step appears and completes on a real left tap.
- Done screen is short. Tutorial still ≤90 s if the user performs the gestures.

---

### 1.7 Remap in one click from the row ✅

**Problem:** Wireframe: customization is one click from any default row. Today: Settings → tab → scroll → capsule → 460×540 sheet.

**Files**

- `Sources/Sanne/UI/Preferences/GestureEditorView.swift` (`ActionPickerSheet`)

**Do this**

1. Clicking the action capsule opens a **popover** (or menu) of the common ~15 actions: snaps, clicks, Mission Control / Exposé, browser tabs, none.
2. Footer: **More…** opens today’s full sheet (search, Record keystroke, Open app, Scripts).
3. Keep the sheet for anything that needs a recorder or file picker.
4. Per-row Reset stays on the row.

**Verify**

- Change swipe-right from Right half → Left half in one popover click, no sheet.
- More… still reaches scripts and recorded keystrokes.
- Per-app editor uses the same popover.

---

## Phase 2 — Consolidate the data model

**Goal:** One enablement story. A gesture is on or off in one place. Existing 0.2.0 configs load with identical behaviour.

Do this **after** Phase 1 can live on slots alone, or the UI rewrite will keep writing both layers.

### The mess

A gesture can be off in five ways:

1. Global `paused`
2. Per-app pause scope
3. Section master (`magicMouseTaps.enabled`)
4. Legacy bool (`leftTap`, `swipeHalves`, …)
5. Slot override `enabled`

Recognition still reads the legacy bools. Remap UI writes overrides, then a 40-case `enableLegacyGate` (`GestureBinding.swift`) tries to keep them in sync. `legacyEnabled` (`GestureSlots.swift`) is the same 40-case switch in reverse.

That is why a per-app “enable this gesture” can turn the section on globally, and why a remap cannot revive a gesture `MagicMouseTapController` never emits.

---

### 2.1 Inventory and test the current matrix ✅

**Files**

- `Sources/Sanne/Gestures/GestureSlots.swift`
- `Sources/Sanne/Config/GestureBinding.swift`
- `Sources/Sanne/Config/ConfigModels.swift`
- `Tests/SanneTests/BindingResolverTests.swift`
- `Tests/SanneTests/ConfigRoundTripTests.swift`

**Do this**

1. Write a table test: for every `GestureSlots.Slot`, assert `legacyEnabled(gate)` matches the config field `enableLegacyGate` writes.
2. Write a test: override `enabled: true` cannot revive a slot whose recognizer still keys off `cfg.leftTap == false` (documents the bug; will go green in 2.3).
3. Snapshot a real 0.2.0 `config.json` fixture (legacy bools + some overrides + app remaps + a custom action).

**Verify**

- Tests encode today’s behaviour, including the dual-enable bug. Do not “fix” behaviour in this step.

---

### 2.2 Masters only as group switches ✅

**Do this**

1. Keep four masters: Magic Mouse, Titlebar, Dock, Menubar. Trackpad stays always-on (`masterEnabled(.trackpad) == true`).
2. UI already has these masters. Stop writing per-gesture legacy bools from Simple toggles — Simple rows write `gestureOverrides[id].enabled` instead.
3. Recognition still reads legacy bools until 2.3, so `enableLegacyGate` remains for one release. Simple-row writes must go through it so behaviour does not change yet.

**Verify**

- Toggling “Tap left” in Simple still turns the gesture off.
- Master off still disables the whole group, including remapped slots.

---

### 2.3 Recognition reads BindingResolver only ✅

**Files**

- `Sources/Sanne/TouchInput/MagicMouseTapController.swift`
- `Sources/Sanne/Gestures/GestureEngine.swift`
- `Sources/Sanne/Gestures/Recognizers/*.swift`

**Do this**

1. At session start (or on config change), snapshot enabled slot IDs from `BindingResolver` for the current frontmost app.
2. `MagicMouseTapController` and the trackpad engine consult that snapshot, **not** `cfg.leftTap` / `cfg.swipeHalves` / …
3. A slot override `enabled: true` can now revive a gesture. A per-app enable still cannot revive a **master** that is off (resolver already does this).
4. Delete calls to `enableLegacyGate` from the editor once recognition no longer needs the bools kept in sync.

**Verify**

- Disable left tap via the row → no left clicks.
- Remap a disabled-by-default 3F swipe on, without flipping `threeFingerSwipes` → gesture fires. **Tests:** `testOverrideEnabledTrueRevivesSlotEvenWhenLegacyGateIsOff`. Magic Mouse path now consults `BindingResolver`.
- Master off → nothing in that group fires, even with per-app enables.
- The 2.1 “cannot revive” test now expects success.

---

### 2.4 Migrate and delete the ~40 bools 🟡

**Keep as real config (not enable flags):** sensitivity, left/right split, dead zone, window gap, HUD enabled, keyboard chord options, modifier-drag modifier arrays, launch at login.

**Delete after migrate:** `leftTap`, `rightTap`, `middleTwoFinger`, `middleThreeFinger`, `tapDrag`, `multiClick` (special: not a slot — keep as an option or promote to a slot), `twoFingerDoubleTapMissionControl`, `twoFingerSwipeUpMissionControl`, `twoFingerSwipeDownAppExpose`, `twoFingerSwipeSpaces`, `threeFingerSwipes`, `twoFingerTopEdgeMove`, `oneFingerSwipePages`, and the matching titlebar / dock / menubar / trackpad enable bools.

**Do this**

1. Bump `SanneConfig.version` to `2`.
2. Add `migrate(from:)` in `ConfigStore.load`:
   - For each slot, if no override exists, write `enabled` from the legacy bool.
   - Then drop the legacy keys on the next save (or stop encoding them).
3. Decode still accepts the old keys so 0.2.0 files load.
4. Generate `sanne.standard.json` from `GestureSlots.all` in a test so the bundled file cannot drift from code defaults (0.2.0 bundled JSON is already missing `hud` and `appGestureOverrides`).
5. Delete `enableLegacyGate`, `legacyEnabled`, and `LegacyGate` once nothing reads them.
6. `multiClick` has no remappable slot. Keep it as `MagicMouseTapConfig.multiClick` (an option, not a gate for a slot) **or** add a slot. Prefer keep-as-option.

**Verify**

- 0.2.0 fixture loads. Every gesture that was on stays on; every gesture that was off stays off; remaps survive; custom actions survive; HUD stays on. **Partial:** `migrateToSlotEnablement()` + version 2 + `defaultEnabled` + fixture test. Legacy bools still exist on the model (decode + unused for recognition). `enableLegacyGate` still present for editor writes. Delete the bools in a follow-up.
- New install writes version 2 without the deleted keys.
- `swift test` includes migrate + “bundled Standard == GestureSlots defaults.”

---

## Phase 3 — Refactor the engines

**Goal:** The code matches the architecture in [TECHNICAL_DESIGN.md](./TECHNICAL_DESIGN.md). Each split ships with tests for the piece you extract.

Surgical. Do not rewrite files that are not on this list.

---

### 3.1 Split PreferencesView and GestureEditorView ✅

**Why:** 956 + 872 lines. Phase 1 will keep piling on unless the files are split.

**Do this**

1. One file per tab: `HomePage.swift`, `MagicMousePage.swift`, `TrackpadPage.swift`, `WindowsPage.swift`, `KeyboardPage.swift`, `AppsPage.swift`, `PresetsPage.swift`, `AdvancedPage.swift` under `UI/Preferences/Pages/`.
2. `PreferencesView.swift` keeps only the sidebar shell + tab switch.
3. Pull `ActionPickerSheet` and `KeystrokeRecorderSheet` out of `GestureEditorView.swift`.
4. Do not rewrite comments into essays. Delete narrative comments that only restate the code.

**Verify**

- Every Settings page still renders. No behaviour change. **Code:** `PreferencesView` is the sidebar shell; pages live under `UI/Preferences/Pages/`; `ActionPickerSheet` and `KeystrokeRecorderSheet` are their own files.
- `swift build` zero warnings. **78 tests, 2026-08-14.**

---

### 3.2 Split MagicMouseTapController (1,313 lines) ✅

Highest-risk file. Zero tests today.

**Extract, in this order**

| Piece | Responsibility |
|-------|----------------|
| Device I/O | Share the enumerator with trackpad (0.3) |
| `ScrollLock` | 0.75 / 0.90 / 0.40 s locks; residual re-arm |
| `PhysicalClickGuard` | 80 ms suppress + 60 ms synthetic echo |
| `MMTapMachine` | Left / right / multi-click |
| `MMSwipeMachine` | 1F pages, 2F, 3F — one swipe primitive |
| `MMDragSession` | Double-tap-hold |
| `MMWindowMove` | Top-edge drag, via the engine (not `TouchWindowMover` inline) |

**Also fix while splitting**

1. **One `killSession()`.** Reset is copy-pasted four times (~40 lines each): `resetUnlocked`, `killSessionUnlocked`, `endActiveDragUnlocked`, `endWindowMoveUnlocked`.
2. **Dead zone actually rejects.** Design §7.4: 0.45–0.55 is dead. Code (`MagicMouseTapController` ~1054): anything not right is left. Center taps become left clicks.
3. **Wire `PalmRejector` into `MMTapMachine`, or delete `PalmRejector.swift`.** Live path never calls it.
4. **Delete `TapRecognizer.processMagicMouse`** (~180 lines, zero callers).
5. Recognition uses the Phase 2 enabled-slot snapshot.
6. Top-edge move emits `GestureSlots.ID.mm2fTopEdgeMove` and goes through `GestureEngine.perform` / `ActionRunner`. Remapping the slot must work (or stay `actionFixed` **and** be documented as such).
7. **Stop reading `@MainActor` config from the Multitouch thread.** Snapshot config onto the pipeline queue at start / on `sanneConfigDidChange`.
8. Revisit the **320 ms delay** on 2-finger middle-click when 2F double-tap Mission Control is also on. Every browser-tab middle-click waits a third of a second. Prefer: if double-tap MC is off, fire middle immediately; if on, keep the delay **or** use travel/hold to disambiguate without a fixed 320 ms.

**Verify**

- Pure tests: dead-zone classification, `Thresholds`, `swipeAxis`, scroll-lock re-arm, physical-click window. **Tests:** `MagicMouseLogicTests`. Center taps are `.dead`, not left.
- Hardware: left/right/middle, tap-drag, no ghost clicks after scroll, 3F swipe vs middle (travel decides, never both), top-edge move. **Still needed for 5.2.**
- `processMagicMouse` is gone. `rg processMagicMouse` is empty. **`TapRecognizer.swift` and `PalmRejector.swift` deleted.** Config is snapshotted off the Multitouch thread. One `killSessionUnlocked` + `resetUnlocked`.

---

### 3.3 GestureEngine: zone apply + one 3-finger tap ✅

**Files**

- `Sources/Sanne/Gestures/GestureEngine.swift`
- `Sources/Sanne/Gestures/Recognizers/TapRecognizer.swift`
- `Sources/Sanne/Gestures/Recognizers/ThreeFingerDragRecognizer.swift`

**Do this**

1. Collapse `applyTitlebar` / `applyDock` / `applyMenubar` to `runSlot` plus titlebar preview. Dock/menubar are already thin.
2. Always use `ThreeFingerDragRecognizer`’s travel-aware `.tap`. Delete `TapRecognizer.processTrackpadThreeFingerTap`. That path never updates `lastPos`, so with 3-finger drag **off**, a 3-finger wiggle still middle-clicks.
3. If `TapRecognizer` is then empty, delete the file.
4. Introduce a small `GestureSession` (zone, window, dock app, peak fingers, frontmost bundle, pinch candidate) instead of six loose flags.
5. Keep free-space arbitration as-is (drag > swipe > tap; peak fingers sticky). It is sound.

**Verify**

- New test: 3F tap with travel above the tap threshold does **not** fire when drag is off (the old bug). **Tests:** `ThreeFingerTapTests`. 4F tap uses a second travel-aware `ThreeFingerDragRecognizer`.
- Titlebar preview still appears and commits on lift. **Code:** preview stays in `applyTitlebar`; Dock/menubar only `runSlot`. `GestureSession` holds zone/window/dock/peak/frontmost/pinch.
- 4F chord decaying to 3F still fires only the 4F slot.

---

### 3.4 One window-motion path ✅

**Problem:** Four movers (titlebar snap, keyboard, modifier-drag, MM top-edge) have already drifted. AX↔AppKit conversion is copied in four files. `setFrame` always returns `true`. Window identity is `pid + title` (tab titles orphan restore).

**Files**

- `Sources/Sanne/Windowing/WindowManager.swift`
- `Sources/Sanne/Windowing/LayoutGeometry.swift`
- `Sources/Sanne/Windowing/RestoreStore.swift`
- `Sources/Sanne/Windowing/ModifierDragController.swift`
- `Sources/Sanne/Windowing/TouchWindowMover.swift`
- `Sources/Sanne/Windowing/SnapPreviewWindow.swift`
- `Sources/Sanne/Keyboard/KeyboardSnapMonitor.swift`
- `Sources/Sanne/Actions/ActionRunner.swift`

**Do this**

1. Extract `LayoutGeometry.appKitToAX` / `axToAppKit` as the **only** coordinate helpers. Delete the copies in `WindowManager`, `SnapPreviewWindow`, `ModifierDragController`.
2. `setFrame` must check `AXError`. On failure return `false`. Do not haptic / HUD on a no-op. Log the AX error.
3. Window identity: `pid + CGWindowNumber` (as [TECHNICAL_DESIGN.md](./TECHNICAL_DESIGN.md) §10.5 specified), not `pid + title`.
4. Keyboard snap calls `ActionRunner` (see 3.5). HUD and remaps come for free.
5. One `WindowMover` session type (`begin` / `update` / `end`) used by modifier-drag and MM top-edge. They are the same delta transform today.
6. Skip Sanne’s own PID in `windowAt` / snap (modifier-drag already does this).
7. One thirds policy for **gestures**: either discrete long-swipe **or** continuous cycle (Phase 4). Do not invent a third. Keyboard cycle can stay half → third → two-thirds until 3.5, but document it.
8. Add catalog action `window.restore`. Second same-layout swipe still restores. Preview on that second swipe should show the **restore** frame, not another left-half ghost.

**Verify**

- `LayoutGeometry` unit tests: every layout at gap 0 and 8; thirds sum; invertibility of AX↔AppKit with an injected primary height. **Tests:** `LayoutGeometryTests`.
- `RestoreStore`: first-write-wins, pop-once, two windows with the same title do not collide. **Identity is `pid + CGWindowNumber`.** Same title / different pid (and same pid / different window number) do not collide. **Tests:** `RestoreStoreTests`.
- Snap a Chrome window, change the tab title, same-layout swipe still restores. **Code:** identity no longer uses title. Hardware confirm still for 5.2.
- Failed AX set → no haptic, no success HUD. **Code:** `setFrame` already returns false; ActionRunner shows “No window” / “Restore” via HUD. Preview of a second same-layout swipe shows the stored restore frame. Gesture thirds stay discrete long-swipes; keyboard cycle stays half → third → two-thirds.

---

### 3.5 Keyboard is a first-class slot family ✅

**Problem:** `KeyboardSnapMonitor` is a sidecar. Hardcoded chord. Global monitor cannot swallow keys (Terminal still sees ⌃⌥←). No remap, no HUD. Down arrow is **almost-maximize** while titlebar down is **minimize**.

**Files**

- `Sources/Sanne/Keyboard/KeyboardSnapMonitor.swift`
- `Sources/Sanne/Gestures/GestureSlots.swift` (or new `HotkeySlots.swift`)
- `Sources/Sanne/Actions/ActionRunner.swift`
- `Sources/Sanne/UI/Preferences/Pages/KeyboardPage.swift`

**Do this**

1. Represent ⌃⌥←/→/↑/↓/↩ and ⌃⌥⌘←/→ as slots (or `HotkeySlots`) with default actions matching today’s behaviour **except** ↓.
2. Change ↓ default to **restore** (or bottom half). Almost-maximize stays a catalog action the user can remap onto ↓.
3. Run every fire through `ActionRunner` so HUD / haptics / logging match gestures.
4. Replace `NSEvent.addGlobalMonitor` with a `CGEvent` tap so Sanne can consume the chord. Request Input Monitoring only when keyboard snap is enabled (progressive permission, [TECHNICAL_DESIGN.md](./TECHNICAL_DESIGN.md) §5).
5. Do **not** add Hyper, WASD, or arbitrary key remaps in this step.

**Verify**

- ⌃⌥← snaps and the HUD says the layout. **Code:** slots `keyboard.chord.*` fire through `ActionRunner` + HUD. Repeat ←/→ still cycle thirds when that option is on.
- Terminal does not also receive the arrow. **Code:** `CGEvent` tap consumes the chord. Input Monitoring is requested only while keyboard snap is enabled. Hardware confirm still for 5.2.
- ↓ restores (or bottoms) as documented on the Keyboard page. **Default action is `window.restore`.** Almost-maximize remains a catalog action.
- Disabling keyboard snap on the Keyboard page stops all of the above. **Code:** master `keyboard.enabled` removes the tap.

---

### 3.6 ActionRunner cleanup ✅

**Files**

- `Sources/Sanne/Actions/ActionRunner.swift`
- `Sources/Sanne/Actions/ActionCatalog.swift`
- `Sources/Sanne/InputSynth/ClickEmitter.swift`
- `Sources/Sanne/InputSynth/KeyEmitter.swift`

**Do this**

1. Replace the 17 `window.snap.*` switch cases with `ActionCatalog.snapLayout(for:)`.
2. Move `usleep` off the main actor (`ClickEmitter` 12 ms, `KeyEmitter` 8 ms). Sleep on the emitter’s own queue, then hop back if needed.
3. Failed snap / skipped script / no window → HUD error (short, e.g. “No window”), not silence. Success-only HUD is why remaps feel dead.
4. Restore announces “Restore”, not “Snap left half.”
5. Launch-app / script HUD: “Running {name}…” is honest; do not imply completion. Optional follow-up on failure via Debug Log is enough.
6. Scripts: change `/bin/zsh -lc` to `zsh -c` (or `/bin/sh -c`) so a gesture does not load `.zprofile`. Keep 10 s / 4-slot limits. Settings copy already interpolates `CustomActionLimits` — keep that.
7. Fix `KeyEmitter` log category (today it logs under `.click`).
8. Delete the stale “event tap thread” comment on `runCustomAction`.

**Verify**

- Adding a new `WindowLayout` does not require a new `ActionRunner` case. **Code:** `ActionCatalog.snapLayout(for:)`.
- A snap with no window shows an error HUD. **Code:** `ActionRunResult.errorTitle` → “No window”. Restore announces “Restore”. Scripts/apps announce “Running {name}…”.
- A script of `sleep 30` still dies at 10 s and logs timeout. **Code:** `zsh -c` (no login profile). 10 s / 4-slot limits unchanged.
- Main-thread hitch during a click is gone (no `usleep` on MainActor; Instruments or a breakpoint in `ClickEmitter.click`). **Code:** `ClickEmitter` / `KeyEmitter` sleep on their own queues. KeyEmitter logs under `.key`.

---

## Phase 4 — Features to add

Only after Phases 0–3. Ordered by week-one value.

---

### 4.1 Add now (product-complete v1.0)

#### 4.1.a Minimal preset ✅

Taps + halves only. The 70% who never customize need an escape from 54 slots.

- Presets page: **Sanne Standard** (current) and **Minimal**.
- Minimal: MM left/right/middle/drag on; titlebar halves + maximize + minimize on; everything else off. No Dock/Menubar/free-space extras.
- Switching presets confirms if the user has remaps.
- This is the first real use of `presetId`.

**Verify:** `SannePreset` + `presetId` select slot defaults in `BindingResolver`. Presets page applies Standard / Minimal; remaps confirm. Drift shows Custom. **Tests:** `PresetTests`.

#### 4.1.b Connected-device empty states ✅

Shipped in spirit by 0.3 / 1.4. Confirm Magic Mouse page, Trackpad page (no pad), and Home all agree.

**Verify:** Home lists `connectedDeviceLine`. Magic Mouse: “Connect a Magic Mouse to configure taps.” Trackpad: “Connect a trackpad to configure gestures.” Slot lists dim when the device is missing. Tuning stays editable.

#### 4.1.c Live “you just did this” in Settings ✅

While Settings is frontmost, a fired gesture flashes / scrolls to its row. Teaches the map without a capture sheet (UX-04 lite). Do not implement full “perform gesture to capture” yet.

**Verify:** `GestureActivity.announce` from the engine, Magic Mouse path, and keyboard tap. Settings switches sidebar, expands Show all if needed, scrolls and flashes the row.

#### 4.1.d Conflict coach ✅

- Add verified bundle IDs for Multitouch.app and TapToClick (today Multitouch is name-heuristic only; `"middle"` false-positives).
- Banner: **Also running: {app}. Using both can break recognition.** Actions: **Pause Sanne** / **Dismiss**.
- Do not force-quit the other app.

**Verify:** `com.brassmonkery.Multitouch` + `com.larabr.taptoclick` in the table. `"Middle"` is not a conflict. Home banner has Pause / Dismiss. **Tests:** `CompetingAppsTests`.

#### 4.1.e Restore as a catalog action ✅

Depends on 3.4. Bindable. Preview shows the restore frame on the second same-layout swipe. Cheat sheet row stays, now backed by a real action. **Landed with 3.4 / 3.5 (`window.restore`, Keyboard ↓ default).**

#### 4.1.f HUD + haptics on keyboard ✅

Free once 3.5 lands. Confirm Settings → Advanced still toggles both. **Keyboard fires go through `ActionRunner` + HUD.**

#### 4.1.g Settings search (UX-10) ✅

Index page titles, toggle labels, slot titles, action titles. Selecting a hit switches sidebar and highlights the row. “launch at login”, “haptics”, “gap”, “HUD” must all resolve.

**Verify:** Search field above the sidebar. Those four queries resolve. Slot hits switch page and highlight. **Tests:** `SettingsSearchTests`.

#### 4.1.h Accessibility pass ✅

- Every remap toggle: `accessibilityLabel("Enable \(slot.title)")`. Stop `Toggle("", …).labelsHidden()` without a label.
- `GestureDiagramView`: do not use `.accessibilityHidden(true)` without an alternative. Label: “Magic Mouse, tap left.”
- Honor Reduce Motion: HUD and tutorial progress skip fades.
- Menu icon already has `accessibilityDescription: "Sanne"`. Keep it. Permission badge (0.2) must not be color-only.

**Verify:** Remap checkbox and `GestureToggleRow` labeled. Diagrams speak “Magic Mouse, tap left.” HUD skips fade when Reduce Motion is on; tutorial progress bar does not animate. Status item badge uses “Sanne — needs Accessibility”, not color alone.

---

### 4.2 Add next (v1.1) ✅

Code landed 2026-08-14. Hardware confirm still needed with 5.2.

| ID | Feature | Notes |
|----|---------|-------|
| 4.2.a | Continuous thirds cycle on long swipe ✅ | `LayoutGeometry.continuous*Layout`. Preview updates. Long L/R stays on the short slot when `keyboard.cycleThirds` is on. **Tests:** `ContinuousThirdsTests`. |
| 4.2.b | Window-to-Space ✅ | `experimental.windowToSpace` off by default. `SpaceMover` via CGS `dlsym`. HUD on failure. **Tests:** `SpaceMoverTests`. |
| 4.2.c | MM 3-finger top-edge resize ✅ | Slot `mouse.surface.3.topEdge.dragResize`. Same top-edge + cursor-travel gate as 2F move. `WindowMover` resize mode. |
| 4.2.d | Gaming mode ✅ | `magicMouseTaps.gamingMode` off by default. Physical right-hold + left tap. **Tests:** `GamingModeTests`. |
| 4.2.e | Safe mode ✅ | Option at launch → Standard in memory, no write to `config.json`. Home banner + menu status. **Tests:** `SafeModeTests`. |
| 4.2.f | Sparkle or GitHub update check ✅ | GitHub Releases GET from menu bar and Advanced. No Sparkle dep. **Tests:** `UpdateCheckerTests`. |
| 4.2.g | Homebrew cask ✅ | [docs/homebrew/sanne.rb](./docs/homebrew/sanne.rb). Publish when a public DMG URL exists. |

---

### 4.3 Later — only if users ask

Hyper key, WASD/IJKL, custom snap percentages, 3×2 / 3×3 grids, adjacent-divider resize, edge drag-to-snap, “perform gesture to capture,” add-arbitrary-gesture, open URL/file, volume/brightness, Show Desktop / Launchpad, on-release action pairs.

These are how Sanne becomes BTT. [PRD.md](./PRD.md) §6.2 and [MVP_SCOPE.md](./MVP_SCOPE.md) §6.2 already said no.

---

### 4.4 Do not add

- Drawing gestures, floating menus, launcher, Touch Bar, Stream Deck
- Cloud sync
- Appearance picker (already follows system)
- Click sound (silent is the point)
- A second gesture editor
- More sidebar items

---

## Phase 5 — Quality bar

**Goal:** Call it 1.0 only when the verify lines below are green.

---

### 5.1 Tests to write first (no hardware)

Highest ROI. Several can land during Phases 2–3 rather than waiting.

| # | Test | When |
|---|------|------|
| 1 | `LayoutGeometry.targetFrame` for every layout at gap 0 and 8 — thirds sum, adjacency | 3.4 ✅ |
| 2 | `RestoreStore` first-write-wins + pop-once + identity | 3.4 ✅ |
| 3 | `ActionCatalog.snapLayout` round-trip; every `ID.*` appears in `all` | 3.6 ✅ |
| 4 | 3F tap movement (locks the `lastPos` bug, then the function dies) | 3.3 ✅ |
| 5 | MM dead-zone classification + `Thresholds` + `swipeAxis` as pure functions | 3.2 ✅ |
| 6 | `PrivateMT.isMagicMouseDevice` table: built-in / Force Touch / opaque / neither | 0.3 / 3.2 ✅ |
| 7 | Config migrate: 0.2.0 JSON → slot-only enablement, behaviour unchanged | 2.4 ✅ `testVersion020FixtureMigratesEverySlotUnchanged` |
| 8 | `BindingResolver` + “does the controller emit?” matrix | 2.3 ✅ `testEmitMatrixMatchesResolverForEverySlot` |
| 9 | `announcesInHUD` for `none`, unknown, launch-app, restore | 3.6 ✅ |
| 10 | Bundled `sanne.standard.json` == `GestureSlots` defaults | 2.4 ✅ `testBundledStandardJSONMatchesGestureSlotsDefaults` |

Existing 35 tests (resolver, tip-tap, free-space swipe, catalog IDs, config round-trip) stay green. Do not weaken them.

---

### 5.2 Hardware QA

Run from `dist/Sanne.app`. This is [PROGRESS.md](./PROGRESS.md) items 4–21 plus the leaks this plan adds.

**Core delight (must pass)**

1. Magic Mouse left / right / middle. No click when hovering above the surface.
2. No ghost clicks for 1 s after a scroll.
3. Dead-zone center tap does **not** left-click.
4. Tap-drag: double-tap-hold moves a file in Finder.
5. Titlebar: halves, maximize, minimize, preview, restore-on-repeat.
6. Titlebar on Chrome and VS Code (custom chrome, 52 pt strip).

**Zones and keyboard**

7. Dock swipe up / down on an icon. Autohide dock.
8. Menubar swipe L/R. Swipe-down hide-others is easy to clip — confirm it is not firing from the titlebar.
9. Keyboard snap after 3.5: chord is consumed; HUD shows; ↓ matches Settings copy.
10. Modifier-drag move/resize from window body. Does not grab Sanne’s own windows.

**Opt-in gestures**

11. Free-space 3F swipes — turn macOS equivalents off first. One fire per swipe. If 3F drag is also on, drag wins the session.
12. Free-space 4F swipes + 4F tap. 4→3 decay fires only 4F.
13. Tip-tap left / right. Two-finger scrolling produces no phantom tip-taps.
14. Magic Mouse 3F swipes vs middle-click. Travel decides. Never both.

**Product**

15. Tutorial from a fresh welcome (0.1), both device branches (1.6).
16. Per-app bindings, orphaned bindings, uninstalled app, missing action.
17. HUD: placement on a secondary display, mid-fade re-show, **never steals focus**, toggle off.
18. Export → import UI path (not only the unit test).
19. Sleep/wake 10×. Unplug/replug Magic Mouse.
20. Multi-monitor throw, including stacked displays after 0.3 (L/R only is OK for 1.0; document stacked as a limitation unless 4.2 adds U/D).

---

### 5.3 Compatibility matrix (before 1.0)

| App | Titlebar snap | Restore | Notes |
|-----|---------------|---------|-------|
| Finder | | | |
| Safari | | | Tab title change must not break restore (3.4) |
| Chrome | | | Custom chrome / no `AXTitleBar` |
| Terminal | | | Keyboard chord must not double-fire (3.5) |
| Xcode | | | Inspectors / no focused window |
| Slack | | | Electron |
| VS Code | | | Electron, custom titlebar |
| Fullscreen Space | | | Must not silently “succeed” (`setFrame` false + HUD) |
| Stage Manager | | | Document if broken |

Also: laptop + external display side-by-side; laptop lid closed, mouse only.

---

### 5.4 v1.0 launch checklist

Carry forward from [MVP_SCOPE.md](./MVP_SCOPE.md) §7.5 and [PROGRESS.md](./PROGRESS.md) Phase 2:

- [ ] First-run + tutorial verified on a clean account
- [ ] Settings is 8 pages; Simple is the default
- [ ] Cheat sheet matches remaps
- [ ] `LICENSE` + `CONTRIBUTING.md` (already present)
- [ ] Privacy: local-only, short README section ✅
- [ ] Menu bar template icon + permission badge ✅ (Phase 0.2)
- [ ] App icon set (CHANGELOG still lists this as planned)
- [ ] Notarized DMG + GitHub Release
- [ ] Optional Sparkle / GitHub update check ✅ GitHub Releases check (4.2.f)
- [ ] Homebrew cask or documented path ✅ sketch at `docs/homebrew/sanne.rb`
- [ ] Hardware QA 5.2 green
- [ ] Compatibility matrix 5.3 filled
- [ ] Trademark / name clearance for “Sanne” (still open in the PRD)

---

## Consolidation map

| Collapse this | Into this | Phase |
|---------------|-----------|-------|
| Dock tab + Menubar tab | Windows page sections | 1.1 |
| Debug Log + About + All bindings | Advanced | 1.1 |
| Home Backup | Presets | 1.1 |
| Home haptic / HUD / preview / login | Advanced or Windows | 1.4 |
| `GestureCatalog` | `GestureSlots` + BindingResolver | 1.3 |
| ~40 legacy bools | Slot `enabled` + 4 masters | 2.4 |
| `enableLegacyGate` + `legacyEnabled` | One snapshot of enabled slot IDs | 2.3–2.4 |
| `TapRecognizer.processMagicMouse` + unused `PalmRejector` | Live MM tap machine (or delete) | 3.2 |
| Dual 3F tap paths | `ThreeFingerDragRecognizer` only | 3.3 |
| Keyboard sidecar + MM top-edge + modifier-drag copies | ActionRunner + one `WindowMover` | 3.4–3.5 |
| Four AX↔AppKit conversions | `LayoutGeometry` only | 3.4 |
| Pause-an-app vs remap-an-app on one unlabeled row | Apps page: two labeled controls | 1.5 |
| Cheat sheet + Settings + All bindings + per-app sheet as four truths | Settings row is canonical; others project it | 1.3 |

---

## Out of scope for this plan

Recorded so they are not mistaken for gaps:

- Growing the action catalog (volume, brightness, Show Desktop, open URL)
- Hyper key, Caps Lock remap, arbitrary key remaps
- Drawing gestures, floating menus, launcher
- Cloud sync, iCloud presets
- Third-party (non-Apple) mice
- XPC privilege separation
- Rewriting MultitouchSupport behind a new abstraction “for cleanliness” without the device-identity fix in 0.3

Longer-term product direction still lives in [PRD.md](./PRD.md) §15.3–15.4 and [PROGRESS.md](./PROGRESS.md) Phase 3–4.

---

## How to update this file

1. Flip ⬜ → 🟡 when a step starts; 🟡 → ✅ only when its **Verify** line is true.
2. If you skip a step, mark ➖ and write one sentence why.
3. Mirror user-visible landings into [PROGRESS.md](./PROGRESS.md), [README.md](./README.md), and [CHANGELOG.md](./CHANGELOG.md).
4. Do not copy hardware QA checklists into [PLAN_PROGRESS.md](./PLAN_PROGRESS.md). That file owns the 0.2.0 BTT/Multitouch parity work. This file owns everything after.

---

*End of improvement plan*
