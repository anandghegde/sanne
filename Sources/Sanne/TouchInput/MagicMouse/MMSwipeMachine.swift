import CoreGraphics
import Foundation

/// Multi-finger swipe slot mapping, the finger-freeze latch, and 1-finger page-swipe commit.
enum MMSwipeMachine {
    /// Horizontal must beat vertical by this ratio so a diagonal scroll is not a page swipe.
    static let pageSwipeAxis: Float = 1.6

    /// Credit a new contact to the swipe only while the chord is still settling.
    static func creditFingers(current: Int, reported: Int, maxTravel: Float, swipeMin: Float) -> Int {
        if maxTravel <= swipeMin * 0.5 {
            return max(current, reported)
        }
        return current
    }

    static func slotId(fingers: Int, axis: MMSwipeAxis) -> String {
        if fingers >= 3 {
            switch axis {
            case .up: return GestureSlots.ID.mm3fSwipeUp
            case .down: return GestureSlots.ID.mm3fSwipeDown
            case .left: return GestureSlots.ID.mm3fSwipeLeft
            case .right: return GestureSlots.ID.mm3fSwipeRight
            }
        }
        switch axis {
        case .up: return GestureSlots.ID.mm2fSwipeUp
        case .down: return GestureSlots.ID.mm2fSwipeDown
        case .left: return GestureSlots.ID.mm2fSwipeLeft
        case .right: return GestureSlots.ID.mm2fSwipeRight
        }
    }

    static func enabledSlot(fingers: Int, axis: MMSwipeAxis, snapshot: RuntimeSnapshot) -> String? {
        let id = slotId(fingers: fingers, axis: axis)
        return snapshot.slotOn(id) ? id : nil
    }

    static func pageSlotsOn(_ snapshot: RuntimeSnapshot) -> Bool {
        snapshot.slotOn(GestureSlots.ID.mm1fSwipeLeft) || snapshot.slotOn(GestureSlots.ID.mm1fSwipeRight)
    }

    /// Clearly horizontal — not a diagonal scroll or a sloppy tap.
    static func isHorizontalPageSwipe(dx: Float, dy: Float) -> Bool {
        abs(dx) > abs(dy) * pageSwipeAxis
    }

    /// Latch while a swipe is forming so the contact cannot become a tap.
    static func isPageSwipeCandidate(dx: Float, dy: Float, slotsEnabled: Bool) -> Bool {
        slotsEnabled && isHorizontalPageSwipe(dx: dx, dy: dy)
    }

    /// Commit only a deliberate finger slide on a parked mouse.
    static func shouldCommitPageSwipe(
        dx: Float,
        dy: Float,
        cursorDist: CGFloat,
        physicalOwns: Bool,
        slotsEnabled: Bool,
        thr: MMThresholds
    ) -> Bool {
        guard slotsEnabled, !physicalOwns else { return false }
        guard cursorDist < thr.cursorMove else { return false }
        guard abs(dx) >= thr.pageSwipeMin else { return false }
        return isHorizontalPageSwipe(dx: dx, dy: dy)
    }
}
