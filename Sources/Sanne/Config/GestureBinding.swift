import Foundation

/// Which layer of the binding stack an editor reads and writes.
///
/// The layers are ordered: an app's entry sits above the global one, which sits above the Sanne
/// Standard default. Modelling the choice as a value — rather than threading an optional bundle id
/// through every mutation — is what keeps `GestureEditorView` free of mode branching.
///
/// Named for the bindings it scopes so it can't be read as a sibling of `AppOverrideScope`, which
/// scopes something unrelated: which subsystems an app *pauses*.
enum GestureBindingScope: Equatable {
    /// The user's global remap layer (Settings → Gestures).
    case global
    /// One app's layer, in force while that app is frontmost.
    case app(bundleId: String)

    /// Bundle id to resolve against: nil for the global layer, which is exactly what
    /// `BindingResolver.resolve` wants for `frontmostBundleId`.
    var bundleId: String? {
        switch self {
        case .global: return nil
        case .app(let bundleId): return bundleId
        }
    }
}

/// Per-gesture override of the layer below (only fields that actually differ need be stored).
struct GestureOverrideEntry: Codable, Equatable {
    /// When set, overrides legacy section toggles for this slot.
    var enabled: Bool?
    /// Catalog action id; nil keeps the inherited action.
    var actionId: String?

    init(enabled: Bool? = nil, actionId: String? = nil) {
        self.enabled = enabled
        self.actionId = actionId
    }

    /// `actionId` only when it actually names an action.
    ///
    /// The map has always treated `nil` and `""` alike, so every reader goes through this instead of
    /// repeating the emptiness check.
    var effectiveActionId: String? {
        guard let actionId, !actionId.isEmpty else { return nil }
        return actionId
    }

    var isEmpty: Bool {
        enabled == nil && effectiveActionId == nil
    }

    /// This entry layered on top of `base`, each field falling through to `base` when unset here.
    ///
    /// Field-wise rather than whole-entry on purpose: an app that only remaps the action still
    /// inherits the global enable state, so a per-app remap can never silently switch a gesture back
    /// on — and conversely an app can enable a gesture that is off everywhere else.
    func layered(over base: GestureOverrideEntry?) -> GestureOverrideEntry {
        GestureOverrideEntry(
            enabled: enabled ?? base?.enabled,
            actionId: effectiveActionId ?? base?.effectiveActionId
        )
    }
}

extension SanneConfig {
    /// Stored entry for a slot in one scope, or nil when that scope leaves the slot alone.
    func gestureOverride(slotId: String, scope: GestureBindingScope) -> GestureOverrideEntry? {
        switch scope {
        case .global:
            return gestureOverrides[slotId]
        case .app(let bundleId):
            return appGestureOverrides[bundleId]?[slotId]
        }
    }

    /// Bundle ids that customise at least one gesture.
    ///
    /// Pruning in `setGestureOverride` is what lets this be a plain key list: an app appears here
    /// only while it really has bindings of its own. Settings → Apps uses it to list apps whose
    /// remaps would otherwise be unreachable, so nothing the user configured can go invisible.
    ///
    /// Sorted by the name the list actually shows rather than by bundle id, which would order
    /// "Safari" under `c` for `com.apple.Safari` and read as unsorted. `appDisplayName` falls back to
    /// the bundle id for an app that is no longer installed, so uninstalled entries still sort
    /// predictably instead of dropping out.
    var appsWithGestureOverrides: [String] {
        appGestureOverrides.keys.sorted {
            ActionCatalog.appDisplayName(bundleId: $0)
                .localizedCaseInsensitiveCompare(ActionCatalog.appDisplayName(bundleId: $1)) == .orderedAscending
        }
    }

    /// Writes `entry` into `scope`, pruning empties.
    ///
    /// Pruning is the invariant the rest of the feature leans on: a slot present in a map always
    /// means "this scope customises it", which is what makes the Modified badge, the Reset buttons
    /// and the exported JSON honest without any extra bookkeeping.
    mutating func setGestureOverride(slotId: String, entry: GestureOverrideEntry, scope: GestureBindingScope) {
        switch scope {
        case .global:
            if entry.isEmpty {
                gestureOverrides.removeValue(forKey: slotId)
            } else {
                gestureOverrides[slotId] = entry
            }
        case .app(let bundleId):
            var map = appGestureOverrides[bundleId] ?? [:]
            if entry.isEmpty {
                map.removeValue(forKey: slotId)
            } else {
                map[slotId] = entry
            }
            // Drop the app's whole map once it customises nothing, so the config never accumulates
            // empty dictionaries for apps the user has since reset.
            if map.isEmpty {
                appGestureOverrides.removeValue(forKey: bundleId)
            } else {
                appGestureOverrides[bundleId] = map
            }
        }
    }

    /// `scope` defaults to `.global` here and below purely for backward compatibility: that is what
    /// every call site predating per-app bindings meant.
    mutating func setGestureOverride(
        slotId: String,
        enabled: Bool?,
        actionId: String?,
        scope: GestureBindingScope = .global
    ) {
        var entry = gestureOverride(slotId: slotId, scope: scope) ?? GestureOverrideEntry()
        entry.enabled = enabled
        entry.actionId = actionId
        setGestureOverride(slotId: slotId, entry: entry, scope: scope)
    }

    mutating func clearGestureOverride(slotId: String, scope: GestureBindingScope = .global) {
        setGestureOverride(slotId: slotId, entry: GestureOverrideEntry(), scope: scope)
    }

    mutating func clearAllGestureOverrides(scope: GestureBindingScope = .global) {
        switch scope {
        case .global:
            gestureOverrides.removeAll()
        case .app(let bundleId):
            appGestureOverrides.removeValue(forKey: bundleId)
        }
    }

    /// Turn on the section toggle that gates this slot, so the recognizer still emits the gesture.
    ///
    /// Always global, even when the caller is editing one app's bindings: the legacy toggles gate
    /// *recognition*, which happens before Sanne knows which app will receive the action. There is
    /// no per-app equivalent to switch, and leaving the gate off would mean a binding the user just
    /// chose never fires.
    ///
    /// Lives on the config rather than in the editor because it is pure config mutation — a
    /// 40-case switch over stored properties has no business in a SwiftUI view.
    mutating func enableLegacyGate(slotId: String) {
        guard let slot = GestureSlots.slot(id: slotId) else { return }
        switch slot.legacyGate {
        case .mmLeftTap: magicMouseTaps.leftTap = true
        case .mmRightTap: magicMouseTaps.rightTap = true
        case .mmMiddleTwo: magicMouseTaps.middleTwoFinger = true
        case .mmMiddleThree: magicMouseTaps.middleThreeFinger = true
        case .mmTapDrag: magicMouseTaps.tapDrag = true
        case .mmTwoFingerDoubleMC: magicMouseTaps.twoFingerDoubleTapMissionControl = true
        case .mmTwoFingerSwipeUp: magicMouseTaps.twoFingerSwipeUpMissionControl = true
        case .mmTwoFingerSwipeDown: magicMouseTaps.twoFingerSwipeDownAppExpose = true
        case .mmTwoFingerSpaces: magicMouseTaps.twoFingerSwipeSpaces = true
        case .mmTwoFingerTopEdgeMove: magicMouseTaps.twoFingerTopEdgeMove = true
        case .mmOneFingerSwipePages: magicMouseTaps.oneFingerSwipePages = true
        case .tbHalves: titlebarGestures.swipeHalves = true
        case .tbThirds: titlebarGestures.swipeThirds = true
        case .tbQuarters: titlebarGestures.swipeQuarters = true
        case .tbMaximize: titlebarGestures.swipeMaximize = true
        case .tbMinimize: titlebarGestures.swipeMinimize = true
        case .tbPinchClose: titlebarGestures.pinchClose = true
        case .tbPinchFullscreen: titlebarGestures.pinchFullscreen = true
        case .tbThreeFingerDisplay: titlebarGestures.threeFingerMoveDisplay = true
        case .dockActivate: dockGestures.swipeActivate = true
        case .dockHide: dockGestures.swipeHide = true
        case .dockNew: dockGestures.pinchNewWindow = true
        case .dockQuit: dockGestures.pinchQuit = true
        case .mbCycle: menubarGestures.swipeCycleWindows = true
        case .mbHideOthers: menubarGestures.swipeHideOthers = true
        case .mbUnminimize: menubarGestures.swipeUnminimize = true
        case .trackpadMiddle: trackpad.threeFingerTapMiddleClick = true
        case .trackpadThreeFingerDrag: trackpad.threeFingerDrag = true
        case .trackpadFreeThreeSwipe: trackpad.threeFingerSwipes = true
        case .trackpadFreeFourSwipe: trackpad.fourFingerSwipes = true
        case .trackpadFreeFourTap: trackpad.fourFingerTap = true
        case .trackpadTipTap: trackpad.tipTap = true
        case .mmThreeFingerSwipes: magicMouseTaps.threeFingerSwipes = true
        case .magicMouseMaster: magicMouseTaps.enabled = true
        case .titlebarMaster: titlebarGestures.enabled = true
        case .dockMaster: dockGestures.enabled = true
        case .menubarMaster: menubarGestures.enabled = true
        case .mmMultiClick: magicMouseTaps.multiClick = true
        }
        switch slot.group {
        case .magicMouse: magicMouseTaps.enabled = true
        case .titlebar: titlebarGestures.enabled = true
        case .dock: dockGestures.enabled = true
        case .menubar: menubarGestures.enabled = true
        case .trackpad: break
        }
    }
}
