# BTT / Multitouch Parity — Step Tracker

**Plan:** [.junie/plans/btt-multitouch-parity-features.md](./.junie/plans/btt-multitouch-parity-features.md)
**Last updated:** 2026-08-10
**Where we are:** Steps 1–6 are **code complete and build clean**. Nothing in this plan has been
exercised on hardware yet, and the test target the plan called for was never created.
**Next step:** [Step 7 — code review](#step-7--code-review-of-steps-16).

This file tracks *execution of one plan*, step by step, so work can stop and resume without losing
the thread. Four documents describe this work; keeping them from drifting into duplicates means
keeping to their lanes:

| Document | Owns |
|----------|------|
| **PLAN_PROGRESS.md** (this file) | Per-step execution detail: what each step delivered, which files, what is *proven* vs merely compiling, what to pick up next |
| [PROGRESS.md](./PROGRESS.md) | Product-wide status tables and the **numbered** hardware QA checklist — cited from here by number, never copied |
| [CHANGELOG.md](./CHANGELOG.md) | User-facing prose for release notes |
| [README.md](./README.md) | The feature list and the off-by-default rationale |
| [the plan](./.junie/plans/btt-multitouch-parity-features.md) | The original spec. **Historical** — its step headings carry ✅ marks for orientation only; record progress here, not there |

---

## Status legend

Same marks as [PROGRESS.md](./PROGRESS.md), applied per column rather than per feature:

| Mark | Meaning |
|------|---------|
| ✅ | Done / verified |
| 🟡 | Implemented, needs polish or more testing |
| 🔴 | Not started / blocked |
| ⬜ | Planned, not started |

**Read the columns literally.** `Code ✅` means the code exists and compiles. It does **not** mean the
gesture has ever fired on a real trackpad — that is what `Hardware QA` is for. No step in this plan
has earned a ✅ in that column.

---

## At a glance

| Step | Feature | Code | Docs | Tests | Hardware QA | On by default? |
|------|---------|------|------|-------|-------------|----------------|
| [1](#step-1--free-space-3f4f-swipes--4f-tap) | Free-space trackpad 3F/4F swipes + 4F tap | ✅ | ✅ | 🔴 | 🔴 PROGRESS 14, 15 | No — macOS claims the chords |
| [2](#step-2--tip-tap) | Tip-tap left / right | ✅ | ✅ | 🔴 | 🔴 PROGRESS 16 | No — shares the pad with scrolling |
| [3](#step-3--magic-mouse-3-finger-swipes) | Magic Mouse 3-finger swipes | ✅ | ✅ | 🔴 | 🔴 PROGRESS 17 | No — easy to hit while gripping |
| [4](#step-4--custom-script-actions) | Shell / AppleScript / Shortcuts actions | ✅ | ✅ | 🔴 | 🔴 PROGRESS 18 | n/a — inert until you add one |
| [5](#step-5--per-app-gesture-bindings) | Per-app gesture bindings | ✅ | ✅ | 🔴 | 🔴 PROGRESS 19 | n/a — inert until you bind one |
| [6](#step-6--action-hud-overlay--docs) | Action HUD overlay + doc updates | ✅ | ✅ | 🔴 | 🔴 PROGRESS 20, 21 | **Yes** — `hud.enabled` |
| [7](#step-7--code-review-of-steps-16) | Code review of steps 1–6 | ⬜ | — | — | — | — |
| [8](#step-8--sannetests-target) | `SanneTests` target + pure-logic tests | ⬜ | — | — | — | — |
| [9](#step-9--hardware-qa-sweep) | Hardware QA sweep | ⬜ | — | — | — | — |
| [10](#step-10--config-round-trip-verification) | Config round-trip verification | ⬜ | — | — | — | — |
| [11](#step-11--release-prep) | Release prep | ⬜ | — | — | — | — |

**Build gate (re-run after any change):**

```bash
swift build     # must succeed with zero warnings
```

Currently: **passing, zero warnings.**

---

## Completed steps

### Step 1 — Free-space 3F/4F swipes + 4F tap

**Delivered.** Trackpad swipes with 3 or 4 fingers anywhere on the pad (L/R/U/D each), plus a
4-finger tap, each remappable to any catalog action like every other slot.

| What | Where |
|------|-------|
| Slot ids | `GestureSlots.ID.free3Swipe{Left,Right,Up,Down}` → `trackpad.free.3.swipe.*`; `free4Swipe*` → `trackpad.free.4.swipe.*`; `free4Tap` → `trackpad.free.4.tap` |
| Defaults *(as stated in Settings → Trackpad — the slot `detail` strings for 3F up/down only say "Free space")* | 3F: left → forward · right → back · up → maximize · down → minimize<br>4F: left / right → previous / next tab · up → Mission Control · down → App Exposé<br>4F tap → Spotlight |
| Recognition | `Gestures/Recognizers/SwipePinchRecognizer.swift` — finger count locked at gesture start; emits swipe outcomes for the `.free` zone at 3+ fingers |
| Routing | `Gestures/GestureEngine.swift` free-space path |
| Config | `TrackpadConfig.threeFingerSwipes`, `.fourFingerSwipes`, `.fourFingerTap` — **all `false`** by default, each `decodeIfPresent ?? false` |
| Legacy gates | `.trackpadFreeThreeSwipe`, `.trackpadFreeFourSwipe`, `.trackpadFreeFourTap` (see `SanneConfig.enableLegacyGate`) |
| Settings | Settings → Trackpad; shows the System-Settings-conflict hint when a conflicting chord is enabled |
| Cheat sheet | `UI/Help/GestureCatalog.swift` |

**Arbitration:** drag > swipe > tap. Once a 3-finger drag commits it wins the whole session — a stuck
mouse button is a worse failure than a missed swipe. Finger count is locked to the session peak, so a
4-finger chord that decays to 3 fingers fires the 4F slot only, never both.

**Off by default on purpose.** macOS consumes 3F/4F swipes for Mission Control / Spaces, and
registering for multitouch does **not** suppress the system gesture. Users must turn the matching
System Settings gestures off first; Settings says so inline.

**Owed:** the plan asked this step to create the `SanneTests` target with free-zone finger-count and
config-decode-tolerance tests. It did not. → [Step 8](#step-8--sannetests-target).
**Owed:** hardware QA → [PROGRESS.md](./PROGRESS.md) items 14–15.

---

### Step 2 — Tip-tap

**Delivered.** Rest one finger on the trackpad and tap beside it; tap-left and tap-right are two
separate remappable gestures.

| What | Where |
|------|-------|
| Recognizer | **new** `Gestures/Recognizers/TipTapRecognizer.swift` — stationary anchor (held, low movement) + quick second-finger tap; side from x-offset vs. the anchor; scaled by `trackpad.sensitivity` |
| Slot ids | `GestureSlots.ID.tipTapLeft` / `.tipTapRight` → `trackpad.free.2.tipTap.left` / `.right` |
| Config | `TrackpadConfig.tipTap` — **`false`** by default (`decodeIfPresent ?? false`) |
| Legacy gate | `.trackpadTipTap` |
| Settings | Settings → Trackpad → *Tip-tap* section, with an inline note that macOS has no tip-tap gesture so no System Settings changes are needed |
| Diagram | `UI/Theme/GestureDiagram.swift` gained a `.tipTap` motion — drawn as a held anchor dot plus a tapping dot, since tip-tap reads as two distinct finger roles rather than a chord |

**Why it can't collide with scrolling:** the anchor finger must stay still. Drift past the threshold
cancels the gesture, so two-finger scrolling and dragging keep working untouched. It is also mutually
exclusive with 3F drag and the free-space swipes.

**Owed:** state-machine tests (anchor-drift cancel, tap timeout, side detection) →
[Step 8](#step-8--sannetests-target). Hardware QA → [PROGRESS.md](./PROGRESS.md) item 16.

---

### Step 3 — Magic Mouse 3-finger swipes

**Delivered.** L/R/U/D swipes across the Magic Mouse surface, extending the existing 2F swipe
tracking in `TouchInput/MagicMouseTapController.swift` to three fingers at the same displacement
thresholds.

| What | Where |
|------|-------|
| Slot ids | `GestureSlots.ID.mm3fSwipe{Left,Right,Up,Down}` → `mouse.surface.3.swipe.*` |
| Defaults | left → Previous tab · right → Next tab · up → Mission Control · down → App Exposé |
| Config | `MagicMouseConfig.threeFingerSwipes` — **`false`** by default (`decodeIfPresent ?? false`) |
| Legacy gate | `.mmThreeFingerSwipes` |
| Settings | Settings → Magic Mouse → *3-finger swipes* |
| Cheat sheet | `UI/Help/GestureCatalog.swift` — updated here for all of steps 1–3 |

**Sharing a chord with middle-click:** three fingers on the surface is *also* the 3F → middle-click
gesture. Travel decides. The middle-click only commits while total movement stays under the swipe
threshold; enough travel makes it a swipe instead. One contact can never produce both.

**Off by default on purpose:** three fingers is easy to land just by gripping the mouse.

**Owed:** hardware QA → [PROGRESS.md](./PROGRESS.md) item 17.

---

### Step 4 — Custom script actions

**Delivered.** Any gesture can run a shell command, an AppleScript, or a macOS Shortcuts shortcut.
Scripts are named, reusable across gestures, and travel with import / export.

| What | Where |
|------|-------|
| Model | **new** `Config/CustomAction.swift` — `CustomActionDef { id: UUID, name, kind, payload }`, `Kind = shell / appleScript / shortcut` |
| Store | `SanneConfig.customActions: [CustomActionDef]` (`decodeIfPresent ?? []`) |
| Action id | `action.custom.<uuid>` via `ActionCatalog.customActionId(_:)` / `parseCustomAction(_:)` |
| Registry | `ActionCatalog.syncCustomActions(_:)`, called by `ConfigStore` on every config change; `customAction(id:)` resolves a def, `action(for:)` builds its catalog row |
| Execution | `Actions/ActionRunner.swift` — off the main thread; `/bin/zsh -lc`, AppleScript, `shortcuts run` |
| Limits | `CustomActionLimits.timeoutSeconds` (10 s) and `.concurrentScripts` (4). Settings copy interpolates these constants rather than restating them, so the UI can't drift from the runner |
| Editor | **new** `UI/Preferences/CustomActionSheet.swift`, reached from the *Scripts* category in `GestureEditorView`'s `ActionPickerSheet` |
| Category | `ActionCatalog.Category.script` = `"Scripts"` |

**Why UUID references, not scripts encoded in the action id:** scripts are multi-line, editable and
reusable. Renaming an action keeps every gesture pointed at it.

**Failure behaviour, by design:** a script that overruns 10 s is terminated (SIGTERM, then killed
after a 1 s grace); triggering a gesture while 4 scripts already run **skips** the extra rather than
queueing it unbounded; non-zero exits and stderr are reported in the Debug Log. A gesture never
blocks, stalls or crashes on a bad script. A deleted def resolves to `none` and the editor shows
*Missing action*.

**One subtlety worth not re-breaking:** `ActionPickerSheet` renders its Scripts rows from the
observed `ConfigStore`, not from the catalog's lock-protected mirror, which SwiftUI cannot observe —
otherwise the list goes stale right after a save or delete. `.script` is filtered out of
`builtInSections` so the two sources cannot produce duplicate rows.

**Owed:** round-trip and unknown-UUID / missing-`shortcuts`-binary tests →
[Step 8](#step-8--sannetests-target). Hardware QA → [PROGRESS.md](./PROGRESS.md) item 18.

---

### Step 5 — Per-app gesture bindings

**Delivered.** The same gesture can run a different action depending on which app is frontmost.

| What | Where |
|------|-------|
| Store | `SanneConfig.appGestureOverrides: [String: [String: GestureOverrideEntry]]` (`decodeIfPresent ?? [:]`) |
| Scope type | `Config/GestureBinding.swift` — `GestureBindingScope { .global, .app(bundleId:) }`; its `bundleId` feeds the resolver directly |
| Layering | `GestureOverrideEntry.layered(over:)` — **field-wise**, so an app that only remaps the action still inherits the global enable state |
| Resolver | `BindingResolver.resolve(slotId:config:frontmostBundleId:)` in `Gestures/GestureSlots.swift` |
| Call sites | `GestureEngine.frontmostBundleIdAtGestureStart`, captured once per gesture |
| UI | **new** `UI/Preferences/AppGestureOverridesButton.swift` and `UI/Preferences/OrphanAppGestureRemapsSection.swift`; the app-scoped editor reuses `GestureEditorView` |

**Precedence (highest first):** app override → global override → Sanne Standard default. A group's
master switch outranks all three, so a per-app row can never revive a subsystem the user turned off
wholesale. `frontmostBundleId` defaults to `nil`, which skips the app layer entirely — that is
exactly what the Gestures tab, the cheat sheet and every pre-existing caller want, so backward
compatibility is the default rather than an afterthought.

**Invariants that the rest of the feature leans on:**

- `setGestureOverride` prunes empty entries *and* empty per-app maps. A slot present in a map always
  means "this scope customises it", which is what makes the Modified badge, the per-row Reset and the
  exported JSON honest with no extra bookkeeping.
- `enableLegacyGate` is **always global**, even from an app-scoped editor: the section toggles gate
  *recognition*, which happens before Sanne knows which app will receive the action.
- `appsWithGestureOverrides` sorts by display name, falling back to the bundle id for an app that is
  no longer installed — so uninstalled entries still sort predictably instead of dropping out.

**Nothing configured can go invisible:** removing an app's *pause* row no longer discards its
bindings. They stay listed under `Section("Gesture bindings only")` in Settings → Apps.

**Owed:** the resolver precedence matrix (app/global/default × enabled/disabled) and nil-bundle-id
backward-compatibility tests → [Step 8](#step-8--sannetests-target). Hardware QA →
[PROGRESS.md](./PROGRESS.md) item 19.

---

### Step 6 — Action HUD overlay + docs

**Delivered.** A brief label naming the action a gesture just fired, so remapped and off-screen
effects stop being guesswork.

| What | Where |
|------|-------|
| Panel | **new** `UI/HUDController.swift` — non-activating borderless `NSPanel`, following the `Windowing/SnapPreviewWindow.swift` pattern; public surface is just `show(title:)` / `hide()` |
| Allow-list | `ActionCatalog.announcesInHUD(_:)` — the single authority, living next to `title(for:)` |
| Config | `HUDConfig` + `SanneConfig.hud` (`decodeIfPresent ?? .init()`) |
| Invocation | a single `perform()` funnel in `GestureEngine`, so "exactly one announce per committed action" is structural rather than something several call sites must remember |
| Settings | Settings → Home → *Action name overlay* |

**Deliberately silent for:** plain clicks (`clickLeft/Right/Middle` — the cursor already shows the
result, and taps are frequent enough that labelling them would pin the HUD on screen), continuous
gestures (`drag`, `moveWindow` — no single moment to announce, and the thing being dragged is its own
feedback), and `none`. Everything else announces, including remapped keystrokes, launched apps and
custom scripts — precisely the actions whose effect can be invisible.

**Panel hardening worth preserving:** never becomes key or steals focus; clamped to the `visibleFrame`
of the display **under the cursor**; a generation counter makes it impossible for a late fade
completion to order out a panel a newer `show` just displayed; a re-show mid-fade snaps back to full
opacity rather than continuing to fade; the fade completion uses `MainActor.assumeIsolated` because
AppKit always calls it on the main thread, which keeps the generation guard synchronous with the
completion instead of racing an async hop.

**Scope note (intentional gap):** keyboard snap (`Keyboard/KeyboardSnapMonitor.swift`) and
modifier-drag (`Windowing/ModifierDragController.swift`) run actions **without** announcing — the HUD
is wired into the gesture engine only. Because the policy lives in `ActionCatalog.announcesInHUD`,
extending them later is one line per call site.

**Docs updated:** [PROGRESS.md](./PROGRESS.md) (feature rows in sections B/D/E + QA items 14–21),
[README.md](./README.md) (features list + a *Why some gestures ship off* section explaining the three
opt-in groups once, and where to enable them), [CHANGELOG.md](./CHANGELOG.md) (six `Added` entries
under `[Unreleased]`).

**Owed:** hardware QA → [PROGRESS.md](./PROGRESS.md) item 20; config round-trip →
[Step 10](#step-10--config-round-trip-verification).

---

## Cross-cutting state

**Files created by this plan** (6; the plan predicted 4 — the two Settings components in step 5 were
split out rather than piled into `PreferencesView.swift`):

```
Sources/Sanne/Gestures/Recognizers/TipTapRecognizer.swift
Sources/Sanne/Config/CustomAction.swift
Sources/Sanne/UI/HUDController.swift
Sources/Sanne/UI/Preferences/CustomActionSheet.swift
Sources/Sanne/UI/Preferences/AppGestureOverridesButton.swift        (not in plan)
Sources/Sanne/UI/Preferences/OrphanAppGestureRemapsSection.swift    (not in plan)
```

**Files modified:** `SwipePinchRecognizer.swift`, `GestureEngine.swift`, `GestureSlots.swift`,
`MagicMouseTapController.swift`, `ActionCatalog.swift`, `ActionRunner.swift`, `ConfigModels.swift`,
`ConfigStore.swift`, `GestureBinding.swift`, `GestureEditorView.swift`, `PreferencesView.swift`,
`UI/Help/GestureCatalog.swift`, `UI/Theme/GestureDiagram.swift`, plus `PROGRESS.md` / `README.md` /
`CHANGELOG.md`.

**Build facts**, so the "no tests" gap below is independently checkable rather than asserted: 51 Swift
sources under `Sources/Sanne/`; `Package.swift` declares swift-tools 5.9, `.macOS(.v13)` and **one**
target — the `Sanne` executable with `.process("Resources")` — and **no test target**; `VERSION` is
`0.1.0`.

**Every new *gesture* ships off, and every new store ships empty.** All new keys decode via
`decodeIfPresent` with a default, so an older config is never rejected:

| Key | Default | |
|-----|---------|---|
| `trackpad.threeFingerSwipes` · `.fourFingerSwipes` · `.fourFingerTap` · `.tipTap` | `false` | opt-in |
| `magicMouseTaps.threeFingerSwipes` | `false` | opt-in |
| `customActions` | `[]` | inert until populated |
| `appGestureOverrides` | `[:]` | inert until populated |
| `hud` | `HUDConfig()` | **on** — the one exception, and safe to be: the HUD is feedback, not a new input path, so it cannot fire a gesture the user didn't ask for |

Pre-existing trackpad behaviour is untouched: `trackpad.threeFingerTapMiddleClick` and
`.threeFingerDrag` remain **`true`**. A pre-change `config.json` therefore loads with identical
behaviour — which is asserted nowhere yet, hence [Step 10](#step-10--config-round-trip-verification).

### What is actually proven

| Claim | Evidence |
|-------|----------|
| Everything compiles, no new warnings | ✅ `swift build` clean. A Swift 6 concurrency warning pair in the HUD fade completion handler was caught here and fixed |
| Config keys default correctly | ✅ read off the stored properties in `ConfigModels.swift` |
| Recognizers behave on real fingers | 🔴 **nothing** — no hardware run, no tests |
| Resolver precedence is correct | 🔴 reasoned only. No test asserts it, and the whole-plan review is still outstanding ([Step 7](#step-7--code-review-of-steps-16)) |
| Scripts time out / cap concurrency as documented | 🔴 constants read correctly; behaviour unexercised |
| HUD never steals focus | 🔴 designed for it; unverified on screen |

Read that table before trusting anything above it.

---

## Future steps

### Step 7 — Code review of steps 1–6

The six steps landed across many sessions and were never reviewed as a whole. Independent of
[Step 9](#step-9--hardware-qa-sweep), so the two can overlap.

Focus areas:

- **Free-space arbitration** — drag / swipe / tap ordering and the session-peak finger-count lock;
  hunt for a path that leaks a synthetic mouse-up or double-fires two slots.
- **`MagicMouseTapController`** — the 3F swipe vs. 3F middle-click split, which is the riskiest edit
  in the plan because it touches a verified-working path (tap-to-click).
- **`ActionRunner`** script lifecycle — timeout, kill grace, slot accounting under rapid re-entry, and
  whether a slot can leak on an early-return path.
- **`BindingResolver`** layering and the `setGestureOverride` pruning invariant.
- **`HUDController`** concurrency and panel lifetime.

### Step 8 — `SanneTests` target

The plan asked steps 1, 2, 4 and 5 to add tests. None exist: `Package.swift` still declares only the
executable target. This is the last outstanding *code* deliverable of the plan.

Add a `SanneTests` target and cover the pure logic only — no hardware, no UI:

- `BindingResolver` precedence matrix: app / global / default × enabled / disabled; `nil` bundle id
  reproduces pre-per-app behaviour; a disabled master group beats all three layers.
- Config decode tolerance and round-trip: a config carrying `customActions`, `appGestureOverrides`,
  `hud` and new slot overrides encodes → decodes equal; a pre-change JSON leaves every new field at
  its default.
- `setGestureOverride` pruning: writing an empty entry removes the slot, and emptying an app removes
  its whole map.
- `TipTapRecognizer` state machine fed synthetic `TouchFrame`s: side detection, anchor-drift cancel,
  tap timeout.
- `SwipePinchRecognizer` free-zone finger-count outcomes, including the 4→3 finger decay case.
- `ActionCatalog`: `customActionId` / `parseCustomAction` round-trip, unknown UUID → `nil`,
  `announcesInHUD` allow-list.

Note the production target is an executable; expect to confirm how the test target imports it before
writing assertions.

### Step 9 — Hardware QA sweep

Needs a Magic Mouse and a trackpad, ideally with a second display. The checklist already exists with
explicit pass criteria — work [PROGRESS.md](./PROGRESS.md) **items 14–21** top to bottom:

| Item | Covers |
|------|--------|
| 14 | free-space 3F swipes (+ drag arbitration) |
| 15 | free-space 4F swipes and 4F tap (finger-count decay) |
| 16 | tip-tap (no phantoms while scrolling) |
| 17 | Magic Mouse 3F swipes vs. middle-click |
| 18 | script actions: failure, 10 s timeout, concurrency cap, missing `shortcuts` binary |
| 19 | per-app bindings, orphaned bindings, uninstalled app, missing action |
| 20 | HUD: placement, mid-fade re-show, **focus theft**, toggle off |
| 21 | config export / import round-trip |

Run from `dist/Sanne.app` (`./scripts/package-app.sh`), not the raw binary — Accessibility identity
and launch-at-login both depend on the bundle.

### Step 10 — Config round-trip verification

[PROGRESS.md](./PROGRESS.md) item 21, called out as its own step because it protects **existing
users** rather than new features: four new top-level keys landed in `SanneConfig`. Cheapest as an
assertion in [Step 8](#step-8--sannetests-target), but worth doing through the UI too, since export →
import is the path users actually take.

### Step 11 — Release prep

Once 7–10 are clean:

1. Move the six `[Unreleased]` → `Added` entries in [CHANGELOG.md](./CHANGELOG.md) under a version
   heading; bump [VERSION](./VERSION) (currently `0.1.0`).
2. `./scripts/package-dmg.sh` → versioned DMG + sha256; `./scripts/notarize.sh` needs Developer ID
   credentials.
3. Flip the relevant 🟡 rows in [PROGRESS.md](./PROGRESS.md) to ✅ as hardware QA confirms them.
4. Carried forward from [PROGRESS.md](./PROGRESS.md) — outside this plan, but on the same release
   path: app icon set, public GitHub Release once the repo is public, optional Sparkle auto-update,
   Homebrew cask.

### Later / optional

Neither is a gap — both are deliberate, and each is cheap if wanted:

- **Announce from keyboard snap and modifier-drag** — one line per call site in
  `Keyboard/KeyboardSnapMonitor.swift` and `Windowing/ModifierDragController.swift`, since
  `ActionCatalog.announcesInHUD` already owns the policy (see
  [Step 6](#step-6--action-hud-overlay--docs)).
- **HUD placement preference** — the position is currently fixed near the bottom of the active
  display, which no one has asked to change yet.

### Explicitly out of scope for this plan

Recorded so they don't get mistaken for gaps — the plan ruled each of these out up front: drag-to-edge
snap areas, named presets / profiles, clipboard manager, key sequences, Touch Bar, and any condition
engine beyond frontmost-app matching. Longer-term product direction lives in
[PROGRESS.md](./PROGRESS.md) Phase 3–4, not here.

---

## How to update this file

1. Move a step from **Completed steps** or **Future steps** as its state changes, and update the
   at-a-glance table — remembering that `Code`, `Tests` and `Hardware QA` are independent columns.
2. Never promote a row to ✅ on reasoning alone. Put the evidence in **What is actually proven**.
3. Re-run `swift build` and confirm zero warnings before recording any step as code complete.
4. Update **Where we are** and **Next step** at the top — that pair is the whole point of the file.
5. Mirror anything user-visible into [PROGRESS.md](./PROGRESS.md), [README.md](./README.md) and
   [CHANGELOG.md](./CHANGELOG.md).
