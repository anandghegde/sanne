import Foundation

/// 0.75 / 0.90 / 0.40 s tap locks after scroll; residual re-arm on rejected lifts.
struct ScrollLock: Equatable {
    static let surface: TimeInterval = 0.90
    static let wheel: TimeInterval = 0.75
    static let momentum: TimeInterval = 0.75
    static let residual: TimeInterval = 0.40
    static let wheelTouchCorrelation: TimeInterval = 1.5
    static let wheelDeltaMin: CGFloat = 1.5

    var noTapUntil: TimeInterval?

    mutating func arm(for duration: TimeInterval, now: TimeInterval = CFAbsoluteTimeGetCurrent()) {
        let until = now + duration
        if let existing = noTapUntil, existing >= until { return }
        noTapUntil = until
    }

    mutating func rearmResidual(now: TimeInterval = CFAbsoluteTimeGetCurrent()) {
        arm(for: Self.residual, now: now)
    }

    /// Contact must *begin* after the lock expires (not merely end after it).
    func isBlocked(contactStart: TimeInterval) -> Bool {
        guard let until = noTapUntil else { return false }
        return contactStart < until
    }
}
