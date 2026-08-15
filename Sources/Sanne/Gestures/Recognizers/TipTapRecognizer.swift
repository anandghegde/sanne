import CoreGraphics
import Foundation

/// Tip-tap: rest one or two fingers and tap another to the left, right, or middle
/// (BetterTouchTool's name). Used on the free-space trackpad and on the Magic Mouse.
///
/// `anchorCount` 1 is the classic rest-one-tap-beside. `anchorCount` 2 is BTT's
/// three-finger tip-tap (rest two, tap a third). Both require the anchors to sit still
/// before the tapper lands, so a simultaneous chord (scroll, 3-finger tap) never arms.
final class TipTapRecognizer: @unchecked Sendable {
    enum Side: Equatable {
        case left
        case right
        case middle

        var label: String {
            switch self {
            case .left: return "left"
            case .right: return "right"
            case .middle: return "middle"
            }
        }
    }

    enum Outcome: Equatable {
        case none
        /// A finger tapped to this side of the resting anchor(s).
        case tipTap(Side)
    }

    private enum Phase: Equatable {
        case idle
        case arming
        case armed
        case tapping
        case invalid
    }

    /// 1 = rest one, tap a second. 2 = rest two, tap a third.
    private let anchorCount: Int
    private var phase: Phase = .idle
    /// Snapshots taken at each anchor's landing, so drift measures from that point.
    private var anchors: [TouchPoint] = []
    private var anchorDown: TimeInterval?
    private var tapper: TouchPoint?
    private var tapperDown: TimeInterval?
    private var tapperTravel: CGFloat = 0
    private let lock = NSLock()

    /// How long the resting finger(s) must sit still before they count as anchors.
    ///
    /// Deliberately *not* scaled by sensitivity: this threshold encodes intent — below it
    /// extra contacts are simply the start of a scroll / tap chord — rather than precision.
    private static let minAnchorHold: TimeInterval = 0.15
    private static let maxAnchorDrift: CGFloat = 0.03
    private static let maxTapDuration: TimeInterval = 0.25
    private static let maxTapTravel: CGFloat = 0.04
    /// Horizontal gap that separates left / right from middle.
    private static let minSeparation: CGFloat = 0.04

    init(anchorCount: Int = 1) {
        self.anchorCount = max(1, min(2, anchorCount))
    }

    func process(frame: TouchFrame, sensitivity: Int) -> Outcome {
        lock.lock()
        defer { lock.unlock() }

        let live = frame.touches.filter { $0.phase != .ended && $0.phase != .cancelled }
        let maxLive = anchorCount + 1

        if live.isEmpty {
            clearUnlocked()
            return .none
        }
        if phase == .invalid { return .none }
        if live.count > maxLive {
            phase = .invalid
            return .none
        }

        let tolerance = Self.tolerance(sensitivity: sensitivity)

        switch phase {
        case .invalid:
            return .none

        case .idle:
            guard live.count <= anchorCount else {
                phase = .invalid
                return .none
            }
            anchors = live
            anchorDown = frame.timestamp
            phase = .arming
            return .none

        case .arming:
            guard anchorsRestingUnlocked(in: live, tolerance: tolerance),
                  let anchorDown
            else { return .none }
            if live.count > anchorCount {
                phase = .invalid
                return .none
            }
            if live.count > anchors.count {
                // Another intended anchor landed; the hold starts once the last one is down.
                anchors = live
                self.anchorDown = frame.timestamp
                return .none
            }
            if live.count < anchors.count {
                phase = .invalid
                return .none
            }
            if anchors.count == anchorCount, frame.timestamp - anchorDown >= Self.minAnchorHold {
                phase = .armed
            }
            return .none

        case .armed:
            guard anchorsRestingUnlocked(in: live, tolerance: tolerance) else { return .none }
            guard live.count == maxLive,
                  let second = live.first(where: { touch in anchors.allSatisfy { $0.id != touch.id } })
            else { return .none }
            startCandidateUnlocked(second, at: frame.timestamp)
            return .none

        case .tapping:
            guard anchorsRestingUnlocked(in: live, tolerance: tolerance),
                  let tapper, let tapperDown
            else { return .none }

            if let current = live.first(where: { $0.id == tapper.id }) {
                tapperTravel = max(
                    tapperTravel,
                    Self.distance(tapper.normalized, current.normalized)
                )
                let tooSlow = frame.timestamp - tapperDown > Self.maxTapDuration * tolerance
                let tooFar = tapperTravel > Self.maxTapTravel * CGFloat(tolerance)
                if tooSlow || tooFar {
                    Log.debug(.gesture, "tip-tap candidate dropped — tapper held or slid")
                    clearTapperUnlocked()
                    phase = .armed
                }
                return .none
            }

            let anchorIDs = Set(anchors.map(\.id))
            if let replacement = live.first(where: { !anchorIDs.contains($0.id) }) {
                startCandidateUnlocked(replacement, at: frame.timestamp)
                Log.debug(.gesture, "tip-tap tapper id changed — restarting candidate")
                return .none
            }

            let duration = frame.timestamp - tapperDown
            let travel = tapperTravel
            let originX = anchors.map(\.normalized.x).reduce(0, +) / CGFloat(anchors.count)
            let offset = tapper.normalized.x - originX
            clearTapperUnlocked()
            phase = .armed

            guard duration <= Self.maxTapDuration * tolerance,
                  travel <= Self.maxTapTravel * CGFloat(tolerance)
            else {
                Log.debug(
                    .gesture,
                    "tip-tap rejected — dur=\(String(format: "%.3f", duration))s " +
                    "travel=\(String(format: "%.3f", travel))"
                )
                return .none
            }

            let side: Side
            if abs(offset) < Self.minSeparation / CGFloat(tolerance) {
                side = .middle
            } else {
                side = offset < 0 ? .left : .right
            }
            Log.debug(
                .gesture,
                "tip-tap \(side.label) " +
                "dx=\(String(format: "%.3f", offset)) dur=\(String(format: "%.3f", duration))s"
            )
            return .tipTap(side)
        }
    }

    func reset() {
        lock.lock()
        defer { lock.unlock() }
        clearUnlocked()
    }

    // MARK: - Private

    /// True while every stored anchor is still down and inside its drift budget.
    /// Latches invalid otherwise — a travelling anchor is a scroll, and a lifted
    /// anchor cannot outlive the tap.
    private func anchorsRestingUnlocked(in live: [TouchPoint], tolerance: Double) -> Bool {
        let limit = Self.maxAnchorDrift * CGFloat(tolerance)
        for anchor in anchors {
            guard let current = live.first(where: { $0.id == anchor.id }),
                  Self.distance(anchor.normalized, current.normalized) <= limit
            else {
                phase = .invalid
                return false
            }
        }
        return !anchors.isEmpty
    }

    private func startCandidateUnlocked(_ touch: TouchPoint, at time: TimeInterval) {
        tapper = touch
        tapperDown = time
        tapperTravel = 0
        phase = .tapping
    }

    private func clearTapperUnlocked() {
        tapper = nil
        tapperDown = nil
        tapperTravel = 0
    }

    private func clearUnlocked() {
        phase = .idle
        anchors = []
        anchorDown = nil
        clearTapperUnlocked()
    }

    private static func tolerance(sensitivity: Int) -> Double {
        let s = max(-2, min(2, sensitivity))
        return 1.0 + Double(s) * 0.15
    }

    private static func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }
}
