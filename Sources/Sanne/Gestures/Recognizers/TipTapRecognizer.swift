import CoreGraphics
import Foundation

/// Free-space tip-tap: rest one finger on the pad and tap a second finger to its left or
/// right (BetterTouchTool calls this a "tip tap").
///
/// Almost no travel, and macOS ships no equivalent gesture — so unlike the free-space
/// 3/4-finger swipes this never races a system handler and needs no System Settings changes.
///
/// Exclusivity with Sanne's other free-space gestures is structural rather than
/// threshold-tuned: a tip-tap only ever exists at one or two contacts, while 3-finger drag,
/// the free-space swipes and the 3/4-finger taps all require a 3+ chord.
final class TipTapRecognizer: @unchecked Sendable {
    enum Side: Equatable {
        case left
        case right
    }

    enum Outcome: Equatable {
        case none
        /// A second finger tapped to this side of the resting anchor finger.
        case tipTap(Side)
    }

    private enum Phase: Equatable {
        /// Nothing tracked yet.
        case idle
        /// One contact down, not yet held long enough to count as an anchor.
        case arming
        /// Anchor confirmed — held past `minAnchorHold`, still inside `maxAnchorDrift`.
        case armed
        /// Anchor plus a candidate tapping finger.
        case tapping
        /// This session can no longer produce a tip-tap; waits for every finger to lift.
        case invalid
    }

    private var phase: Phase = .idle
    /// Snapshots taken at touch-down, so drift and travel measure from the landing point.
    private var anchor: TouchPoint?
    private var anchorDown: TimeInterval?
    private var tapper: TouchPoint?
    private var tapperDown: TimeInterval?
    private var tapperTravel: CGFloat = 0
    private let lock = NSLock()

    /// How long the resting finger must sit still before it counts as an anchor.
    ///
    /// Deliberately *not* scaled by sensitivity: this threshold encodes intent — below it two
    /// contacts are simply the start of a scroll chord — rather than precision, which is what
    /// the sensitivity slider tunes.
    private static let minAnchorHold: TimeInterval = 0.15
    /// Normalized travel that disqualifies the anchor (it is scrolling, not resting).
    private static let maxAnchorDrift: CGFloat = 0.03
    /// Longer than this and the second finger is a hold, not a tap.
    private static let maxTapDuration: TimeInterval = 0.25
    /// Normalized travel allowed for the tapping finger.
    private static let maxTapTravel: CGFloat = 0.04
    /// Minimum horizontal gap between anchor and tap; below it the side is a coin flip.
    private static let minSeparation: CGFloat = 0.04

    func process(frame: TouchFrame, sensitivity: Int) -> Outcome {
        lock.lock()
        defer { lock.unlock() }

        let live = frame.touches.filter { $0.phase != .ended && $0.phase != .cancelled }

        // An empty pad always ends the session — including an invalid one, which is how a
        // scrolling session becomes eligible for tip-taps again.
        if live.isEmpty {
            clearUnlocked()
            return .none
        }
        if phase == .invalid { return .none }
        // 3+ contacts belong to 3-finger drag / free-space swipes / multi-finger taps.
        if live.count > 2 {
            phase = .invalid
            return .none
        }

        let tolerance = Self.tolerance(sensitivity: sensitivity)

        switch phase {
        case .invalid:
            return .none

        case .idle:
            guard live.count == 1, let first = live.first else {
                // Two fingers landed together, so there is no resting anchor to tap against.
                phase = .invalid
                return .none
            }
            anchor = first
            anchorDown = frame.timestamp
            phase = .arming
            return .none

        case .arming:
            guard anchorRestingUnlocked(in: live, tolerance: tolerance),
                  let anchorDown
            else { return .none }
            if live.count == 2 {
                // A second finger arriving before the anchor is established is a scroll chord.
                phase = .invalid
                return .none
            }
            if frame.timestamp - anchorDown >= Self.minAnchorHold {
                phase = .armed
            }
            return .none

        case .armed:
            guard anchorRestingUnlocked(in: live, tolerance: tolerance), let anchor else {
                return .none
            }
            // Promotion to `.armed` happens on its own frame and returns, so any second finger
            // seen here provably landed *after* the anchor was confirmed — no need to guess
            // when it arrived.
            guard live.count == 2, let second = live.first(where: { $0.id != anchor.id }) else {
                return .none
            }
            startCandidateUnlocked(second, at: frame.timestamp)
            return .none

        case .tapping:
            guard anchorRestingUnlocked(in: live, tolerance: tolerance),
                  let anchor, let tapper, let tapperDown
            else { return .none }

            if let current = live.first(where: { $0.id == tapper.id }) {
                tapperTravel = max(
                    tapperTravel,
                    Self.distance(tapper.normalized, current.normalized)
                )
                let tooSlow = frame.timestamp - tapperDown > Self.maxTapDuration * tolerance
                let tooFar = tapperTravel > Self.maxTapTravel * CGFloat(tolerance)
                if tooSlow || tooFar {
                    // Drop back to `.armed`, never `.invalid`: the anchor is still resting, so
                    // the user's next clean tap against it must still be able to fire.
                    Log.debug(.gesture, "tip-tap candidate dropped — second finger held or slid")
                    clearTapperUnlocked()
                    phase = .armed
                }
                return .none
            }

            // The tracked tapper is absent from this frame.
            if let replacement = live.first(where: { $0.id != anchor.id }) {
                // Its id vanished while another non-anchor contact is present: either
                // MultitouchSupport renumbered, or one finger landed as the other left. We
                // cannot prove the vanished contact ended as a clean tap, so refuse to fire —
                // but adopt the newcomer as a fresh candidate so the next tap still works.
                startCandidateUnlocked(replacement, at: frame.timestamp)
                Log.debug(.gesture, "tip-tap tapper id changed — restarting candidate")
                return .none
            }

            // Only the anchor is left, so the tap finished. Snapshot it, then return to
            // `.armed` — repeated taps against one held anchor should each fire, and a
            // rejected tap must not force the user to lift and start over.
            let duration = frame.timestamp - tapperDown
            let travel = tapperTravel
            let offset = tapper.normalized.x - anchor.normalized.x
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
            guard abs(offset) >= Self.minSeparation / CGFloat(tolerance) else {
                // Landed almost on top of the anchor, so the side would be a coin flip. Stay
                // armed and wait for a better separated tap rather than poisoning the session.
                Log.debug(
                    .gesture,
                    "tip-tap rejected — dx=\(String(format: "%.3f", offset)) below separation"
                )
                return .none
            }

            let side: Side = offset < 0 ? .left : .right
            // Debug, not info: the engine logs the slot at info level only once the binding
            // resolves enabled, so a tip-tap nobody asked for stays out of the Debug Log.
            Log.debug(
                .gesture,
                "tip-tap \(side == .left ? "left" : "right") " +
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

    /// True while the stored anchor is still down and still inside its drift budget.
    ///
    /// Latches the session invalid otherwise. A travelling anchor means the user is scrolling,
    /// and latching stops a finger that happens to settle mid-scroll from re-arming and firing
    /// a phantom tip-tap; the latch clears on the frame where every finger is up. A lifted
    /// anchor is equally fatal — the anchor must outlive the tap.
    private func anchorRestingUnlocked(in live: [TouchPoint], tolerance: Double) -> Bool {
        guard let anchor,
              let current = live.first(where: { $0.id == anchor.id }),
              Self.distance(anchor.normalized, current.normalized)
                  <= Self.maxAnchorDrift * CGFloat(tolerance)
        else {
            phase = .invalid
            return false
        }
        return true
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
        anchor = nil
        anchorDown = nil
        clearTapperUnlocked()
    }

    /// −2 strict … +2 forgiving. Widens the permissive thresholds and narrows the required
    /// ones, mirroring how `SwipePinchRecognizer` applies `trackpad.sensitivity`.
    private static func tolerance(sensitivity: Int) -> Double {
        let s = max(-2, min(2, sensitivity))
        return 1.0 + Double(s) * 0.15
    }

    private static func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }
}
