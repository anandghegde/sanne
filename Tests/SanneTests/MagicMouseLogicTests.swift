import XCTest
@testable import SanneKit

final class MagicMouseLogicTests: XCTestCase {
    func testDeadZoneRejectsCenter() {
        XCTAssertEqual(MMGeometry.tapZone(x: 0.50, split: 0.50, deadZone: 0.10), .dead)
        XCTAssertEqual(MMGeometry.tapZone(x: 0.48, split: 0.50, deadZone: 0.10), .dead)
        XCTAssertEqual(MMGeometry.tapZone(x: 0.52, split: 0.50, deadZone: 0.10), .dead)
        XCTAssertEqual(MMGeometry.tapZone(x: 0.44, split: 0.50, deadZone: 0.10), .left)
        XCTAssertEqual(MMGeometry.tapZone(x: 0.56, split: 0.50, deadZone: 0.10), .right)
    }

    func testDeadZoneZeroIsSplitOnly() {
        XCTAssertEqual(MMGeometry.tapZone(x: 0.49, split: 0.50, deadZone: 0), .left)
        XCTAssertEqual(MMGeometry.tapZone(x: 0.50, split: 0.50, deadZone: 0), .right)
    }

    func testThresholdsScaleWithSensitivity() {
        let strict = MMThresholds(sensitivity: -2)
        let loose = MMThresholds(sensitivity: 2)
        XCTAssertGreaterThan(strict.minDuration, loose.minDuration)
        XCTAssertLessThan(strict.maxDuration, loose.maxDuration)
        XCTAssertGreaterThan(strict.surfaceScroll, loose.surfaceScroll)
        XCTAssertGreaterThan(strict.swipeMin, loose.swipeMin)
    }

    func testSwipeAxisTiesGoVertical() {
        XCTAssertEqual(MMGeometry.swipeAxis(dx: 0.1, dy: 0.1), .up)
        XCTAssertEqual(MMGeometry.swipeAxis(dx: 0.1, dy: -0.1), .down)
        XCTAssertEqual(MMGeometry.swipeAxis(dx: -0.2, dy: 0.05), .left)
        XCTAssertEqual(MMGeometry.swipeAxis(dx: 0.2, dy: 0.05), .right)
    }

    func testScrollLockRearmExtends() {
        var lock = ScrollLock()
        let t0: TimeInterval = 1_000
        lock.arm(for: 0.20, now: t0)
        XCTAssertTrue(lock.isBlocked(contactStart: t0))
        XCTAssertFalse(lock.isBlocked(contactStart: t0 + 0.21))
        lock.rearmResidual(now: t0 + 0.15)
        XCTAssertTrue(lock.isBlocked(contactStart: t0 + 0.30))
        XCTAssertFalse(lock.isBlocked(contactStart: t0 + 0.56))
    }

    func testPhysicalClickWindow() {
        var clickGuard = PhysicalClickGuard()
        let t0: TimeInterval = 1_000
        XCTAssertFalse(clickGuard.shouldSuppress(now: t0))
        clickGuard.notePhysicalClick(now: t0)
        XCTAssertTrue(clickGuard.shouldSuppress(now: t0 + 0.04))
        clickGuard.clearContactFlag()
        XCTAssertTrue(clickGuard.shouldSuppress(now: t0 + 0.04))
        XCTAssertFalse(clickGuard.shouldSuppress(now: t0 + 0.09))
    }

    func testStatsDoesNotDeadlockAcrossManagers() {
        // TDM.stats used to hold TDM.lock while calling MM.stats, which re-took TDM.lock.
        // start() logs those stats on the main thread, so the app hung on launch.
        let exp = expectation(description: "stats returned")
        DispatchQueue.global().async {
            _ = TouchDeviceManager.shared.stats
            _ = MagicMouseTapController.shared.stats
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
    }

    func testSyntheticEchoIgnore() {
        var clickGuard = PhysicalClickGuard()
        let t0: TimeInterval = 1_000
        clickGuard.armSyntheticEcho(now: t0)
        XCTAssertTrue(clickGuard.shouldIgnoreEcho(now: t0 + 0.03))
        XCTAssertFalse(clickGuard.shouldIgnoreEcho(now: t0 + 0.07))
    }
}
