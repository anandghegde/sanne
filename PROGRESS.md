# Sanne — Progress & Plan

**Last updated:** 2026-08-10  
**Current phase:** Phase 1 (MVP) + Phase 2 product polish  
**Overall:** ~94% MVP · Phase 2: packaging (DMG scripts + release docs); notarization optional · BTT/Multitouch parity features (free-space + tip-tap + MM 3F swipes, script actions, per-app bindings, action HUD) are **code complete, hardware QA pending**

Living document. Update statuses here as work lands. Scope detail lives in [MVP_SCOPE.md](./MVP_SCOPE.md) and [PRD.md](./PRD.md); step-by-step execution of the BTT/Multitouch parity plan — what each step delivered, what is proven vs merely compiling, and what to pick up next — is tracked in [PLAN_PROGRESS.md](./PLAN_PROGRESS.md).

---

## Status legend

| Mark | Meaning |
|------|---------|
| ✅ | Done / verified |
| 🟡 | Implemented, needs polish or more testing |
| 🔴 | Not started / blocked |
| ⬜ | Planned, not started |

---

## Phase map

```
Phase 0   Feasibility / foundations     ✅ DONE (in product app)
Phase 1   MVP                           🟡 IN PROGRESS
Phase 2   v1.0 public                   ⬜ NEXT
Phase 3   v1.x power features           ⬜ LATER
Phase 4   v2                            ⬜ PARKED
```

---

## Phase 0 — Feasibility (done)

Goal: prove hard APIs; no separate throwaway spike (lives in **Sanne** itself).

| # | Milestone | Status | Notes |
|---|-----------|--------|--------|
| 0.1 | MultitouchSupport load + device list | ✅ | dlopen, create list, retain CFArray |
| 0.2 | Magic Mouse touch stream + taps | ✅ | **User verified tap-to-click works** (2026-07-31) |
| 0.3 | Synthetic left/right/middle click | ✅ | Used by tap path |
| 0.4 | AX window snap (left half, etc.) | 🟡 | Snap + restore-on-repeat; needs more manual QA |
| 0.5 | Titlebar hit-test / zones | 🟡 | Window captured at gesture start; needs Finder/Chrome QA |
| 0.6 | Sleep/wake rebind | 🟡 | Trackpad **and** Magic Mouse rebind; not stress-tested (10×) |
| 0.7 | Debug logging (file + UI) | ✅ | `~/Library/Logs/Sanne/sanne.log`, Settings → Debug Log |

**Key fix (tap-to-click):** Correct Multitouch callback ABI (`int` first arg), retain device list, exclusive device ownership (trackpad path must not re-register Magic Mouse — overwrote callback).

---

## Phase 1 — MVP checklist

### A. Shell

| Item | Status | Notes |
|------|--------|--------|
| Menu bar agent | ✅ | |
| Pause / Resume | ✅ | Menu + settings |
| Accessibility onboarding | ✅ | |
| About + version string | ✅ | `VERSION` / About show **0.2.0** |
| Launch at login | 🟡 | `SMAppService` + Settings toggle; needs **Sanne.app** (not raw binary) |
| Notarized builds for testers | ✅ | **0.2.0** Developer ID + notarized/stapled DMG (`dist/Sanne-0.2.0.dmg`) |

### B. Magic Mouse taps

| Item | Status | Notes |
|------|--------|--------|
| Left-zone tap → click | ✅ | **Verified** |
| Right-zone tap → right-click | 🟡 | Implemented; confirm on hardware |
| Multi-finger → middle-click | 🟡 | Implemented; confirm |
| Double-tap-hold → drag | 🟡 | Implemented; needs hardware QA |
| Double / triple multi-click | 🟡 | clickState 2/3 for rename / word select |
| 2-finger middle-click | 🟡 | Popular Multitouch/BTT default |
| 2F double-tap → Mission Control | 🟡 | |
| 2F swipe up/down → MC / App Exposé | 🟡 | Spaces L/R optional (off by default) |
| 3F swipe L/R/U/D | 🟡 | Off by default; travel decides — the same chord held still is still a middle-click |
| Palm rejection | 🟡 | Cancel on surface/cursor move |
| Sensitivity + L/R split settings | ✅ | Settings UI |
| Enable/disable taps | ✅ | |

### C. Titlebar window gestures

| Item | Status | Notes |
|------|--------|--------|
| Swipe L/R → halves | 🟡 | Window@start + preview; needs hardware QA |
| Long swipe L/R → thirds | 🟡 | leftThird / rightThird when magnitude ≥ 0.22 |
| Long swipe up → centerLarge | 🟡 | |
| Swipe up → maximize | 🟡 | |
| Swipe down → minimize | 🟡 | |
| Diagonal → quarters | 🟡 | |
| Pinch in → close | 🟡 | |
| Pinch out → fullscreen | 🟡 | |
| Live snap preview | 🟡 | Screen from window, not live cursor |
| Haptics on commit | 🟡 | |
| Restore previous frame | 🟡 | Second same layout restores pre-snap frame |
| 3-finger L/R → adjacent display | 🟡 | Titlebar; needs multi-monitor QA |

### D. Trackpad free-space

| Item | Status | Notes |
|------|--------|--------|
| 3-finger tap → middle-click | 🟡 | Implemented; needs QA |
| 3-finger drag | 🟡 | Left-button drag (text select, file move); wins the session once it commits |
| 3-finger swipe L/R/U/D | 🟡 | Off by default — macOS claims these; turn the System Settings equivalents off first |
| 4-finger swipe L/R/U/D | 🟡 | Off by default (same macOS conflict) |
| 4-finger tap | 🟡 | Off by default |
| Tip-tap left / right | 🟡 | Off by default — rest one finger, tap beside it; anchor must stay still, so scrolling can't trigger it |
| Free-space arbitration | 🟡 | drag > swipe > tap, finger count locked to the session peak so a 4F chord can't also fire the 3F slot |

### E. Defaults & settings

| Item | Status | Notes |
|------|--------|--------|
| Sanne Standard preset | ✅ | Bundled JSON + code defaults |
| Per-feature toggles | ✅ | MM / Windows / Trackpad sections |
| Reset to Standard | ✅ | |
| Debug Log tab | ✅ | |
| Full gesture remap editor | 🟡 | Settings → Gestures; catalog + record keystroke + open app; per-row reset + Modified filter |
| Custom script actions | 🟡 | Settings → Gestures → Action → **Scripts**: shell / AppleScript / Shortcuts; named + reusable; 10 s timeout, max 4 at once, errors to Debug Log |
| Per-app gesture bindings | 🟡 | Settings → Apps → app row → **Gesture bindings**; app override → global override → Standard default; section toggles stay global (they gate recognition) |
| Action name HUD overlay | 🟡 | Settings → Home → **Action name overlay**; ~0.8 s label on the display under the cursor. Skips clicks + continuous drags. Scope note: keyboard snap and modifier-drag don't announce yet — one line per call site now that `ActionCatalog.announcesInHUD` owns the policy |

### F. Reliability

| Item | Status | Notes |
|------|--------|--------|
| Multi-monitor snap geometry | 🟡 | Uses visibleFrame; needs multi-display QA |
| Competing app warning | ✅ | Heuristic list |
| Wake rebind | 🟡 | Both trackpad + Magic Mouse; needs 10× sleep stress |
| Proper `.app` bundle | 🟡 | `package-app.sh` → `dist/Sanne.app`; `package-dmg.sh` → versioned DMG + sha256 |

---

## Phase 2 — v1.0 (planned)

| Item | Status | Notes |
|------|--------|-------|
| Dock zone gestures | 🟡 | Swipe up activate / down hide; pinch out ⌘N; pinch quit off by default |
| Menubar zone gestures | 🟡 | L/R cycle windows; down hide others; up unminimize |
| Thirds / long-swipe layouts | 🟡 | Geometry + long titlebar swipe + keyboard cycle |
| Move window to adjacent display | 🟡 | 3F titlebar + ⌃⌥⌘←/→; relative frame map |
| Keyboard snap (⌃⌥+arrows) | 🟡 | KeyboardSnapMonitor; Settings → Keyboard |
| Modifier + drag move/resize | 🟡 | ⌥⌘ move · ⌃⌘ resize; Settings → Windows |
| Magic Mouse 2F top-edge move | 🟡 | Fingers on top of surface + move mouse → drag window under cursor |
| Per-app rules | 🟡 | Pause scope: all / Magic Mouse / window gestures / keyboard+drag — plus per-app gesture bindings (see E) |
| Import / export config | 🟡 | JSON via Settings → Home (includes `gestureOverrides`, `appGestureOverrides`, `customActions`, `hud`) |
| Full gesture remap editor | 🟡 | Settings → Gestures; catalog + freeform keystroke + launch app + scripts |
| Tutorial + cheat sheet | 🟡 | Menu + Settings; live signals for MM tap / titlebar snap / middle-click |
| GitHub Releases + optional Sparkle | 🟡 | Notes skeleton `docs/releases/0.1.0.md`; publish when repo is public |
| Homebrew cask | ⬜ | Sketch in docs/RELEASING.md |
| Notarized DMG | 🟡 | Scripts ready; run with SANNE_SIGN_IDENTITY + notary profile |

---

## Phase 3 — v1.x (planned)

| Item | Status |
|------|--------|
| Tap-drag polish / gaming mode | ⬜ |
| Spaces window move | ⬜ |
| HUD labels (landed early — see E) | 🟡 |
| Hyper key + simple remaps | ⬜ |
| Shell / Shortcuts / AppleScript actions (landed early — see E) | 🟡 |
| Preset gallery | ⬜ |

---

## Suggested next steps (ordered)

1. **QA custom keystroke remap** — Settings → Gestures → Action → Record keystroke; fire gesture  
2. **QA launch-app remap** — Action → Open app…; gesture opens chosen `.app`  
3. **QA Magic Mouse top-edge move** — 2 fingers near top of surface, move mouse over a window  
4. **QA titlebar gestures** on trackpad (halves, maximize, minimize, preview, restore-on-repeat)  
5. **QA long-swipe thirds** + **3-finger display throw** (multi-monitor)  
6. **QA keyboard snap** — ⌃⌥←/→/↑/↓/↩ and ⌃⌥⌘←/→  
7. **QA modifier-drag** — ⌥⌘ move, ⌃⌘ resize from window body  
8. **QA per-app scopes** (All / Magic Mouse only / Window gestures / Keyboard & drag) + import/export  
9. **QA Dock / Menubar gestures**  
10. **Confirm right-click + middle-click** on Magic Mouse; **QA tap-drag**  
11. **Launch at login** from `dist/Sanne.app`  
12. **Sleep/wake stress test**  
13. **QA tutorial + cheat sheet** + full gesture remap  
14. **QA free-space 3-finger swipes** — first turn the macOS equivalents off (System Settings → Trackpad → More Gestures), then Settings → Trackpad → enable 3-finger swipes and bind L/R. *Pass:* each swipe fires exactly once; with 3-finger drag also on, a drag that commits wins the whole session (no swipe fires, no stuck mouse button)  
15. **QA free-space 4-finger swipes + 4-finger tap** — enable both in Settings → Trackpad. *Pass:* a 4-finger chord that drops to 3 fingers mid-swipe fires **only** the 4F slot, never both; a 4-finger tap that travels is treated as a swipe, not a tap  
16. **QA tip-tap** — Settings → Trackpad → enable tip-tap; rest one finger, tap to its left, then its right. *Pass:* correct side every time; two-finger scrolling and dragging produce **no** phantom tip-taps (anchor drift cancels the gesture)  
17. **QA Magic Mouse 3-finger swipes** — Settings → Magic Mouse → enable 3-finger swipes. *Pass:* three fingers held still still middle-clicks; the same chord with travel swipes instead; never both from one contact  
18. **QA custom script actions** — Settings → Gestures → Action → **Scripts** → add a shell, an AppleScript and a Shortcuts action. *Pass:* each runs from its gesture; a failing script logs exit code + stderr to Debug Log; a shell action of `sleep 30` is terminated at 10 s and logged as timed out; firing a slow script repeatedly logs "already running — skipped" rather than spawning without limit; a Shortcuts action on a Mac without `/usr/bin/shortcuts` logs a launch failure instead of failing silently  
19. **QA per-app gesture bindings** — Settings → Apps → app row → **Gesture bindings**; bind one gesture to different actions in two apps. *Pass:* the frontmost app's action fires and the other app is unaffected; deleting an app's pause row keeps its bindings, which then show under **"Gesture bindings only"**; a binding for an uninstalled app still lists (name falls back to the bundle id) with no crash; deleting a custom action a binding uses shows **"Missing action"** and the gesture does nothing  
20. **QA action HUD** — Settings → Home → **Action name overlay**. *Pass:* appears for remapped gestures but never for plain clicks, 3-finger drag or continuous window move; lands near the bottom of the display **under the cursor** (verify on a secondary display); two gestures ~0.6 s apart snap it back to full opacity instead of continuing to fade; it **never steals focus** — type into a text field while firing HUD gestures and confirm no keystrokes are lost; toggling it off silences it entirely  
21. **QA config round-trip** — Settings → Home → export, then import into a fresh config. *Pass:* `customActions`, `appGestureOverrides`, `hud` and the new slot overrides all survive; a pre-change `config.json` still loads with every new field at its default  
22. Next: **hardware QA items 14–21** (skipped for the 0.2.0 cut — still recommended before wide distribution). Pure-logic tests green (`SanneTests`, 35). Outside this plan: app icon set; public GitHub Release `v0.2.0` when ready; optional Sparkle; Homebrew cask

Items 14–21 above are the hardware QA sweep for the BTT/Multitouch parity work; [PLAN_PROGRESS.md](./PLAN_PROGRESS.md) tracks that plan — **0.2.0 release prep done**; hardware QA optional.

---

## Changelog (high level)

| Date | What |
|------|------|
| 2026-07-31 | PRD, technical design, MVP scope, UX wireframes; MIT FOSS decision |
| 2026-07-31 | Product app scaffold: menu bar, config, settings, multitouch, windowing |
| 2026-07-31 | Debug logging (stdout + file + Debug Log UI) |
| 2026-07-31 | Magic Mouse tap-to-click fixed and **verified working** (callback ABI + exclusive device registration) |
| 2026-07-31 | This progress document created |
| 2026-07-31 | Tap-drag (double-tap-hold) in MagicMouseTapController; launch-at-login (`SMAppService`); `scripts/package-app.sh` → `dist/Sanne.app` |
| 2026-07-31 | Titlebar robustness: window@gesture-start, restore-on-repeat layout, resilient setFrame; wake rebinds Magic Mouse + trackpad; default MM sensitivity −1 |
| 2026-07-31 | Magic Mouse detection: keep external+!ForceTouch fallback (opaque-only broke MM; device reports opaque=false) |
| 2026-07-31 | Debug menu: Log Zone Under Cursor, multitouch stats, Test Snap left/right/maximize/restore — for titlebar QA |
| 2026-07-31 | Phase 2 start: Dock + menubar zone gestures, Settings tabs, KeyEmitter, ZoneActions; config decode tolerant of new keys |
| 2026-07-31 | Magic Mouse: multi-click (double/triple), 2-finger middle, 2F double-tap MC, 2F swipe MC/Exposé; Settings toggles |
| 2026-07-31 | Phase 2 window: thirds/two-thirds/centerLarge geometry; long titlebar swipe; 3F adjacent display; keyboard snap (⌃⌥); Settings Keyboard tab |
| 2026-07-31 | Modifier-drag (⌥⌘ move / ⌃⌘ resize); per-app disable list; config import/export JSON; Settings Apps + General backup |
| 2026-07-31 | Tutorial (live gesture signals) + searchable Gesture Cheat Sheet; menu bar + Settings General/About; onboarding → Start Tutorial |
| 2026-07-31 | Full gesture remap editor: ActionCatalog + BindingResolver + ActionRunner; Settings → Gestures; engines run remapped actions |
| 2026-07-31 | UI polish (Multitouch-style chrome, icon sidebar, gesture rows) |
| 2026-08-01 | Magic Mouse 2F top-edge drag → move window; common keystroke catalog; per-app scope (all / MM / window / keyboard+drag); About MIT |
| 2026-08-01 | Freeform keystroke recorder + launch-app action in gesture remap (`keystroke.custom.*`, `app.launch.*`) |
| 2026-08-01 | Packaging: VERSION, package-dmg.sh, notarize.sh, entitlements, CHANGELOG, docs/RELEASING.md, release notes 0.1.0 |
| 2026-08-08 | Illustrated gesture diagrams across Settings, Gestures editor and Cheat Sheet; System Settings-style tinted sidebar |
| 2026-08-09 | Free-space trackpad gestures: 3F/4F swipes L/R/U/D + 4F tap (`free3Swipe*`, `free4Swipe*`, `free4Tap`), off by default; arbitration drag > swipe > tap with the finger count locked to the session peak |
| 2026-08-09 | Tip-tap: `TipTapRecognizer` + `tipTapLeft` / `tipTapRight` slots, off by default; stationary anchor keeps it clear of scrolling and the 3+ finger chords |
| 2026-08-09 | Magic Mouse 3-finger swipes (`mm3fSwipe*`), off by default; travel decides between the swipe and the still-held middle-click |
| 2026-08-09 | Custom script actions: `CustomActionDef` + `action.custom.<uuid>`, Scripts rows in the action picker, `CustomActionSheet` editor; shell / AppleScript / Shortcuts run off-main with a 10 s timeout, 4-script ceiling and stderr to Debug Log |
| 2026-08-09 | Per-app gesture bindings: `appGestureOverrides`, resolver precedence app → global → Standard, app-scoped Gestures editor from Settings → Apps, orphaned bindings surfaced so nothing configured goes invisible |
| 2026-08-09 | Action HUD overlay: `HUDController` non-activating panel, `ActionCatalog.announcesInHUD` allow-list (skips clicks + continuous drags), toggle at Settings → Home |
| 2026-08-10 | `PLAN_PROGRESS.md`: step-by-step tracker for the BTT/Multitouch parity plan — per-step delivery detail, what is proven vs merely compiling, and the remaining steps (code review, `SanneTests` target, hardware QA, config round-trip, release prep) |
| 2026-08-10 | Steps 7–8 + automated step 10: code review of free-space / MM 3F / scripts / resolver / HUD; fix `removeCustomAction` to clear per-app remaps; package split (`SanneKit` library + thin `Sanne` executable); `SanneTests` with 35 pure-logic tests green |
| 2026-08-10 | **0.2.0 release prep** (hardware QA skipped): VERSION + CHANGELOG + `docs/releases/0.2.0.md`; Developer ID DMG + notarize |

---

## How to update this file

When finishing work:

1. Flip 🔴/⬜ → 🟡/✅ in the tables above  
2. Add a row to **Changelog**  
3. Adjust **Current phase** / **Overall** at the top  
4. Optionally sync checkboxes in [MVP_SCOPE.md](./MVP_SCOPE.md)
