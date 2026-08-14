import Foundation

/// 80 ms suppress of synthetic taps after a hardware click + 60 ms ignore of our own CGEvent echo.
struct PhysicalClickGuard: Equatable {
    static let suppressWindow: TimeInterval = 0.08
    static let syntheticEchoIgnore: TimeInterval = 0.06

    var physicalClickDuringContact = false
    var lastPhysicalClickTime: TimeInterval?
    var ignorePhysicalEchoUntil: TimeInterval?

    mutating func armSyntheticEcho(now: TimeInterval = CFAbsoluteTimeGetCurrent()) {
        ignorePhysicalEchoUntil = now + Self.syntheticEchoIgnore
    }

    func shouldIgnoreEcho(now: TimeInterval = CFAbsoluteTimeGetCurrent()) -> Bool {
        guard let until = ignorePhysicalEchoUntil else { return false }
        return now < until
    }

    mutating func notePhysicalClick(now: TimeInterval = CFAbsoluteTimeGetCurrent()) {
        physicalClickDuringContact = true
        lastPhysicalClickTime = now
    }

    mutating func clearContactFlag() {
        physicalClickDuringContact = false
    }

    func shouldSuppress(now: TimeInterval = CFAbsoluteTimeGetCurrent()) -> Bool {
        if physicalClickDuringContact { return true }
        if let t = lastPhysicalClickTime, now - t < Self.suppressWindow {
            return true
        }
        return false
    }
}
