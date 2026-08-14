import CoreGraphics
import Foundation

/// Double-tap-hold → drag (or a remapped hold action).
enum MMDragSession {
    static let doubleTapWindow: TimeInterval = 0.35
    static let dragHoldMin: TimeInterval = 0.15

    enum HoldTick {
        case none
        case beginDrag
        case fireRemap
        case cancel
    }

    static func shouldArmPending(
        snapshot: RuntimeSnapshot,
        blocked: Bool,
        lastLeftTap: TimeInterval?,
        now: TimeInterval
    ) -> Bool {
        guard snapshot.slotOn(GestureSlots.ID.mmDrag), !blocked, let last = lastLeftTap else {
            return false
        }
        return now - last < doubleTapWindow
    }

    static func tickHold(
        snapshot: RuntimeSnapshot,
        start: TimeInterval,
        now: TimeInterval
    ) -> HoldTick {
        guard now - start >= dragHoldMin else { return .none }
        guard snapshot.slotOn(GestureSlots.ID.mmDrag) else { return .cancel }
        if snapshot.actionId(for: GestureSlots.ID.mmDrag) == ActionCatalog.ID.drag {
            return .beginDrag
        }
        return .fireRemap
    }
}
