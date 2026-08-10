# Sanne — MVP & Release Scope

**Version:** 1.0  
**Status:** Active (track day-to-day completion in [PROGRESS.md](./PROGRESS.md))  
**Companion to:** [PROGRESS.md](./PROGRESS.md) · [PRD.md](./PRD.md) · [TECHNICAL_DESIGN.md](./TECHNICAL_DESIGN.md) · [UX_WIREFRAMES.md](./UX_WIREFRAMES.md)  
**Last updated:** 2026-07-31  

---

## 1. Purpose

Cut the PRD into shippable slices. Prevent BTT-scale creep. Define what “done” means for each phase.

---

## 2. Product north star (unchanged)

> Install Sanne. Gestures just work. When you want more, every default is editable.

MVP must prove that sentence for **two moments of delight**:

1. **Magic Mouse:** silent tap-to-click  
2. **Trackpad:** titlebar swipe to snap  

If those two are not excellent, nothing else matters.

---

## 3. Scope principles

1. **Depth over breadth** — polish fewer gestures rather than ship every Multitouch trigger.  
2. **Defaults before editor** — Sanne Standard must feel finished before the full customizer.  
3. **Zones before free-space** — titlebar/Dock first; free-space multi-finger is mostly OS.  
4. **One device path solid** — Magic Mouse taps + built-in trackpad; Magic Trackpad treated as trackpad.  
5. **No scripting in MVP** — keystrokes and built-in actions only.  

---

## 4. Phase map

```
Phase 0     Spike / feasibility          ~1–2 weeks
Phase 1     MVP (private beta)           ~6–8 weeks
Phase 2     v1.0 (public)                ~4–6 weeks after MVP
Phase 3     v1.1–1.x                     ongoing
Phase 4     v2                           later
```

---

## 5. Phase 0 — Technical spike (go/no-go)

**Goal:** Prove the hard APIs before productizing UI.

| Spike | Success criteria |
|-------|------------------|
| MultitouchSupport load | Enumerate trackpad + Magic Mouse; stream finger positions |
| Synthetic click | Left/right/middle `CGEvent` works in Safari/Finder |
| AX window snap | Move Safari to left half on main display |
| Element at position | Detect “cursor is on titlebar” reliably in Finder + Chrome |
| Sleep/wake rebind | 10× sleep cycles without losing MT stream |

**Deliverable:** working product foundations (multitouch, AX snap, titlebar zones, Magic Mouse taps).  
**Implementation:** the **Sanne** app itself (`swift build` / `swift run` at repo root) — not a separate spike target.  
**Go:** multitouch streams, synthetic clicks, titlebar snap, and wake rebind work on target machines.

---

## 6. Phase 1 — MVP (private beta)

### 6.1 In scope (must ship)

#### A. Shell

- [x] Menu bar app (agent)  
- [x] Launch at login (`SMAppService`; requires packaged `.app`)  
- [x] Pause / Resume  
- [x] Accessibility onboarding  
- [x] About + version (informal)  
- [x] Local `.app` + DMG packaging (`scripts/package-*.sh`)  
- [ ] Notarized builds for testers (script ready; needs Developer ID)

#### B. Magic Mouse taps (TapToClick core)

- [x] Left-zone tap → left click (**verified**)  
- [x] Right-zone tap → right click (implemented; confirm)  
- [x] Multi-finger → middle click (implemented; confirm)  
- [x] Double-tap-hold → drag (implemented; needs hardware QA)  
- [x] Palm / move cancellation (basic)  
- [x] Sensitivity + left/right split settings  
- [x] Enable/disable whole tap system  

#### C. Zone window management (Swish core)

**Titlebar (2-finger trackpad + adapted Magic Mouse where possible):**

- [x] Swipe L/R → left/right half (code; needs QA)  
- [x] Swipe up → maximize (code; needs QA)  
- [x] Swipe down → minimize (code; needs QA)  
- [x] Diagonal → quarters (code; needs QA)  
- [x] Pinch in → close (code; needs QA)  
- [x] Live snap **preview** (code; needs QA)  
- [x] Haptic on trackpad when action commits (code; needs QA)  
- [x] Restore previous size path (basic; needs QA)  

**Not required in MVP:** continuous thirds cycling, deep pinch quit, menubar zones, Dock zones, Spaces move.

#### D. Minimal trackpad free-space

- [x] 3-finger tap → middle click only (code; needs QA)

#### E. Defaults & settings (minimal)

- [x] Sanne Standard embedded (non-editable structure OK if toggles work)  
- [x] Per-gesture **on/off** for all shipped gestures  
- [x] Magic Mouse section + Windows/Titlebar section  
- [x] Reset all to defaults  

#### F. Reliability

- [x] Wake rebind (wired; needs stress test)  
- [x] Multi-monitor: snap on correct screen’s visible frame (basic; needs QA)  
- [x] Warn if competing gesture app detected (simple list)  

### 6.2 Explicitly out of MVP

| Item | Deferred to |
|------|-------------|
| Full custom gesture→action editor | v1.0 |
| Per-app rules | v1.0 |
| Dock / menubar zones | v1.0 |
| Thirds / long-swipe layouts | v1.0 |
| Multi-display window throw | v1.0 |
| Spaces window move | v1.0 or experimental |
| Keyboard snap / Hyper | v1.0 |
| Modifier+drag move/resize | v1.0 |
| Gaming mode | v1.1 |
| Import/export | v1.0 |
| HUD text bezel | v1.1 |
| Scripting | v1.x |
| Preset gallery | v1.x |
| Drawing gestures | v2 |
| Floating menus / launcher | v2 |

### 6.3 MVP success criteria (beta)

| Metric | Target |
|--------|--------|
| Titlebar snap feels “instant” | Subjective pass from ≥8/10 beta users |
| Magic Mouse taps usable all day | ≥8/10 would replace TapToClick |
| Accidental clicks (MM) | “Rare” for ≥7/10 |
| Crash-free | No reproducible crash in 1 week of use |
| Sleep/wake | Gestures work after wake without relaunch |

### 6.4 MVP non-goals for polish

- Beautiful marketing site  
- Any licensing / trial / paid gates (app is free OSS from day one)  
- Sparkle auto-update (optional; manual GitHub Releases fine for MVP)  
- Localization (English only)  

---

## 7. Phase 2 — v1.0 public release

Everything in MVP **plus**:

### 7.1 Window / zones complete

- [x] Dock: swipe up activate, swipe down hide app (pinch out ⌘N; pinch quit optional)  
- [x] Menubar: swipe L/R focus next/prev window; swipe down hide others; swipe up unminimize  
- [x] Pinch out titlebar → native fullscreen (MVP path)  

- [x] Thirds + two-thirds + centerLarge (long swipe L/R; keyboard cycle)  
- [x] Move window to adjacent **display** (3F titlebar + ⌃⌥⌘ arrows)  
- [x] Keyboard snap (⌃⌥ + arrows; cycle thirds)  
- [x] Modifier + drag to move window (⌥⌘ + drag)  
- [x] Modifier + drag to resize window (⌃⌘ + drag)  
- [x] Magic Mouse: 2-finger top-touch drag → move window  

### 7.2 Customization

- [x] Gesture list with remap action (from fixed action catalog)  
- [x] Per-app overrides (scope: all / Magic Mouse / window gestures / keyboard+drag)  
- [x] Import / export config JSON  
- [x] Reset single gesture to default  
- [x] Diff badge: “modified from Standard” (per row + Modified filter)  

### 7.3 Product

- [x] Interactive tutorial (≤90s; skippable; live MM tap / titlebar snap / middle-click)  
- [x] In-app cheat sheet (searchable catalog)  
- [x] About pane: license (MIT); public repo URL when published  
- [ ] Optional Sparkle / GitHub update check  
- [ ] Public notarized DMG on GitHub Releases (local DMG + release notes ready)  
- [ ] Homebrew cask (or documented `brew install --cask` path; sketch in RELEASING.md)
- [ ] Conflict UX polished  

### 7.4 Action catalog (v1.0 minimum)

Window snaps/maximize/minimize/close/fullscreen · clicks · common keystrokes (⌘C/V/X/Z…, Escape, Spotlight, …) · freeform recorded keystroke · open application · Mission Control / Exposé / Spaces · browser tab next/prev/close/new

### 7.5 v1.0 launch checklist

- [ ] `LICENSE` (MIT) + `CONTRIBUTING.md` + `CODE_OF_CONDUCT.md` (optional but recommended)  
- [ ] Privacy policy (local-only data; short README section is enough)  
- [ ] Trademark / name clearance for “Sanne”  
- [ ] Icon set (menu bar template + app icon)  
- [ ] 10-app compatibility matrix tested  
- [ ] macOS 13–26 (current) smoke tests  
- [ ] Landing page or README demo GIFs  
- [ ] Good first issues labeled for contributors  

---

## 8. Phase 3 — v1.x

Priority order:

1. **Gaming mode** (Magic Mouse)  
2. **Spaces** window move (if API quality OK)  
3. **HUD** labels  
4. **On touch release** action pairs (CAD middle-drag)  
5. **Adjacent window divider** resize  
6. **Edge drag-to-snap**  
7. **Hyper key** + simple key remaps  
8. **Shell / Shortcuts / AppleScript** actions  
9. **Preset packs** (Minimal, Windows refugee, Browser)  
10. **Sensitivity profiles** advanced  
11. **Safe mode** launch  

---

## 9. Phase 4 — v2 (parked)

- Drawing gestures  
- Floating quick-action palette  
- Launcher-lite  
- Config sync  
- Third-party mouse depth  
- Vertical Dock polish edge cases  

---

## 10. Feature priority backlog (engineering tickets)

### P0 — MVP

| ID | Item |
|----|------|
| MVP-01 | App skeleton, menu bar, pause |
| MVP-02 | Permissions onboarding |
| MVP-03 | MT device pipeline |
| MVP-04 | LayoutGeometry + AX snap |
| MVP-05 | Snap preview overlay |
| MVP-06 | ZoneClassifier titlebar |
| MVP-07 | Titlebar swipe/pinch recognizers |
| MVP-08 | Wire titlebar → window actions |
| MVP-09 | Magic Mouse tap left/right |
| MVP-10 | Middle click 3-finger |
| MVP-11 | Tap-drag |
| MVP-12 | Palm rejection v1 |
| MVP-13 | Settings toggles + sensitivity |
| MVP-14 | Wake rebind + multi-monitor |
| MVP-15 | Competing app warning |

### P1 — v1.0

| ID | Item |
|----|------|
| V1-01 | Dock zones |
| V1-02 | Menubar zones |
| V1-03 | Thirds / continuous layouts |
| V1-04 | Display throw |
| V1-05 | Keyboard snap |
| V1-06 | Move/resize modifiers + MM |
| V1-07 | Rule editor UI |
| V1-08 | Per-app rules |
| V1-09 | Import/export |
| V1-10 | Tutorial + cheat sheet |
| V1-11 | About / OSS license UI + repo link |
| V1-12 | GitHub Releases + optional Sparkle |
| V1-13 | Homebrew cask |

### P2 — v1.x

| ID | Item |
|----|------|
| VX-01 | Gaming mode |
| VX-02 | Spaces move |
| VX-03 | HUD |
| VX-04 | Script actions |
| VX-05 | Presets gallery |
| VX-06 | Hyper / remaps |

---

## 11. Community beta design

| Item | Plan |
|------|------|
| Cohort | Public pre-release tags + optional private tester Discord/GitHub Discussions |
| Split | Encourage both Magic Mouse–primary and trackpad-primary reports |
| Duration | 3–4 weeks before v1.0 tag |
| Feedback | GitHub Issues templates (bug / device matrix) |
| Builds | Weekly (or per-merge) artifacts; changelog in Releases |
| Kill criteria | Unfixable false clicks; MT broken on shipping OS |

---

## 12. Effort sketch (indicative)

| Phase | Eng weeks (1 senior Mac dev) |
|-------|------------------------------|
| Phase 0 spike | 1–2 |
| MVP | 6–8 |
| v1.0 | +4–6 |
| v1.1 (gaming, HUD, spaces) | +3–4 |

Two developers can compress calendar time ~1.5× on UI vs input split; MT pipeline stays single-owner.

---

## 13. Definition of Done (any feature)

1. Works on built-in trackpad **and** Magic Mouse path if applicable  
2. Has a default in Sanne Standard **or** is opt-in advanced  
3. Can be disabled without restart  
4. Documented in cheat sheet  
5. Survives sleep/wake  
6. No more than one known-won’t-fix app (documented)  

---

## 14. Summary: what we tell users at each stage

| Stage | Promise |
|-------|---------|
| **MVP beta** | “Silent Magic Mouse clicks + titlebar snap gestures. Rough settings. Free & open source.” |
| **v1.0** | “Full Sanne Standard zones, customize anything. Free forever — MIT on GitHub.” |
| **v1.x** | “Power features without becoming BTT.” |

---

*End of MVP scope*
