import AppKit
import ApplicationServices

/// Magic Mouse top-edge window move. Thin wrapper over `WindowMover`.
@MainActor
final class TouchWindowMover {
    static let shared = TouchWindowMover()

    private init() {}

    var isActive: Bool { WindowMover.shared.isActive }

    @discardableResult
    func begin(kind: WindowMoverKind = .move, haptics: Bool = false) -> Bool {
        WindowMover.shared.begin(kind: kind, haptics: haptics)
    }

    func update() {
        WindowMover.shared.update()
    }

    func end() {
        WindowMover.shared.end()
    }
}
