import Foundation

/// Tap vs scroll / page-swipe thresholds. Peak frame velocity is noisy — use net surface travel.
struct MMThresholds: Equatable {
    /// Shortest contact treated as a tap — anything quicker is a graze.
    let minDuration: TimeInterval
    /// Longest stationary contact still treated as a tap (not a rest).
    let maxDuration: TimeInterval
    /// Vertical finger slide on surface → scroll; kill mid-gesture / reject on lift.
    let surfaceScroll: Float
    /// Horizontal travel for 1-finger back/forward. Must beat a rest-drift.
    let pageSwipeMin: Float
    /// Cursor jump while finger down (pointer moved a lot → not a stationary tap).
    let cursorMove: CGFloat
    /// Multi-finger swipe travel (normalized). Also the line between a 3-finger swipe and
    /// a 3-finger middle-click.
    let swipeMin: Float

    init(sensitivity: Int) {
        let s = max(-2, min(2, sensitivity))
        minDuration = 0.035 - Double(s) * 0.005
        maxDuration = 0.42 + Double(s) * 0.06
        surfaceScroll = Float(0.070 - Double(s) * 0.010)
        pageSwipeMin = Float(0.20 - Double(s) * 0.020)
        cursorMove = CGFloat(18.0 + Double(s) * 4.0)
        swipeMin = Float(0.10 - Double(s) * 0.01)
    }
}

enum MMTapZone: Equatable {
    case left
    case right
    case dead
}

enum MMSwipeAxis: String, Equatable {
    case up, down, left, right
}

enum MMGeometry {
    /// 0.45–0.55 (with default split 0.5 and dead 0.10) is dead. Center taps must not become left.
    /// Physical right-hold + left-zone tap is the gaming-mode fire.
    static func gamingLeftTap(gamingMode: Bool, rightHeld: Bool, zone: MMTapZone) -> Bool {
        gamingMode && rightHeld && zone == .left
    }

    static func tapZone(x: Float, split: Float, deadZone: Float) -> MMTapZone {
        let leftMax = split - deadZone / 2
        let rightMin = split + deadZone / 2
        if x >= rightMin { return .right }
        if x <= leftMax { return .left }
        return .dead
    }

    /// Dominant axis of a multi-finger swipe. Ties go vertical (`ady >= adx`).
    /// Norm Y increases toward the top of the mouse, so `dy > 0` is an upward swipe.
    static func swipeAxis(dx: Float, dy: Float) -> MMSwipeAxis {
        if abs(dy) >= abs(dx) {
            return dy > 0 ? .up : .down
        }
        return dx < 0 ? .left : .right
    }
}
