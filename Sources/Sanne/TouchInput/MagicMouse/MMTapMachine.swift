import CoreGraphics
import Foundation

/// Left / right / dead-zone tap classification and multi-click counting.
enum MMTapMachine {
    static let minTouchSize: Float = 0.08
    static let multiClickWindow: TimeInterval = 0.45
    static let multiClickMaxCursorDist: CGFloat = 6

    enum LiftDecision: Equatable {
        case reject(String)
        case deadZone
        case click(ClickButton)
        case pageSwipe(dx: Float)
    }

    static func decideLift(
        snapshot: RuntimeSnapshot,
        duration: TimeInterval,
        surfaceMoved: Float,
        peakVel: Float,
        peakSize: Float,
        cursorDist: CGFloat,
        startX: Float,
        dx: Float,
        dy: Float,
        tapBlocked: Bool,
        physicalOwns: Bool,
        rightHeld: Bool,
        thr: MMThresholds
    ) -> LiftDecision {
        if MMSwipeMachine.shouldCommitPageSwipe(
            dx: dx,
            dy: dy,
            cursorDist: cursorDist,
            physicalOwns: physicalOwns,
            slotsEnabled: MMSwipeMachine.pageSlotsOn(snapshot),
            thr: thr
        ) {
            return .pageSwipe(dx: dx)
        }
        if tapBlocked {
            return .reject("scroll-session lock")
        }
        let zone = MMGeometry.tapZone(
            x: startX,
            split: Float(snapshot.leftRightSplit),
            deadZone: Float(snapshot.deadZone)
        )
        let gamingLeft = MMGeometry.gamingLeftTap(
            gamingMode: snapshot.gamingMode,
            rightHeld: rightHeld,
            zone: zone
        )
        if physicalOwns, !gamingLeft {
            return .reject("physical click owns contact")
        }
        if surfaceMoved >= thr.surfaceScroll {
            return .reject("surface")
        }
        if duration >= thr.maxDuration {
            return .reject("duration rest")
        }
        if duration < thr.minDuration {
            return .reject("duration graze")
        }
        if peakSize > 0, peakSize < minTouchSize {
            return .reject("size graze")
        }
        if cursorDist >= thr.cursorMove {
            return .reject("cursor")
        }
        switch zone {
        case .right:
            return snapshot.slotOn(GestureSlots.ID.mmRight) ? .click(.right) : .reject("right off")
        case .left:
            return snapshot.slotOn(GestureSlots.ID.mmLeft) ? .click(.left) : .reject("left off")
        case .dead:
            return .deadZone
        }
    }

    static func nextClickCount(
        button: ClickButton,
        cursor: CGPoint,
        multiClick: Bool,
        lastTime: TimeInterval?,
        lastButton: ClickButton?,
        lastCount: Int,
        lastCursor: CGPoint,
        now: TimeInterval
    ) -> Int {
        guard multiClick else { return 1 }
        if let lastT = lastTime,
           let lastB = lastButton,
           lastB == button,
           now - lastT < multiClickWindow,
           hypot(cursor.x - lastCursor.x, cursor.y - lastCursor.y) < multiClickMaxCursorDist
        {
            return min(3, lastCount + 1)
        }
        return 1
    }
}
