import Foundation

/// Static Sanne Standard gesture reference for the cheat sheet and tutorial.
enum GestureCatalog {
    struct Entry: Identifiable, Hashable {
        let id: String
        let category: Category
        let gesture: String
        let action: String
        /// Extra keywords for search (not shown).
        let keywords: [String]

        enum Category: String, CaseIterable, Identifiable, Hashable {
            case titlebar = "Titlebar"
            case magicMouse = "Magic Mouse"
            case dock = "Dock"
            case menubar = "Menubar"
            case trackpad = "Trackpad"
            case keyboard = "Keyboard"
            case modifierDrag = "Modifier + drag"

            var id: String { rawValue }

            var systemImage: String {
                switch self {
                case .titlebar: return "rectangle.topthird.inset.filled"
                case .magicMouse: return "computermouse"
                case .dock: return "dock.rectangle"
                case .menubar: return "menubar.rectangle"
                case .trackpad: return "rectangle.and.hand.point.up.left"
                case .keyboard: return "keyboard"
                case .modifierDrag: return "arrow.up.and.down.and.arrow.left.and.right"
                }
            }
        }
    }

    static let all: [Entry] = [
        // Titlebar
        .init(id: "tb-half-l", category: .titlebar, gesture: "2-finger swipe ←", action: "Snap left half", keywords: ["halves", "tile"]),
        .init(id: "tb-half-r", category: .titlebar, gesture: "2-finger swipe →", action: "Snap right half", keywords: ["halves", "tile"]),
        .init(id: "tb-third-l", category: .titlebar, gesture: "Long 2-finger swipe ←", action: "Left third", keywords: ["thirds"]),
        .init(id: "tb-third-r", category: .titlebar, gesture: "Long 2-finger swipe →", action: "Right third", keywords: ["thirds"]),
        .init(id: "tb-max", category: .titlebar, gesture: "2-finger swipe ↑", action: "Maximize", keywords: ["fullscreen", "zoom"]),
        .init(id: "tb-center", category: .titlebar, gesture: "Long 2-finger swipe ↑", action: "Large center", keywords: ["centerLarge"]),
        .init(id: "tb-min", category: .titlebar, gesture: "2-finger swipe ↓", action: "Minimize", keywords: ["hide"]),
        .init(id: "tb-q-tl", category: .titlebar, gesture: "Diagonal ↖", action: "Top-left quarter", keywords: ["quarters", "corner"]),
        .init(id: "tb-q-tr", category: .titlebar, gesture: "Diagonal ↗", action: "Top-right quarter", keywords: ["quarters", "corner"]),
        .init(id: "tb-q-bl", category: .titlebar, gesture: "Diagonal ↙", action: "Bottom-left quarter", keywords: ["quarters", "corner"]),
        .init(id: "tb-q-br", category: .titlebar, gesture: "Diagonal ↘", action: "Bottom-right quarter", keywords: ["quarters", "corner"]),
        .init(id: "tb-close", category: .titlebar, gesture: "Pinch in", action: "Close window", keywords: ["pinch"]),
        .init(id: "tb-fs", category: .titlebar, gesture: "Pinch out", action: "Native fullscreen", keywords: ["pinch"]),
        .init(id: "tb-display", category: .titlebar, gesture: "3-finger swipe ←/→", action: "Move to adjacent display", keywords: ["monitor", "screen"]),
        .init(id: "tb-restore", category: .titlebar, gesture: "Same snap twice", action: "Restore previous frame", keywords: ["undo", "toggle"]),

        // Magic Mouse
        .init(id: "mm-left", category: .magicMouse, gesture: "Tap left side", action: "Left click", keywords: ["tap", "silent"]),
        .init(id: "mm-right", category: .magicMouse, gesture: "Tap right side", action: "Right-click", keywords: ["context"]),
        .init(id: "mm-multi", category: .magicMouse, gesture: "Double / triple tap", action: "Multi-click (rename / word / line)", keywords: ["clickState"]),
        .init(id: "mm-2f-mid", category: .magicMouse, gesture: "2-finger touch", action: "Middle-click", keywords: ["tab"]),
        .init(id: "mm-3f-mid", category: .magicMouse, gesture: "3-finger touch", action: "Middle-click", keywords: ["tab"]),
        // Same chord as the 3-finger middle-click above — travel decides which one fires.
        .init(id: "mm-3f-lr", category: .magicMouse, gesture: "3-finger swipe ←/→", action: "Previous / next tab (off by default)", keywords: ["mouse", "tabs", "BTT"]),
        .init(id: "mm-3f-up", category: .magicMouse, gesture: "3-finger swipe ↑", action: "Mission Control (off by default)", keywords: ["mouse", "spaces"]),
        .init(id: "mm-3f-down", category: .magicMouse, gesture: "3-finger swipe ↓", action: "App Exposé (off by default)", keywords: ["mouse", "expose"]),
        .init(id: "mm-drag", category: .magicMouse, gesture: "Double-tap and hold", action: "Drag", keywords: ["tap-drag"]),
        .init(id: "mm-2f-mc", category: .magicMouse, gesture: "2-finger double-tap", action: "Mission Control", keywords: ["spaces"]),
        .init(id: "mm-2f-up", category: .magicMouse, gesture: "2-finger swipe up", action: "Mission Control", keywords: []),
        .init(id: "mm-2f-down", category: .magicMouse, gesture: "2-finger swipe down", action: "App Exposé", keywords: ["expose"]),
        .init(id: "mm-2f-lr", category: .magicMouse, gesture: "2-finger swipe ←/→", action: "Spaces (off by default)", keywords: ["desktop"]),
        .init(id: "mm-2f-top", category: .magicMouse, gesture: "2 fingers on top edge + move", action: "Move window under cursor", keywords: ["drag", "top"]),

        // Dock
        .init(id: "dock-up", category: .dock, gesture: "2-finger swipe ↑ on icon", action: "Activate / unminimize", keywords: ["dock"]),
        .init(id: "dock-down", category: .dock, gesture: "2-finger swipe ↓ on icon", action: "Hide app", keywords: ["dock"]),
        .init(id: "dock-new", category: .dock, gesture: "Pinch out on icon", action: "New window (⌘N)", keywords: []),
        .init(id: "dock-quit", category: .dock, gesture: "Pinch in on icon", action: "Quit (off by default)", keywords: ["⌘Q"]),

        // Menubar
        .init(id: "mb-next", category: .menubar, gesture: "2-finger swipe →", action: "Next window", keywords: ["cycle", "⌘`"]),
        .init(id: "mb-prev", category: .menubar, gesture: "2-finger swipe ←", action: "Previous window", keywords: ["cycle"]),
        .init(id: "mb-hide", category: .menubar, gesture: "2-finger swipe ↓", action: "Hide other apps", keywords: ["⌥⌘H"]),
        .init(id: "mb-unmin", category: .menubar, gesture: "2-finger swipe ↑", action: "Unminimize frontmost", keywords: []),

        // Trackpad free-space
        .init(id: "tp-mid", category: .trackpad, gesture: "3-finger tap (free space)", action: "Middle-click", keywords: ["browser"]),
        .init(id: "tp-drag", category: .trackpad, gesture: "3-finger drag (free space)", action: "Select text / drag items", keywords: ["selection", "three finger drag", "BTT"]),
        .init(id: "tp-3f-lr", category: .trackpad, gesture: "3-finger swipe ←/→", action: "Forward / Back (off by default)", keywords: ["free space", "history", "page"]),
        .init(id: "tp-3f-up", category: .trackpad, gesture: "3-finger swipe ↑", action: "Maximize (off by default)", keywords: ["free space", "window"]),
        .init(id: "tp-3f-down", category: .trackpad, gesture: "3-finger swipe ↓", action: "Minimize (off by default)", keywords: ["free space", "window"]),
        .init(id: "tp-4f-lr", category: .trackpad, gesture: "4-finger swipe ←/→", action: "Previous / next tab (off by default)", keywords: ["free space", "tabs"]),
        .init(id: "tp-4f-up", category: .trackpad, gesture: "4-finger swipe ↑", action: "Mission Control (off by default)", keywords: ["free space", "spaces"]),
        .init(id: "tp-4f-down", category: .trackpad, gesture: "4-finger swipe ↓", action: "App Exposé (off by default)", keywords: ["free space", "expose"]),
        .init(id: "tp-4f-tap", category: .trackpad, gesture: "4-finger tap", action: "Spotlight (off by default)", keywords: ["free space", "search"]),
        .init(id: "tp-tiptap-l", category: .trackpad, gesture: "Hold 1 finger, tap left", action: "Previous tab (off by default)", keywords: ["free space", "tip tap", "tiptap", "tabs", "BTT"]),
        .init(id: "tp-tiptap-r", category: .trackpad, gesture: "Hold 1 finger, tap right", action: "Next tab (off by default)", keywords: ["free space", "tip tap", "tiptap", "tabs", "BTT"]),

        // Keyboard
        .init(id: "kb-lr", category: .keyboard, gesture: "⌃⌥ + ←/→", action: "Snap half; repeat cycles thirds", keywords: ["control", "option"]),
        .init(id: "kb-up", category: .keyboard, gesture: "⌃⌥ + ↑", action: "Maximize", keywords: []),
        .init(id: "kb-down", category: .keyboard, gesture: "⌃⌥ + ↓", action: "Almost-maximize", keywords: []),
        .init(id: "kb-ret", category: .keyboard, gesture: "⌃⌥ + ↩", action: "Large center", keywords: ["return", "enter"]),
        .init(id: "kb-disp", category: .keyboard, gesture: "⌃⌥⌘ + ←/→", action: "Move to adjacent display", keywords: ["monitor"]),

        // Modifier drag
        .init(id: "md-move", category: .modifierDrag, gesture: "⌥⌘ + drag", action: "Move window (anywhere)", keywords: ["option", "command"]),
        .init(id: "md-resize", category: .modifierDrag, gesture: "⌃⌘ + drag", action: "Resize from nearest edge/corner", keywords: ["control", "command"]),
    ]

    static func matches(_ entry: Entry, query: String) -> Bool {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return true }
        let hay = ([entry.gesture, entry.action, entry.category.rawValue] + entry.keywords)
            .joined(separator: " ")
            .lowercased()
        return q.split(separator: " ").allSatisfy { hay.contains($0) }
    }
}

// MARK: - Tutorial progress signals

enum TutorialSignal: String {
    case magicMouseClick
    case titlebarSnap
    case trackpadMiddleClick
}

extension Notification.Name {
    static let sanneTutorialSignal = Notification.Name("sanneTutorialSignal")
    static let sanneShowTutorial = Notification.Name("sanneShowTutorial")
    static let sanneShowCheatSheet = Notification.Name("sanneShowCheatSheet")
}

enum TutorialPrefs {
    private static let completedKey = "sanne.tutorialCompleted"

    static var completed: Bool {
        get { UserDefaults.standard.bool(forKey: completedKey) }
        set { UserDefaults.standard.set(newValue, forKey: completedKey) }
    }

    static func post(_ signal: TutorialSignal) {
        NotificationCenter.default.post(
            name: .sanneTutorialSignal,
            object: nil,
            userInfo: ["signal": signal.rawValue]
        )
    }
}
