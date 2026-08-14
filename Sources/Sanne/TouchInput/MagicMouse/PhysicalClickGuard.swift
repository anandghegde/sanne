import Foundation

/// 80 ms suppress of synthetic taps after a hardware click + 60 ms ignore of our own CGEvent echo.
struct PhysicalClickGuard: Equatable {
    static let suppressWindow: TimeInterval = 0.08
    static let syntheticEchoIgnore: TimeInterval = 0.06

    var physicalClickDuringContact = false
    var lastPhysicalClickTime: Date?
    var ignorePhysicalEchoUntil: Date?

    mutating func armSyntheticEcho(now: Date = Date()) {
        ignorePhysicalEchoUntil = now.addingTimeInterval(Self.syntheticEchoIgnore)
    }

    func shouldIgnoreEcho(now: Date = Date()) -> Bool {
        guard let until = ignorePhysicalEchoUntil else { return false }
        return now < until
    }

    mutating func notePhysicalClick(now: Date = Date()) {
        physicalClickDuringContact = true
        lastPhysicalClickTime = now
    }

    mutating func clearContactFlag() {
        physicalClickDuringContact = false
    }

    func shouldSuppress(now: Date = Date()) -> Bool {
        if physicalClickDuringContact { return true }
        if let t = lastPhysicalClickTime, now.timeIntervalSince(t) < Self.suppressWindow {
            return true
        }
        return false
    }
}
