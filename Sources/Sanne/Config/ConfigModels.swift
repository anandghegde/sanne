import Foundation

struct SanneConfig: Codable, Equatable {
    var version: Int = 1
    var presetId: String = "sanne.standard"
    var paused: Bool = false
    var magicMouseTaps: MagicMouseTapConfig = .init()
    var titlebarGestures: TitlebarGestureConfig = .init()
    var dockGestures: DockGestureConfig = .init()
    var menubarGestures: MenubarGestureConfig = .init()
    var trackpad: TrackpadConfig = .init()
    var window: WindowConfig = .init()
    var keyboard: KeyboardConfig = .init()
    var modifierDrag: ModifierDragConfig = .init()
    /// When frontmost app matches an override with `isActive`, Sanne pauses for that app.
    var appOverrides: [AppOverride] = []
    /// Per-gesture remap / enable overrides keyed by `GestureSlots` id.
    var gestureOverrides: [String: GestureOverrideEntry] = [:]
    /// Per-app gesture overrides, `[bundleId: [slotId: entry]]`. Layered field-by-field over
    /// `gestureOverrides` while that app is frontmost, so an app need only state what differs.
    var appGestureOverrides: [String: [String: GestureOverrideEntry]] = [:]
    /// User-defined shell / AppleScript / Shortcuts actions, referenced by `action.custom.<uuid>`.
    var customActions: [CustomActionDef] = []
    /// Brief on-screen label naming the action a gesture just fired.
    var hud: HUDConfig = .init()
    var experimental: ExperimentalConfig = .init()
    var launchAtLogin: Bool = false

    static let `default` = SanneConfig()

    /// Missing keys (older config.json) keep code defaults so upgrades don't wipe settings.
    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 1
        presetId = try c.decodeIfPresent(String.self, forKey: .presetId) ?? "sanne.standard"
        paused = try c.decodeIfPresent(Bool.self, forKey: .paused) ?? false
        magicMouseTaps = try c.decodeIfPresent(MagicMouseTapConfig.self, forKey: .magicMouseTaps) ?? .init()
        titlebarGestures = try c.decodeIfPresent(TitlebarGestureConfig.self, forKey: .titlebarGestures) ?? .init()
        dockGestures = try c.decodeIfPresent(DockGestureConfig.self, forKey: .dockGestures) ?? .init()
        menubarGestures = try c.decodeIfPresent(MenubarGestureConfig.self, forKey: .menubarGestures) ?? .init()
        trackpad = try c.decodeIfPresent(TrackpadConfig.self, forKey: .trackpad) ?? .init()
        window = try c.decodeIfPresent(WindowConfig.self, forKey: .window) ?? .init()
        keyboard = try c.decodeIfPresent(KeyboardConfig.self, forKey: .keyboard) ?? .init()
        modifierDrag = try c.decodeIfPresent(ModifierDragConfig.self, forKey: .modifierDrag) ?? .init()
        appOverrides = try c.decodeIfPresent([AppOverride].self, forKey: .appOverrides) ?? []
        gestureOverrides = try c.decodeIfPresent([String: GestureOverrideEntry].self, forKey: .gestureOverrides) ?? [:]
        appGestureOverrides = try c.decodeIfPresent(
            [String: [String: GestureOverrideEntry]].self,
            forKey: .appGestureOverrides
        ) ?? [:]
        customActions = try c.decodeIfPresent([CustomActionDef].self, forKey: .customActions) ?? []
        hud = try c.decodeIfPresent(HUDConfig.self, forKey: .hud) ?? .init()
        experimental = try c.decodeIfPresent(ExperimentalConfig.self, forKey: .experimental) ?? .init()
        launchAtLogin = try c.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
    }

    /// Active override for the frontmost app, if any (`isActive` still on).
    func activeOverride(forFrontmostBundleId bundleId: String?) -> AppOverride? {
        guard let bundleId else { return nil }
        return appOverrides.first { $0.bundleId == bundleId && $0.isActive }
    }

    /// True when Sanne should fully pause for the given frontmost bundle id (legacy / scope `.all`).
    func isDisabled(forFrontmostBundleId bundleId: String?) -> Bool {
        guard let o = activeOverride(forFrontmostBundleId: bundleId) else { return false }
        return o.scope == .all
    }

    func pausesMagicMouse(forFrontmostBundleId bundleId: String?) -> Bool {
        guard let o = activeOverride(forFrontmostBundleId: bundleId) else { return false }
        return o.scope.pausesMagicMouse
    }

    func pausesWindowGestures(forFrontmostBundleId bundleId: String?) -> Bool {
        guard let o = activeOverride(forFrontmostBundleId: bundleId) else { return false }
        return o.scope.pausesWindowGestures
    }

    func pausesKeyboard(forFrontmostBundleId bundleId: String?) -> Bool {
        guard let o = activeOverride(forFrontmostBundleId: bundleId) else { return false }
        return o.scope.pausesKeyboard
    }

    func pausesModifierDrag(forFrontmostBundleId bundleId: String?) -> Bool {
        guard let o = activeOverride(forFrontmostBundleId: bundleId) else { return false }
        return o.scope.pausesModifierDrag
    }

    /// v1 → v2: copy each legacy enable bool into a slot override when it differs
    /// from the slot default, then bump `version`. Existing remaps are left alone.
    mutating func migrateToSlotEnablement() {
        guard version < 2 else { return }
        for slot in GestureSlots.all {
            if gestureOverrides[slot.id]?.enabled != nil { continue }
            let legacy = GestureSlots.legacyEnabled(slot.legacyGate, config: self)
            let fallback = slot.defaultEnabled
            guard legacy != fallback else { continue }
            var entry = gestureOverrides[slot.id] ?? GestureOverrideEntry()
            entry.enabled = legacy
            gestureOverrides[slot.id] = entry
        }
        version = 2
    }
}

struct MagicMouseTapConfig: Codable, Equatable {
    enum CodingKeys: String, CodingKey {
        case enabled, leftTap, rightTap, middleTwoFinger, middleThreeFinger, tapDrag, multiClick
        case twoFingerDoubleTapMissionControl, twoFingerSwipeUpMissionControl
        case twoFingerSwipeDownAppExpose, twoFingerSwipeSpaces, threeFingerSwipes
        case twoFingerTopEdgeMove, oneFingerSwipePages, leftRightSplit, deadZone, sensitivity, gamingMode
    }

    var enabled: Bool = true
    var leftTap: Bool = true
    var rightTap: Bool = true
    /// 2-finger short touch → middle-click (browser tabs, CAD).
    var middleTwoFinger: Bool = true
    /// 3-finger touch → middle-click.
    var middleThreeFinger: Bool = true
    /// Double-tap-hold on second contact → drag.
    var tapDrag: Bool = true
    /// Double / triple tap → OS multi-click (clickState 2/3). Essential for rename, word select.
    var multiClick: Bool = true
    /// 2-finger double-tap → Mission Control.
    var twoFingerDoubleTapMissionControl: Bool = true
    /// 2-finger swipe up → Mission Control.
    var twoFingerSwipeUpMissionControl: Bool = true
    /// 2-finger swipe down → App Exposé.
    var twoFingerSwipeDownAppExpose: Bool = true
    /// 2-finger swipe L/R → Spaces (off by default; OS often already maps this).
    var twoFingerSwipeSpaces: Bool = false
    /// 3-finger swipe L/R/U/D on the mouse surface. Off by default — three fingers on a
    /// Magic Mouse is an easy accident while gripping it, and the same chord held still is
    /// already a middle-click (travel decides which one fires).
    var threeFingerSwipes: Bool = false
    /// 2 fingers on top edge + move mouse → drag window under cursor.
    var twoFingerTopEdgeMove: Bool = true
    /// 1-finger horizontal swipe → browser/history back & forward.
    /// Replaces macOS “Swipe between pages”, which Multitouch registration typically breaks.
    var oneFingerSwipePages: Bool = true
    var leftRightSplit: Double = 0.5
    var deadZone: Double = 0.08
    /// −2 stricter (fewer scroll false-clicks) … +2 more taps accepted. Default 0.
    var sensitivity: Int = 0
    /// Physical right-hold + left tap still left-clicks (FPS look + fire). Off by default.
    var gamingMode: Bool = false

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        leftTap = try c.decodeIfPresent(Bool.self, forKey: .leftTap) ?? true
        rightTap = try c.decodeIfPresent(Bool.self, forKey: .rightTap) ?? true
        middleTwoFinger = try c.decodeIfPresent(Bool.self, forKey: .middleTwoFinger) ?? true
        middleThreeFinger = try c.decodeIfPresent(Bool.self, forKey: .middleThreeFinger) ?? true
        tapDrag = try c.decodeIfPresent(Bool.self, forKey: .tapDrag) ?? true
        multiClick = try c.decodeIfPresent(Bool.self, forKey: .multiClick) ?? true
        twoFingerDoubleTapMissionControl = try c.decodeIfPresent(Bool.self, forKey: .twoFingerDoubleTapMissionControl) ?? true
        twoFingerSwipeUpMissionControl = try c.decodeIfPresent(Bool.self, forKey: .twoFingerSwipeUpMissionControl) ?? true
        twoFingerSwipeDownAppExpose = try c.decodeIfPresent(Bool.self, forKey: .twoFingerSwipeDownAppExpose) ?? true
        twoFingerSwipeSpaces = try c.decodeIfPresent(Bool.self, forKey: .twoFingerSwipeSpaces) ?? false
        threeFingerSwipes = try c.decodeIfPresent(Bool.self, forKey: .threeFingerSwipes) ?? false
        twoFingerTopEdgeMove = try c.decodeIfPresent(Bool.self, forKey: .twoFingerTopEdgeMove) ?? true
        oneFingerSwipePages = try c.decodeIfPresent(Bool.self, forKey: .oneFingerSwipePages) ?? true
        leftRightSplit = try c.decodeIfPresent(Double.self, forKey: .leftRightSplit) ?? 0.5
        deadZone = try c.decodeIfPresent(Double.self, forKey: .deadZone) ?? 0.08
        sensitivity = try c.decodeIfPresent(Int.self, forKey: .sensitivity) ?? 0
        gamingMode = try c.decodeIfPresent(Bool.self, forKey: .gamingMode) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(enabled, forKey: .enabled)
        try c.encode(multiClick, forKey: .multiClick)
        try c.encode(leftRightSplit, forKey: .leftRightSplit)
        try c.encode(deadZone, forKey: .deadZone)
        try c.encode(sensitivity, forKey: .sensitivity)
        try c.encode(gamingMode, forKey: .gamingMode)
    }
}

struct TitlebarGestureConfig: Codable, Equatable {
    enum CodingKeys: String, CodingKey {
        case enabled, swipeHalves, swipeQuarters, swipeThirds, swipeMaximize, swipeMinimize
        case pinchClose, pinchFullscreen, threeFingerMoveDisplay
    }

    var enabled: Bool = true
    var swipeHalves: Bool = true
    var swipeQuarters: Bool = true
    /// Long 2-finger swipe L/R → thirds / two-thirds (preview shows target).
    var swipeThirds: Bool = true
    var swipeMaximize: Bool = true
    var swipeMinimize: Bool = true
    var pinchClose: Bool = true
    var pinchFullscreen: Bool = true
    /// 3-finger swipe L/R on titlebar → move window to adjacent display.
    var threeFingerMoveDisplay: Bool = true

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        swipeHalves = try c.decodeIfPresent(Bool.self, forKey: .swipeHalves) ?? true
        swipeQuarters = try c.decodeIfPresent(Bool.self, forKey: .swipeQuarters) ?? true
        swipeThirds = try c.decodeIfPresent(Bool.self, forKey: .swipeThirds) ?? true
        swipeMaximize = try c.decodeIfPresent(Bool.self, forKey: .swipeMaximize) ?? true
        swipeMinimize = try c.decodeIfPresent(Bool.self, forKey: .swipeMinimize) ?? true
        pinchClose = try c.decodeIfPresent(Bool.self, forKey: .pinchClose) ?? true
        pinchFullscreen = try c.decodeIfPresent(Bool.self, forKey: .pinchFullscreen) ?? true
        threeFingerMoveDisplay = try c.decodeIfPresent(Bool.self, forKey: .threeFingerMoveDisplay) ?? true
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(enabled, forKey: .enabled)
    }
}

struct DockGestureConfig: Codable, Equatable {
    enum CodingKeys: String, CodingKey {
        case enabled, swipeActivate, swipeHide, pinchNewWindow, pinchQuit
    }

    var enabled: Bool = true
    /// Swipe up on Dock icon → activate / unhide / unminimize app.
    var swipeActivate: Bool = true
    /// Swipe down on Dock icon → hide app.
    var swipeHide: Bool = true
    /// Pinch out → new window (⌘N).
    var pinchNewWindow: Bool = true
    /// Pinch in → quit (⌘Q). Off by default — easy to trigger by accident.
    var pinchQuit: Bool = false

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        swipeActivate = try c.decodeIfPresent(Bool.self, forKey: .swipeActivate) ?? true
        swipeHide = try c.decodeIfPresent(Bool.self, forKey: .swipeHide) ?? true
        pinchNewWindow = try c.decodeIfPresent(Bool.self, forKey: .pinchNewWindow) ?? true
        pinchQuit = try c.decodeIfPresent(Bool.self, forKey: .pinchQuit) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(enabled, forKey: .enabled)
    }
}

struct MenubarGestureConfig: Codable, Equatable {
    enum CodingKeys: String, CodingKey {
        case enabled, swipeCycleWindows, swipeHideOthers, swipeUnminimize
    }

    var enabled: Bool = true
    /// Swipe L/R → previous / next window (⌘` / ⌘⇧`).
    var swipeCycleWindows: Bool = true
    /// Swipe down → hide other apps (⌥⌘H).
    var swipeHideOthers: Bool = true
    /// Swipe up → unminimize / focus frontmost app windows.
    var swipeUnminimize: Bool = true

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        swipeCycleWindows = try c.decodeIfPresent(Bool.self, forKey: .swipeCycleWindows) ?? true
        swipeHideOthers = try c.decodeIfPresent(Bool.self, forKey: .swipeHideOthers) ?? true
        swipeUnminimize = try c.decodeIfPresent(Bool.self, forKey: .swipeUnminimize) ?? true
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(enabled, forKey: .enabled)
    }
}

struct TrackpadConfig: Codable, Equatable {
    enum CodingKeys: String, CodingKey {
        case threeFingerTapMiddleClick, threeFingerDrag, threeFingerSwipes
        case fourFingerSwipes, fourFingerTap, tipTap, sensitivity
    }

    var threeFingerTapMiddleClick: Bool = true
    /// 3-finger drag in free space → left-button drag (text select, file move).
    /// Same idea as macOS Accessibility “Three Finger Drag” / BTT.
    var threeFingerDrag: Bool = true
    /// Free-space 3-finger swipes L/R/U/D. Off by default — macOS consumes these for
    /// Mission Control / spaces, and registering multitouch does not suppress the system
    /// gesture, so users must turn the macOS equivalents off first.
    var threeFingerSwipes: Bool = false
    /// Free-space 4-finger swipes L/R/U/D. Off by default (same macOS conflict).
    var fourFingerSwipes: Bool = false
    /// Free-space 4-finger tap. Off by default.
    var fourFingerTap: Bool = false
    /// Tip-tap: rest one finger, tap beside it (left / right are separate gestures).
    var tipTap: Bool = true
    var sensitivity: Int = 0

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        threeFingerTapMiddleClick = try c.decodeIfPresent(Bool.self, forKey: .threeFingerTapMiddleClick) ?? true
        threeFingerDrag = try c.decodeIfPresent(Bool.self, forKey: .threeFingerDrag) ?? true
        threeFingerSwipes = try c.decodeIfPresent(Bool.self, forKey: .threeFingerSwipes) ?? false
        fourFingerSwipes = try c.decodeIfPresent(Bool.self, forKey: .fourFingerSwipes) ?? false
        fourFingerTap = try c.decodeIfPresent(Bool.self, forKey: .fourFingerTap) ?? false
        tipTap = try c.decodeIfPresent(Bool.self, forKey: .tipTap) ?? true
        sensitivity = try c.decodeIfPresent(Int.self, forKey: .sensitivity) ?? 0
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(sensitivity, forKey: .sensitivity)
    }
}

struct WindowConfig: Codable, Equatable {
    var gap: Double = 0
    var showPreview: Bool = true
    var haptics: Bool = true
}

/// Gated features that are not day-one. Off until the user turns them on.
struct ExperimentalConfig: Codable, Equatable {
    /// Move the focused window to the previous / next Space. Private CGS; HUD on failure.
    var windowToSpace: Bool = false

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        windowToSpace = try c.decodeIfPresent(Bool.self, forKey: .windowToSpace) ?? false
    }
}

/// The overlay that names the action a gesture just fired.
///
/// On by default: remapped gestures are invisible by nature, and an action that fires somewhere
/// off-screen (a Space switch, a script) is otherwise indistinguishable from one that silently did
/// nothing. Clicks and continuous drags are never announced — see `ActionCatalog.announcesInHUD`.
struct HUDConfig: Codable, Equatable {
    var enabled: Bool = true

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
    }
}

/// Global keyboard window snapping (⌃⌥ chord — never bare arrows).
struct KeyboardConfig: Codable, Equatable {
    enum CodingKeys: String, CodingKey {
        case enabled, snapWithArrows, cycleThirds, moveToAdjacentDisplay
    }

    var enabled: Bool = true
    /// ⌃⌥ + ←/→ cycle left/right layouts; ↑ maximize; ↓ restore; ↩ center.
    var snapWithArrows: Bool = true
    /// When true, repeated ←/→ cycles half → third → two-thirds.
    var cycleThirds: Bool = true
    /// ⌃⌥⌘ + ←/→ move focused window to adjacent display.
    var moveToAdjacentDisplay: Bool = true

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        snapWithArrows = try c.decodeIfPresent(Bool.self, forKey: .snapWithArrows) ?? true
        cycleThirds = try c.decodeIfPresent(Bool.self, forKey: .cycleThirds) ?? true
        moveToAdjacentDisplay = try c.decodeIfPresent(Bool.self, forKey: .moveToAdjacentDisplay) ?? true
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(enabled, forKey: .enabled)
        try c.encode(cycleThirds, forKey: .cycleThirds)
    }
}

/// Modifier names for Codable chords (maps to `NSEvent.ModifierFlags`).
enum ModifierName: String, Codable, Equatable, CaseIterable {
    case control
    case option
    case shift
    case command
}

/// Hold modifiers + left-drag to move/resize a window from anywhere.
struct ModifierDragConfig: Codable, Equatable {
    var enabled: Bool = true
    var moveEnabled: Bool = true
    var resizeEnabled: Bool = true
    /// Default ⌥⌘ — hold and drag to move window.
    var moveModifiers: [ModifierName] = [.option, .command]
    /// Default ⌃⌘ — hold and drag to resize from nearest edge/corner.
    var resizeModifiers: [ModifierName] = [.control, .command]

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        moveEnabled = try c.decodeIfPresent(Bool.self, forKey: .moveEnabled) ?? true
        resizeEnabled = try c.decodeIfPresent(Bool.self, forKey: .resizeEnabled) ?? true
        moveModifiers = try c.decodeIfPresent([ModifierName].self, forKey: .moveModifiers) ?? [.option, .command]
        resizeModifiers = try c.decodeIfPresent([ModifierName].self, forKey: .resizeModifiers) ?? [.control, .command]
    }
}

/// Which Sanne subsystems pause while an app is frontmost.
enum AppOverrideScope: String, Codable, Equatable, CaseIterable, Identifiable {
    /// Everything (Magic Mouse, window zones, keyboard, modifier-drag).
    case all
    /// Magic Mouse taps / multi-finger only.
    case magicMouse
    /// Titlebar, Dock, menubar, free-space trackpad.
    case windowGestures
    /// Keyboard snap + modifier-drag.
    case keyboardAndDrag

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "All Sanne"
        case .magicMouse: return "Magic Mouse only"
        case .windowGestures: return "Window gestures only"
        case .keyboardAndDrag: return "Keyboard & drag only"
        }
    }

    var pausesMagicMouse: Bool {
        self == .all || self == .magicMouse
    }

    var pausesWindowGestures: Bool {
        self == .all || self == .windowGestures
    }

    var pausesKeyboard: Bool {
        self == .all || self == .keyboardAndDrag
    }

    var pausesModifierDrag: Bool {
        self == .all || self == .keyboardAndDrag
    }
}

/// Per-app override: pause selected Sanne features while the app is frontmost.
struct AppOverride: Codable, Equatable, Identifiable {
    var bundleId: String
    var displayName: String
    /// When true, the override pauses the selected scope. Off keeps the row without pausing.
    var isActive: Bool = true
    /// Which subsystems pause while active. Default `.all` matches legacy behavior.
    var scope: AppOverrideScope = .all

    var id: String { bundleId }

    enum CodingKeys: String, CodingKey {
        case bundleId, displayName, isActive, disabled, scope
    }

    init(
        bundleId: String,
        displayName: String,
        isActive: Bool = true,
        scope: AppOverrideScope = .all
    ) {
        self.bundleId = bundleId
        self.displayName = displayName
        self.isActive = isActive
        self.scope = scope
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        bundleId = try c.decode(String.self, forKey: .bundleId)
        displayName = try c.decodeIfPresent(String.self, forKey: .displayName) ?? bundleId
        // `disabled` was the 0.2.0 name for the same bit (true = override is on).
        if let active = try c.decodeIfPresent(Bool.self, forKey: .isActive) {
            isActive = active
        } else if let disabled = try c.decodeIfPresent(Bool.self, forKey: .disabled) {
            isActive = disabled
        } else {
            isActive = true
        }
        scope = try c.decodeIfPresent(AppOverrideScope.self, forKey: .scope) ?? .all
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(bundleId, forKey: .bundleId)
        try c.encode(displayName, forKey: .displayName)
        try c.encode(isActive, forKey: .isActive)
        try c.encode(scope, forKey: .scope)
    }
}
