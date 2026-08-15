import CoreGraphics
import Foundation

/// One-finger tap in a trackpad corner or along the top edge (BetterTouchTool region taps).
///
/// Only a short, still contact in a corner / top band fires. A second finger (tip-tap /
/// scroll) or any travel past the tap budget cancels. Off-by-default slots decide whether
/// the engine actually runs an action — this recognizer only classifies.
final class CornerTapRecognizer: @unchecked Sendable {
    enum Region: Equatable {
        case topLeft
        case topRight
        case bottomLeft
        case bottomRight
        case top
    }

    enum Outcome: Equatable {
        case none
        case tap(Region)
    }

    private var start: TouchPoint?
    private var startTime: TimeInterval?
    private var maxTravel: CGFloat = 0
    private var invalid = false
    private let lock = NSLock()

    private static let corner: CGFloat = 0.22
    private static let topBand: CGFloat = 0.80
    private static let maxDuration: TimeInterval = 0.35
    private static let minDuration: TimeInterval = 0.02
    private static let maxTravel: CGFloat = 0.04

    func process(frame: TouchFrame, sensitivity: Int) -> Outcome {
        lock.lock()
        defer { lock.unlock() }

        let live = frame.touches.filter { $0.phase != .ended && $0.phase != .cancelled }
        let tolerance = Self.tolerance(sensitivity: sensitivity)

        if live.isEmpty {
            let outcome = finishUnlocked(now: frame.timestamp, tolerance: tolerance)
            clearUnlocked()
            return outcome
        }
        if live.count != 1 {
            invalid = true
            return .none
        }
        if invalid { return .none }

        let touch = live[0]
        if start == nil {
            start = touch
            startTime = frame.timestamp
            maxTravel = 0
            return .none
        }
        if touch.id != start?.id {
            invalid = true
            return .none
        }
        maxTravel = max(maxTravel, Self.distance(start!.normalized, touch.normalized))
        return .none
    }

    func reset() {
        lock.lock()
        defer { lock.unlock() }
        clearUnlocked()
    }

    static func region(at point: CGPoint) -> Region? {
        let c = corner
        if point.x <= c, point.y >= 1 - c { return .topLeft }
        if point.x >= 1 - c, point.y >= 1 - c { return .topRight }
        if point.x <= c, point.y <= c { return .bottomLeft }
        if point.x >= 1 - c, point.y <= c { return .bottomRight }
        if point.y >= topBand { return .top }
        return nil
    }

    static func slotId(for region: Region) -> String {
        switch region {
        case .topLeft: return GestureSlots.ID.cornerTopLeft
        case .topRight: return GestureSlots.ID.cornerTopRight
        case .bottomLeft: return GestureSlots.ID.cornerBottomLeft
        case .bottomRight: return GestureSlots.ID.cornerBottomRight
        case .top: return GestureSlots.ID.tapTop
        }
    }

    // MARK: - Private

    private func finishUnlocked(now: TimeInterval, tolerance: Double) -> Outcome {
        guard !invalid, let start, let startTime else { return .none }
        let duration = now - startTime
        let travelLimit = Self.maxTravel * CGFloat(tolerance)
        let maxDur = Self.maxDuration * tolerance
        let minDur = Self.minDuration / tolerance
        guard duration >= minDur, duration <= maxDur, maxTravel <= travelLimit else {
            return .none
        }
        guard let region = Self.region(at: start.normalized) else { return .none }
        Log.debug(
            .gesture,
            "corner tap \(region) " +
            "xy=(\(String(format: "%.2f", start.normalized.x)),\(String(format: "%.2f", start.normalized.y)))"
        )
        return .tap(region)
    }

    private func clearUnlocked() {
        start = nil
        startTime = nil
        maxTravel = 0
        invalid = false
    }

    private static func tolerance(sensitivity: Int) -> Double {
        let s = max(-2, min(2, sensitivity))
        return 1.0 + Double(s) * 0.15
    }

    private static func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }
}
