import Foundation
import CoreGraphics

/// Multi-finger swipe / pinch state machine for zone gestures (titlebar / Dock / menubar)
/// and free-space 3/4-finger swipes.
final class SwipePinchRecognizer: @unchecked Sendable {
    private struct Active {
        var startCentroid: CGPoint
        var startDistance: CGFloat
        var lastCentroid: CGPoint
        var lastDistance: CGFloat
        /// Peak simultaneous contacts. Frozen once the chord starts travelling so a finger
        /// lifting mid-swipe (4→3) cannot reclassify the gesture into another slot.
        var fingerCount: Int
        var fingerCountLocked: Bool
        var zone: CursorZone
        var emittedPreview: WindowLayout?
    }

    private var active: Active?
    private let lock = NSLock()

    struct Outcome {
        var gesture: RecognizedGesture
        var isPreview: Bool
        var isCommit: Bool
        /// Normalized swipe distance (0…~1); used for short vs long swipe.
        var magnitude: CGFloat = 0
    }

    /// Sensitivity scales thresholds (config -2...2 → multiplier).
    func process(frame: TouchFrame, zone: CursorZone, sensitivity: Int) -> Outcome? {
        let scale = 1.0 - Double(sensitivity) * 0.08
        let swipeMin = 0.08 * scale
        let pinchMin = 0.12 * scale

        let activeTouches = frame.touches.filter { $0.phase != .ended && $0.phase != .cancelled }
        lock.lock()
        defer { lock.unlock() }

        if activeTouches.count >= 2 {
            let centroid = Self.centroid(activeTouches)
            let distance = Self.span(activeTouches)

            if active == nil {
                active = Active(
                    startCentroid: centroid,
                    startDistance: distance,
                    lastCentroid: centroid,
                    lastDistance: distance,
                    fingerCount: activeTouches.count,
                    fingerCountLocked: false,
                    zone: zone,
                    emittedPreview: nil
                )
                return nil
            }

            guard var a = active else { return nil }
            a.lastCentroid = centroid
            a.lastDistance = distance
            if !a.fingerCountLocked {
                a.fingerCount = max(a.fingerCount, activeTouches.count)
            }

            let dx = centroid.x - a.startCentroid.x
            let dy = centroid.y - a.startCentroid.y
            let dist = hypot(dx, dy)
            // Fingers land a few frames apart, so keep taking the max until the chord is
            // clearly travelling — after that the count is final.
            if !a.fingerCountLocked, dist > swipeMin * 0.5 {
                a.fingerCountLocked = true
            }
            active = a

            let scaleDelta = distance - a.startDistance
            let fingers = a.fingerCount

            // Prefer pinch if scale change dominates (2-finger zone gesture only; 3F is the
            // display throw, and free space never claims pinch — macOS owns zoom).
            if Self.emitsPinch(zone: a.zone, fingers: fingers),
               abs(scaleDelta) > pinchMin && abs(scaleDelta) > dist
            {
                let inward = scaleDelta < 0
                return Outcome(gesture: .pinch(inward: inward), isPreview: true, isCommit: false, magnitude: abs(scaleDelta))
            }

            if dist > swipeMin, Self.emitsSwipe(zone: a.zone, fingers: fingers) {
                let dir = Self.direction(dx: dx, dy: dy, allowDiagonal: Self.allowsDiagonal(a.zone))
                return Outcome(
                    gesture: .swipe(fingers: fingers, direction: dir),
                    isPreview: true,
                    isCommit: false,
                    magnitude: dist
                )
            }
            return nil
        }

        // Fingers lifted — commit if we had an active gesture past threshold
        if let a = active {
            let dx = a.lastCentroid.x - a.startCentroid.x
            let dy = a.lastCentroid.y - a.startCentroid.y
            let dist = hypot(dx, dy)
            let endDistance = a.lastDistance
            let scaleDelta = endDistance - a.startDistance
            let fingers = a.fingerCount
            active = nil

            if Self.emitsPinch(zone: a.zone, fingers: fingers),
               abs(scaleDelta) > pinchMin && abs(scaleDelta) > dist * 0.5
            {
                return Outcome(
                    gesture: .pinch(inward: scaleDelta < 0),
                    isPreview: false,
                    isCommit: true,
                    magnitude: abs(scaleDelta)
                )
            }
            if dist > swipeMin, Self.emitsSwipe(zone: a.zone, fingers: fingers) {
                let dir = Self.direction(dx: dx, dy: dy, allowDiagonal: Self.allowsDiagonal(a.zone))
                return Outcome(
                    gesture: .swipe(fingers: fingers, direction: dir),
                    isPreview: false,
                    isCommit: true,
                    magnitude: dist
                )
            }
        }
        return nil
    }

    // MARK: - Zone rules

    /// Free space belongs to macOS at 1–2 fingers (scroll / zoom); Sanne only claims
    /// 3+ finger chords there. Window zones keep accepting 2-finger swipes.
    private static func emitsSwipe(zone: CursorZone, fingers: Int) -> Bool {
        zone == .free ? fingers >= 3 : true
    }

    /// Pinch is a 2-finger window-zone gesture only.
    private static func emitsPinch(zone: CursorZone, fingers: Int) -> Bool {
        zone != .free && fingers < 3
    }

    /// Only window zones map diagonals (titlebar quarters). Free space collapses to the
    /// dominant axis so a slightly angled 4-finger swipe still fires L/R/U/D.
    private static func allowsDiagonal(_ zone: CursorZone) -> Bool {
        zone != .free
    }

    func reset() {
        lock.lock()
        active = nil
        lock.unlock()
    }

    private static func centroid(_ touches: [TouchPoint]) -> CGPoint {
        let n = CGFloat(touches.count)
        let x = touches.reduce(0) { $0 + $1.normalized.x } / n
        let y = touches.reduce(0) { $0 + $1.normalized.y } / n
        return CGPoint(x: x, y: y)
    }

    private static func span(_ touches: [TouchPoint]) -> CGFloat {
        guard touches.count >= 2 else { return 0 }
        var maxD: CGFloat = 0
        for i in 0..<touches.count {
            for j in (i + 1)..<touches.count {
                let d = hypot(
                    touches[i].normalized.x - touches[j].normalized.x,
                    touches[i].normalized.y - touches[j].normalized.y
                )
                maxD = max(maxD, d)
            }
        }
        return maxD
    }

    private static func direction(dx: CGFloat, dy: CGFloat, allowDiagonal: Bool) -> SwipeDirection {
        let adx = abs(dx)
        let ady = abs(dy)
        // Diagonal if both significant
        if allowDiagonal, adx > 0.04 && ady > 0.04 {
            if dy > 0 && dx < 0 { return .upLeft }
            if dy > 0 && dx > 0 { return .upRight }
            if dy < 0 && dx < 0 { return .downLeft }
            return .downRight
        }
        if adx >= ady {
            return dx < 0 ? .left : .right
        }
        return dy > 0 ? .up : .down
    }
}
