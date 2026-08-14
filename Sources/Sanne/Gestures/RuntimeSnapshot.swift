import Foundation

/// Slim immutable view of enablement + tuning for the recognition path.
/// Rebuilt only when config or the frontmost app changes — never per touch frame.
struct RuntimeSnapshot: Equatable {
    struct Masters: Equatable {
        var magicMouse: Bool
        var titlebar: Bool
        var dock: Bool
        var menubar: Bool
        var keyboard: Bool
    }

    var enabled: Set<String>
    var actions: [String: String]
    var masters: Masters
    var paused: Bool
    var pauseMagicMouse: Bool
    var pauseWindowGestures: Bool
    var pauseKeyboard: Bool
    var pauseModifierDrag: Bool
    var frontmostBundleId: String?
    var multiClick: Bool
    var mmSensitivity: Int
    var leftRightSplit: Double
    var deadZone: Double
    var gamingMode: Bool
    var gap: Double
    var haptics: Bool
    var showPreview: Bool
    var hudEnabled: Bool
    var trackpadSensitivity: Int
    var cycleThirds: Bool

    static let empty = RuntimeSnapshot(
        enabled: [],
        actions: [:],
        masters: Masters(magicMouse: true, titlebar: true, dock: true, menubar: true, keyboard: true),
        paused: false,
        pauseMagicMouse: false,
        pauseWindowGestures: false,
        pauseKeyboard: false,
        pauseModifierDrag: false,
        frontmostBundleId: nil,
        multiClick: true,
        mmSensitivity: 0,
        leftRightSplit: 0.5,
        deadZone: 0.08,
        gamingMode: false,
        gap: 0,
        haptics: true,
        showPreview: true,
        hudEnabled: true,
        trackpadSensitivity: 0,
        cycleThirds: true
    )

    func slotOn(_ id: String) -> Bool { enabled.contains(id) }

    func actionId(for slotId: String) -> String? { actions[slotId] }

    /// Frontmost-app remaps apply on the next gesture after a switch, not mid-contact.
    static func build(config: SanneConfig, frontmostBundleId: String?) -> RuntimeSnapshot {
        var enabled = Set<String>()
        var actions: [String: String] = [:]
        enabled.reserveCapacity(GestureSlots.all.count)
        actions.reserveCapacity(GestureSlots.all.count)
        for slot in GestureSlots.all {
            guard let resolved = BindingResolver.resolve(
                slotId: slot.id,
                config: config,
                frontmostBundleId: frontmostBundleId
            ) else { continue }
            actions[slot.id] = resolved.actionId
            if resolved.enabled { enabled.insert(slot.id) }
        }
        return RuntimeSnapshot(
            enabled: enabled,
            actions: actions,
            masters: Masters(
                magicMouse: config.magicMouseTaps.enabled,
                titlebar: config.titlebarGestures.enabled,
                dock: config.dockGestures.enabled,
                menubar: config.menubarGestures.enabled,
                keyboard: config.keyboard.enabled
            ),
            paused: config.paused,
            pauseMagicMouse: config.paused || config.pausesMagicMouse(forFrontmostBundleId: frontmostBundleId),
            pauseWindowGestures: config.paused || config.pausesWindowGestures(forFrontmostBundleId: frontmostBundleId),
            pauseKeyboard: config.paused || config.pausesKeyboard(forFrontmostBundleId: frontmostBundleId),
            pauseModifierDrag: config.paused || config.pausesModifierDrag(forFrontmostBundleId: frontmostBundleId),
            frontmostBundleId: frontmostBundleId,
            multiClick: config.magicMouseTaps.multiClick,
            mmSensitivity: config.magicMouseTaps.sensitivity,
            leftRightSplit: config.magicMouseTaps.leftRightSplit,
            deadZone: config.magicMouseTaps.deadZone,
            gamingMode: config.magicMouseTaps.gamingMode,
            gap: config.window.gap,
            haptics: config.window.haptics,
            showPreview: config.window.showPreview,
            hudEnabled: config.hud.enabled,
            trackpadSensitivity: config.trackpad.sensitivity,
            cycleThirds: config.keyboard.cycleThirds
        )
    }
}

/// Single owner of the live `RuntimeSnapshot`. Recognition threads copy this under a lock.
final class RuntimeSnapshotStore: @unchecked Sendable {
    static let shared = RuntimeSnapshotStore()

    private let lock = NSLock()
    private var current = RuntimeSnapshot.empty

    private init() {}

    var snapshot: RuntimeSnapshot {
        lock.lock()
        defer { lock.unlock() }
        return current
    }

    func rebuild(config: SanneConfig, frontmostBundleId: String?) {
        let next = RuntimeSnapshot.build(config: config, frontmostBundleId: frontmostBundleId)
        lock.lock()
        current = next
        lock.unlock()
        NotificationCenter.default.post(name: .sanneRuntimeSnapshotDidChange, object: nil)
    }
}

extension Notification.Name {
    static let sanneRuntimeSnapshotDidChange = Notification.Name("sanneRuntimeSnapshotDidChange")
}
