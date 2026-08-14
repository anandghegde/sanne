import Foundation

/// Cross-page Settings index (UX-10). Slot rows, page titles, and the labeled toggles
/// that live outside the gesture list.
enum SettingsSearch {
    struct Hit: Identifiable, Hashable {
        let id: String
        let title: String
        let subtitle: String
        let route: String
        let slotId: String?
        let terms: [String]

        func matches(_ query: String) -> Bool {
            let words = query.split(whereSeparator: \.isWhitespace).map { $0.lowercased() }
            guard !words.isEmpty else { return false }
            let hay = ([title, subtitle] + terms).joined(separator: " ").lowercased()
            return words.allSatisfy { hay.contains($0) }
        }
    }

    static func hits(query: String) -> [Hit] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return [] }
        return catalog.filter { $0.matches(q) }
    }

    static let catalog: [Hit] = pageHits + toggleHits + slotHits

    private static let pageHits: [Hit] = [
        Hit(id: "page.home", title: "Home", subtitle: "Status and pause",
            route: PreferencesRoute.home, slotId: nil, terms: ["status", "pause"]),
        Hit(id: "page.magicMouse", title: "Magic Mouse", subtitle: "Taps and surface gestures",
            route: PreferencesRoute.magicMouse, slotId: nil, terms: ["mouse", "tap"]),
        Hit(id: "page.trackpad", title: "Trackpad", subtitle: "Free-space taps and swipes",
            route: PreferencesRoute.trackpad, slotId: nil, terms: ["pad"]),
        Hit(id: "page.windows", title: "Windows", subtitle: "Titlebar, Dock, and menu bar",
            route: PreferencesRoute.windows, slotId: nil, terms: ["titlebar", "dock", "menubar", "snap"]),
        Hit(id: "page.keyboard", title: "Keyboard", subtitle: "Control-Option snap chords",
            route: PreferencesRoute.keyboard, slotId: nil, terms: ["hotkey", "chord"]),
        Hit(id: "page.apps", title: "Apps", subtitle: "Pause and remaps per app",
            route: PreferencesRoute.apps, slotId: nil, terms: ["override", "pause"]),
        Hit(id: "page.presets", title: "Presets", subtitle: "Standard, Minimal, export, import",
            route: PreferencesRoute.presets, slotId: nil, terms: ["minimal", "standard", "reset", "backup"]),
        Hit(id: "page.advanced", title: "Advanced", subtitle: "About, bindings, debug",
            route: PreferencesRoute.about, slotId: nil, terms: ["about", "debug"]),
    ]

    private static let toggleHits: [Hit] = [
        Hit(id: "toggle.launchAtLogin", title: "Launch at login", subtitle: "Advanced",
            route: PreferencesRoute.about, slotId: nil,
            terms: ["login", "startup", "open at login"]),
        Hit(id: "toggle.haptics", title: "Haptic feedback", subtitle: "Advanced",
            route: PreferencesRoute.about, slotId: nil,
            terms: ["haptics", "haptic", "vibrate"]),
        Hit(id: "toggle.hud", title: "Action name overlay", subtitle: "Advanced",
            route: PreferencesRoute.about, slotId: nil,
            terms: ["hud", "overlay", "action name"]),
        Hit(id: "toggle.gap", title: "Gap", subtitle: "Windows · Layout",
            route: PreferencesRoute.windows, slotId: nil,
            terms: ["gap", "padding", "margin", "spacing"]),
        Hit(id: "toggle.preview", title: "Snap preview overlay", subtitle: "Windows · Layout",
            route: PreferencesRoute.windows, slotId: nil,
            terms: ["preview", "ghost"]),
        Hit(id: "toggle.pause", title: "Pause all gestures", subtitle: "Home",
            route: PreferencesRoute.home, slotId: nil,
            terms: ["pause", "disable"]),
        Hit(id: "toggle.mmMaster", title: "Enable Magic Mouse taps", subtitle: "Magic Mouse",
            route: PreferencesRoute.magicMouse, slotId: nil,
            terms: ["master", "taps"]),
        Hit(id: "toggle.tbMaster", title: "Titlebar window gestures", subtitle: "Windows",
            route: PreferencesRoute.windows, slotId: nil,
            terms: ["titlebar", "master"]),
        Hit(id: "toggle.dockMaster", title: "Dock gestures", subtitle: "Windows",
            route: PreferencesRoute.windows, slotId: nil, terms: ["dock"]),
        Hit(id: "toggle.mbMaster", title: "Menubar gestures", subtitle: "Windows",
            route: PreferencesRoute.windows, slotId: nil, terms: ["menubar", "menu bar"]),
        Hit(id: "toggle.keyboardMaster", title: "Enable keyboard snap", subtitle: "Keyboard",
            route: PreferencesRoute.keyboard, slotId: nil, terms: ["keyboard", "input monitoring"]),
        Hit(id: "toggle.modifierDrag", title: "Enable modifier drag", subtitle: "Windows",
            route: PreferencesRoute.windows, slotId: nil, terms: ["modifier", "option", "command", "resize", "move"]),
        Hit(id: "toggle.cycleThirds", title: "Cycle thirds on long swipe", subtitle: "Windows · Layout",
            route: PreferencesRoute.windows, slotId: nil, terms: ["thirds", "cycle", "long swipe"]),
        Hit(id: "toggle.gamingMode", title: "Gaming mode", subtitle: "Magic Mouse",
            route: PreferencesRoute.magicMouse, slotId: nil, terms: ["gaming", "right hold", "fps"]),
        Hit(id: "toggle.windowToSpace", title: "Move window to Space", subtitle: "Advanced · Experimental",
            route: PreferencesRoute.about, slotId: nil, terms: ["spaces", "experimental", "desktop"]),
        Hit(id: "toggle.updates", title: "Check for Updates", subtitle: "Advanced",
            route: PreferencesRoute.about, slotId: nil, terms: ["update", "sparkle", "github", "release"]),
        Hit(id: "toggle.bindings", title: "All bindings", subtitle: "Advanced",
            route: PreferencesRoute.bindings, slotId: nil, terms: ["remap", "catalog"]),
        Hit(id: "toggle.debug", title: "Debug Log", subtitle: "Advanced",
            route: PreferencesRoute.debug, slotId: nil, terms: ["log", "debug"]),
    ]

    private static let slotHits: [Hit] = GestureSlots.all.map { slot in
        Hit(
            id: "slot.\(slot.id)",
            title: slot.title,
            subtitle: "\(slot.group.rawValue) · \(slot.defaultActionTitle)",
            route: PreferencesRoute.route(for: slot.group),
            slotId: slot.id,
            terms: [slot.detail, slot.id, slot.defaultActionTitle, slot.group.rawValue]
        )
    }
}
