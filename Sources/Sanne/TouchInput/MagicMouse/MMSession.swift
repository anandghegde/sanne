import CoreGraphics
import Foundation

/// All per-contact Magic Mouse session fields. One `reset` / `kill`.
struct MMSession {
    enum DragPhase: String {
        case none
        case pendingHold
        case active
    }

    enum WindowMovePhase: String {
        case none
        case active
    }

    enum KillAction {
        case none
        case endDrag
        case endWindowMove
    }

    var activeTouchID: Int32 = -1
    var touchStartX: Float = 0
    var touchStartY: Float = 0
    var touchStartTime: TimeInterval?
    var touchStartCursor: CGPoint = .zero
    var maxSurfaceMove: Float = 0
    var maxVelocity: Float = 0
    var maxTouchSize: Float = 0
    var netDx: Float = 0
    var netDy: Float = 0
    var pageSwipeActive = false
    var multiFinger = false
    var multiFingerCount = 0
    var multiSwipeFingers = 0
    var multiStartCentroid: CGPoint = .zero
    var multiLastCentroid: CGPoint = .zero
    var multiMaxTravel: Float = 0
    var suppressUntilLift = false
    var suppressedForScroll = false
    var lastMouseTouchTime: TimeInterval?
    var dragPhase: DragPhase = .none
    var lastLeftTapTime: TimeInterval?
    var lastDragPostedCursor: CGPoint = .zero
    var lastClickTime: TimeInterval?
    var lastClickButton: ClickButton?
    var lastClickCount: Int = 0
    var lastClickCursor: CGPoint = .zero
    var lastTwoFingerTapTime: TimeInterval?
    var windowMovePhase: WindowMovePhase = .none
    var windowMoveKind: WindowMoverKind = .move
    var multiStartY: Float = 0
    var physicalRightHeld = false

    mutating func reset(clearSuppress: Bool) {
        activeTouchID = -1
        multiFinger = false
        multiFingerCount = 0
        multiSwipeFingers = 0
        dragPhase = .none
        windowMovePhase = .none
        windowMoveKind = .move
        touchStartX = 0
        touchStartY = 0
        touchStartTime = nil
        touchStartCursor = .zero
        maxSurfaceMove = 0
        maxVelocity = 0
        maxTouchSize = 0
        netDx = 0
        netDy = 0
        pageSwipeActive = false
        multiMaxTravel = 0
        multiStartY = 0
        multiStartCentroid = .zero
        multiLastCentroid = .zero
        if clearSuppress {
            suppressUntilLift = false
        }
    }

    mutating func kill(reason: String) -> KillAction {
        let action: KillAction
        if dragPhase == .active {
            action = .endDrag
        } else if windowMovePhase == .active {
            action = .endWindowMove
        } else {
            reset(clearSuppress: false)
            action = .none
        }
        suppressUntilLift = true
        suppressedForScroll = (reason == "surface")
        return action
    }
}
