import AppKit
import CoreGraphics
import Foundation

/// Thread-safe mirror of `SanneConfig.customActions`.
///
/// `ActionCatalog.action(id:)` is called from nonisolated recognizer and menu code, but the defs
/// live in the `@MainActor` `ConfigStore`. Rather than isolate the whole catalog, `ConfigStore`
/// pushes the list here on every config change and lookups take a lock.
private final class CustomActionRegistry: @unchecked Sendable {
    private let lock = NSLock()
    private var ordered: [CustomActionDef] = []
    private var byId: [UUID: CustomActionDef] = [:]

    func replace(with list: [CustomActionDef]) {
        lock.lock()
        defer { lock.unlock() }
        ordered = list
        byId = Dictionary(list.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
    }

    func def(id: UUID) -> CustomActionDef? {
        lock.lock()
        defer { lock.unlock() }
        return byId[id]
    }

    var all: [CustomActionDef] {
        lock.lock()
        defer { lock.unlock() }
        return ordered
    }
}

/// Fixed catalog of actions a gesture can invoke (v1 remap editor).
/// Dynamic actions use encoded ids: `keystroke.custom.<keyCode>.<flags>`, `app.launch.<bundleId>`,
/// and `action.custom.<uuid>` for user-defined scripts.
enum ActionCatalog {
    enum Category: String, CaseIterable, Identifiable {
        case window = "Window"
        case clicks = "Clicks"
        case system = "System"
        case dock = "Dock"
        case menubar = "Menubar"
        case browser = "Browser"
        case keyboard = "Keyboard"
        case apps = "Apps"
        case script = "Scripts"
        case special = "Special"

        var id: String { rawValue }
    }

    struct Action: Identifiable, Hashable {
        let id: String
        let title: String
        let category: Category
        let keywords: [String]

        var searchText: String {
            ([title, category.rawValue, id] + keywords).joined(separator: " ").lowercased()
        }
    }

    // MARK: - IDs

    enum ID {
        static let none = "none"

        static let snapLeftHalf = "window.snap.leftHalf"
        static let snapRightHalf = "window.snap.rightHalf"
        static let snapTopHalf = "window.snap.topHalf"
        static let snapBottomHalf = "window.snap.bottomHalf"
        static let snapTopLeft = "window.snap.topLeft"
        static let snapTopRight = "window.snap.topRight"
        static let snapBottomLeft = "window.snap.bottomLeft"
        static let snapBottomRight = "window.snap.bottomRight"
        static let snapLeftThird = "window.snap.leftThird"
        static let snapCenterThird = "window.snap.centerThird"
        static let snapRightThird = "window.snap.rightThird"
        static let snapLeftTwoThirds = "window.snap.leftTwoThirds"
        static let snapRightTwoThirds = "window.snap.rightTwoThirds"
        static let snapMaximize = "window.snap.maximize"
        static let snapCenter = "window.snap.center"
        static let snapCenterLarge = "window.snap.centerLarge"
        static let snapAlmostMaximize = "window.snap.almostMaximize"
        static let minimize = "window.minimize"
        static let close = "window.close"
        static let fullscreen = "window.fullscreen"
        static let moveDisplayLeft = "window.moveDisplay.left"
        static let moveDisplayRight = "window.moveDisplay.right"

        static let clickLeft = "click.left"
        static let clickRight = "click.right"
        static let clickMiddle = "click.middle"

        static let missionControl = "system.missionControl"
        static let appExpose = "system.appExpose"
        static let spaceLeft = "system.space.left"
        static let spaceRight = "system.space.right"

        static let dockActivate = "dock.activate"
        static let dockHide = "dock.hide"
        static let dockNewWindow = "dock.newWindow"
        static let dockQuit = "dock.quit"

        static let menubarNext = "menubar.nextWindow"
        static let menubarPrev = "menubar.prevWindow"
        static let menubarHideOthers = "menubar.hideOthers"
        static let menubarUnminimize = "menubar.unminimize"

        static let browserNewTab = "browser.newTab"
        static let browserCloseTab = "browser.closeTab"
        static let browserNextTab = "browser.nextTab"
        static let browserPrevTab = "browser.prevTab"
        static let browserBack = "browser.back"
        static let browserForward = "browser.forward"

        static let keyCopy = "keystroke.copy"
        static let keyPaste = "keystroke.paste"
        static let keyCut = "keystroke.cut"
        static let keyUndo = "keystroke.undo"
        static let keyRedo = "keystroke.redo"
        static let keySelectAll = "keystroke.selectAll"
        static let keySave = "keystroke.save"
        static let keyNew = "keystroke.new"
        static let keyClose = "keystroke.close"
        static let keyQuit = "keystroke.quit"
        static let keyHide = "keystroke.hide"
        static let keyFind = "keystroke.find"
        static let keyEscape = "keystroke.escape"
        static let keyDelete = "keystroke.delete"
        static let keyReturn = "keystroke.return"
        static let keySpace = "keystroke.space"
        static let keySpotlight = "keystroke.spotlight"
        static let keySwitchApp = "keystroke.switchApp"

        /// Continuous drag (double-tap-hold). Remapping the slot fires the new
        /// action once when the hold commits, instead of starting a drag session.
        static let drag = "special.drag"
        /// Continuous window move (2F top-edge) — not remappable.
        static let moveWindow = "special.moveWindow"

        /// Prefix for freeform keystrokes: `keystroke.custom.<keyCode>.<flagsRaw>`
        static let customKeystrokePrefix = "keystroke.custom."
        /// Prefix for launch-app: `app.launch.<bundleIdentifier>`
        static let launchAppPrefix = "app.launch."
        /// Prefix for user-defined scripts: `action.custom.<uuid>`
        static let customActionPrefix = "action.custom."
    }

    // MARK: - Custom actions

    private static let customRegistry = CustomActionRegistry()

    /// Called by `ConfigStore` whenever the config changes.
    static func syncCustomActions(_ list: [CustomActionDef]) {
        customRegistry.replace(with: list)
    }

    static func customActionId(_ id: UUID) -> String {
        "\(ID.customActionPrefix)\(id.uuidString)"
    }

    static func parseCustomAction(_ actionId: String) -> UUID? {
        guard actionId.hasPrefix(ID.customActionPrefix) else { return nil }
        return UUID(uuidString: String(actionId.dropFirst(ID.customActionPrefix.count)))
    }

    /// Resolved def, or nil when it has since been deleted.
    static func customAction(id: UUID) -> CustomActionDef? {
        customRegistry.def(id: id)
    }

    // MARK: - Dynamic actions

    /// Encode a freeform keystroke (key + modifiers) as a catalog action id.
    static func customKeystrokeId(keyCode: CGKeyCode, flags: CGEventFlags) -> String {
        "\(ID.customKeystrokePrefix)\(keyCode).\(flags.rawValue)"
    }

    static func parseCustomKeystroke(_ actionId: String) -> (keyCode: CGKeyCode, flags: CGEventFlags)? {
        guard actionId.hasPrefix(ID.customKeystrokePrefix) else { return nil }
        let rest = String(actionId.dropFirst(ID.customKeystrokePrefix.count))
        let parts = rest.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2,
              let key = UInt16(parts[0]),
              let flagsRaw = UInt64(parts[1])
        else { return nil }
        return (CGKeyCode(key), CGEventFlags(rawValue: flagsRaw))
    }

    /// Encode “open this app” as a catalog action id.
    static func launchAppId(bundleId: String) -> String {
        "\(ID.launchAppPrefix)\(bundleId)"
    }

    static func parseLaunchApp(_ actionId: String) -> String? {
        guard actionId.hasPrefix(ID.launchAppPrefix) else { return nil }
        let bid = String(actionId.dropFirst(ID.launchAppPrefix.count))
        return bid.isEmpty ? nil : bid
    }

    static func isDynamicAction(_ actionId: String) -> Bool {
        parseCustomKeystroke(actionId) != nil
            || parseLaunchApp(actionId) != nil
            || parseCustomAction(actionId) != nil
    }

    /// Human-readable chord, e.g. `⌘⇧A` (US key labels).
    static func formatKeystroke(keyCode: CGKeyCode, flags: CGEventFlags) -> String {
        var parts: [String] = []
        if flags.contains(.maskControl) { parts.append("⌃") }
        if flags.contains(.maskAlternate) { parts.append("⌥") }
        if flags.contains(.maskShift) { parts.append("⇧") }
        if flags.contains(.maskCommand) { parts.append("⌘") }
        parts.append(keyLabel(keyCode))
        return parts.joined()
    }

    /// Display name for an app action (falls back to bundle id).
    static func appDisplayName(bundleId: String) -> String {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            return FileManager.default.displayName(atPath: url.path)
        }
        return bundleId
    }

    /// US-layout virtual key labels for titles (fine for system shortcuts).
    static func keyLabel(_ keyCode: CGKeyCode) -> String {
        switch keyCode {
        case 36: return "↩"
        case 48: return "⇥"
        case 49: return "Space"
        case 51: return "⌫"
        case 53: return "⎋"
        case 117: return "⌦"
        case 122: return "F1"
        case 120: return "F2"
        case 99: return "F3"
        case 118: return "F4"
        case 96: return "F5"
        case 97: return "F6"
        case 98: return "F7"
        case 100: return "F8"
        case 101: return "F9"
        case 109: return "F10"
        case 103: return "F11"
        case 111: return "F12"
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        case 116: return "⇞"
        case 121: return "⇟"
        case 115: return "↖"
        case 119: return "↘"
        default:
            if let ch = usLetterNumber(keyCode) { return ch }
            return "Key\(keyCode)"
        }
    }

    private static func usLetterNumber(_ keyCode: CGKeyCode) -> String? {
        let map: [CGKeyCode: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
            11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T",
            18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5", 24: "=", 25: "9", 26: "7",
            27: "-", 28: "8", 29: "0", 30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P",
            37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/", 45: "N",
            46: "M", 47: ".", 50: "`",
        ]
        return map[keyCode]
    }

    /// Modifier-only key codes (ignored when recording).
    static func isModifierKeyCode(_ keyCode: CGKeyCode) -> Bool {
        // ⌘ ⇧ ⌥ ⌃ left/right + Fn
        [54, 55, 56, 57, 58, 59, 60, 61, 62, 63].contains(keyCode)
    }

    static func cgFlags(from ns: NSEvent.ModifierFlags) -> CGEventFlags {
        let m = ns.intersection(.deviceIndependentFlagsMask)
        var flags: CGEventFlags = []
        if m.contains(.command) { flags.insert(.maskCommand) }
        if m.contains(.option) { flags.insert(.maskAlternate) }
        if m.contains(.control) { flags.insert(.maskControl) }
        if m.contains(.shift) { flags.insert(.maskShift) }
        return flags
    }

    static let all: [Action] = [
        .init(id: ID.none, title: "Do nothing", category: .special, keywords: ["disabled", "off"]),

        .init(id: ID.snapLeftHalf, title: "Snap left half", category: .window, keywords: ["tile"]),
        .init(id: ID.snapRightHalf, title: "Snap right half", category: .window, keywords: ["tile"]),
        .init(id: ID.snapTopHalf, title: "Snap top half", category: .window, keywords: []),
        .init(id: ID.snapBottomHalf, title: "Snap bottom half", category: .window, keywords: []),
        .init(id: ID.snapTopLeft, title: "Snap top-left quarter", category: .window, keywords: ["corner"]),
        .init(id: ID.snapTopRight, title: "Snap top-right quarter", category: .window, keywords: ["corner"]),
        .init(id: ID.snapBottomLeft, title: "Snap bottom-left quarter", category: .window, keywords: ["corner"]),
        .init(id: ID.snapBottomRight, title: "Snap bottom-right quarter", category: .window, keywords: ["corner"]),
        .init(id: ID.snapLeftThird, title: "Snap left third", category: .window, keywords: ["thirds"]),
        .init(id: ID.snapCenterThird, title: "Snap center third", category: .window, keywords: ["thirds"]),
        .init(id: ID.snapRightThird, title: "Snap right third", category: .window, keywords: ["thirds"]),
        .init(id: ID.snapLeftTwoThirds, title: "Snap left two-thirds", category: .window, keywords: []),
        .init(id: ID.snapRightTwoThirds, title: "Snap right two-thirds", category: .window, keywords: []),
        .init(id: ID.snapMaximize, title: "Maximize", category: .window, keywords: ["zoom", "fill"]),
        .init(id: ID.snapCenter, title: "Center window", category: .window, keywords: []),
        .init(id: ID.snapCenterLarge, title: "Large center", category: .window, keywords: ["centerLarge"]),
        .init(id: ID.snapAlmostMaximize, title: "Almost maximize", category: .window, keywords: ["inset"]),
        .init(id: ID.minimize, title: "Minimize", category: .window, keywords: []),
        .init(id: ID.close, title: "Close window", category: .window, keywords: []),
        .init(id: ID.fullscreen, title: "Native fullscreen", category: .window, keywords: []),
        .init(id: ID.moveDisplayLeft, title: "Move to display left", category: .window, keywords: ["monitor"]),
        .init(id: ID.moveDisplayRight, title: "Move to display right", category: .window, keywords: ["monitor"]),

        .init(id: ID.clickLeft, title: "Left click", category: .clicks, keywords: ["primary"]),
        .init(id: ID.clickRight, title: "Right-click", category: .clicks, keywords: ["secondary", "context"]),
        .init(id: ID.clickMiddle, title: "Middle-click", category: .clicks, keywords: ["scroll wheel"]),

        .init(id: ID.missionControl, title: "Mission Control", category: .system, keywords: ["spaces"]),
        .init(id: ID.appExpose, title: "App Exposé", category: .system, keywords: ["expose", "windows"]),
        .init(id: ID.spaceLeft, title: "Space left", category: .system, keywords: ["desktop"]),
        .init(id: ID.spaceRight, title: "Space right", category: .system, keywords: ["desktop"]),

        .init(id: ID.dockActivate, title: "Activate Dock app", category: .dock, keywords: ["unminimize"]),
        .init(id: ID.dockHide, title: "Hide Dock app", category: .dock, keywords: []),
        .init(id: ID.dockNewWindow, title: "New window (⌘N)", category: .dock, keywords: []),
        .init(id: ID.dockQuit, title: "Quit app (⌘Q)", category: .dock, keywords: []),

        .init(id: ID.menubarNext, title: "Next window", category: .menubar, keywords: ["cycle"]),
        .init(id: ID.menubarPrev, title: "Previous window", category: .menubar, keywords: ["cycle"]),
        .init(id: ID.menubarHideOthers, title: "Hide other apps", category: .menubar, keywords: []),
        .init(id: ID.menubarUnminimize, title: "Unminimize frontmost", category: .menubar, keywords: []),

        .init(id: ID.browserNewTab, title: "New tab (⌘T)", category: .browser, keywords: []),
        .init(id: ID.browserCloseTab, title: "Close tab (⌘W)", category: .browser, keywords: []),
        .init(id: ID.browserNextTab, title: "Next tab (⌃⇥)", category: .browser, keywords: []),
        .init(id: ID.browserPrevTab, title: "Previous tab (⌃⇧⇥)", category: .browser, keywords: []),
        .init(id: ID.browserBack, title: "Back (mouse btn 3)", category: .browser, keywords: ["history", "swipe", "page", "⌘["]),
        .init(id: ID.browserForward, title: "Forward (mouse btn 4)", category: .browser, keywords: ["history", "swipe", "page", "⌘]"]),

        .init(id: ID.keyCopy, title: "Copy (⌘C)", category: .keyboard, keywords: ["clipboard"]),
        .init(id: ID.keyPaste, title: "Paste (⌘V)", category: .keyboard, keywords: ["clipboard"]),
        .init(id: ID.keyCut, title: "Cut (⌘X)", category: .keyboard, keywords: ["clipboard"]),
        .init(id: ID.keyUndo, title: "Undo (⌘Z)", category: .keyboard, keywords: []),
        .init(id: ID.keyRedo, title: "Redo (⌘⇧Z)", category: .keyboard, keywords: []),
        .init(id: ID.keySelectAll, title: "Select all (⌘A)", category: .keyboard, keywords: []),
        .init(id: ID.keySave, title: "Save (⌘S)", category: .keyboard, keywords: []),
        .init(id: ID.keyNew, title: "New (⌘N)", category: .keyboard, keywords: []),
        .init(id: ID.keyClose, title: "Close (⌘W)", category: .keyboard, keywords: []),
        .init(id: ID.keyQuit, title: "Quit (⌘Q)", category: .keyboard, keywords: []),
        .init(id: ID.keyHide, title: "Hide app (⌘H)", category: .keyboard, keywords: []),
        .init(id: ID.keyFind, title: "Find (⌘F)", category: .keyboard, keywords: []),
        .init(id: ID.keyEscape, title: "Escape", category: .keyboard, keywords: ["esc"]),
        .init(id: ID.keyDelete, title: "Delete / Backspace", category: .keyboard, keywords: ["backspace"]),
        .init(id: ID.keyReturn, title: "Return", category: .keyboard, keywords: ["enter"]),
        .init(id: ID.keySpace, title: "Space", category: .keyboard, keywords: []),
        .init(id: ID.keySpotlight, title: "Spotlight (⌘Space)", category: .keyboard, keywords: ["search"]),
        .init(id: ID.keySwitchApp, title: "App switcher (⌘⇥)", category: .keyboard, keywords: ["cmd tab"]),

        .init(id: ID.drag, title: "Drag (hold)", category: .special, keywords: ["tap-drag"]),
        .init(id: ID.moveWindow, title: "Move window (continuous)", category: .special, keywords: ["top-edge"]),
    ]

    private static let byId: [String: Action] = {
        Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
    }()

    static func action(id: String) -> Action? {
        if let builtIn = byId[id] { return builtIn }
        if let ks = parseCustomKeystroke(id) {
            let chord = formatKeystroke(keyCode: ks.keyCode, flags: ks.flags)
            return Action(
                id: id,
                title: "Keystroke \(chord)",
                category: .keyboard,
                keywords: ["custom", "shortcut", chord]
            )
        }
        if let bid = parseLaunchApp(id) {
            let name = appDisplayName(bundleId: bid)
            return Action(
                id: id,
                title: "Open \(name)",
                category: .apps,
                keywords: ["launch", "open", "app", bid, name]
            )
        }
        if let uuid = parseCustomAction(id) {
            // A binding can outlive its def (deleted while another config was imported, or a
            // hand-edited file). Surface that in the UI instead of showing a raw uuid; the runner
            // treats it as `none`.
            guard let def = customRegistry.def(id: uuid) else {
                return Action(id: id, title: "Missing action", category: .script, keywords: ["custom", "script"])
            }
            return action(for: def)
        }
        return nil
    }

    /// Catalog entry for a def the caller already holds.
    ///
    /// Non-private so the action picker can render its Scripts rows straight from the observed
    /// `ConfigStore` instead of looking each def back up in `customRegistry`, which SwiftUI cannot
    /// observe — the list would otherwise go stale after a save or delete.
    static func action(for def: CustomActionDef) -> Action {
        Action(
            id: customActionId(def.id),
            title: def.displayName,
            category: .script,
            keywords: ["custom", "script", def.kind.rawValue, def.kind.displayName]
        )
    }

    static func title(for id: String) -> String {
        action(id: id)?.title ?? id
    }

    /// Whether firing `actionId` is worth a HUD label.
    ///
    /// The single authority on the question, so the engine's announce is a one-liner and no call
    /// site can hold a divergent opinion. Excluded on purpose:
    ///
    /// - **Clicks** — the cursor already shows the result, and taps are frequent enough that
    ///   labelling them would leave the HUD permanently on screen.
    /// - **Continuous gestures** (`drag`, `moveWindow`) — they have no single moment to announce,
    ///   and the thing being dragged is its own feedback.
    /// - **`none`** — nothing happened.
    ///
    /// Everything else, including remapped keystrokes, launched apps and custom scripts, announces:
    /// those are exactly the actions whose effect can be off-screen or invisible.
    static func announcesInHUD(_ actionId: String) -> Bool {
        switch actionId {
        case ID.none, ID.drag, ID.moveWindow,
             ID.clickLeft, ID.clickRight, ID.clickMiddle:
            return false
        default:
            return true
        }
    }

    static func matches(_ action: Action, query: String) -> Bool {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return true }
        return q.split(separator: " ").allSatisfy { action.searchText.contains($0) }
    }

    /// Layout for snap actions (used for live preview).
    static func snapLayout(for actionId: String) -> WindowLayout? {
        guard actionId.hasPrefix("window.snap.") else { return nil }
        let raw = String(actionId.dropFirst("window.snap.".count))
        return WindowLayout(rawValue: raw)
    }

    /// Built-in catalog plus optional dynamic action (current remap) for the picker list.
    static func grouped(filter query: String = "", includingDynamic dynamicId: String? = nil) -> [(Category, [Action])] {
        var list = all + customRegistry.all.map(action(for:))
        if let dynamicId, isDynamicAction(dynamicId), let dyn = action(id: dynamicId) {
            if !list.contains(where: { $0.id == dyn.id }) {
                list.append(dyn)
            }
        }
        return Category.allCases.compactMap { cat in
            let items = list.filter { $0.category == cat && matches($0, query: query) }
            return items.isEmpty ? nil : (cat, items)
        }
    }
}
