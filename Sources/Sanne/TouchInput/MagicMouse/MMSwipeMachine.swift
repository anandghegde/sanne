import Foundation

/// Multi-finger swipe slot mapping and the finger-freeze latch.
enum MMSwipeMachine {
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
}
