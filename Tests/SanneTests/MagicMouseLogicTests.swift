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
        XCTAssertGreaterThan(strict.pageSwipeMin, loose.pageSwipeMin)
        XCTAssertGreaterThan(strict.swipeMin, loose.swipeMin)
    }

    func testPageSwipeIgnoresFingerDrift() {
        let thr = MMThresholds(sensitivity: 0)
        XCTAssertGreaterThan(thr.pageSwipeMin, 0.15)
        XCTAssertFalse(
            MMSwipeMachine.shouldCommitPageSwipe(
                dx: 0.09, dy: 0.01, cursorDist: 0, physicalOwns: false,
                slotsEnabled: true, thr: thr
            ),
            "8–9% surface slide used to fire back/forward"
        )
    }

    func testPageSwipeIgnoresDiagonalScroll() {
        let thr = MMThresholds(sensitivity: 0)
        XCTAssertTrue(MMSwipeMachine.isHorizontalPageSwipe(dx: 0.28, dy: 0.05))
        XCTAssertFalse(MMSwipeMachine.isHorizontalPageSwipe(dx: 0.22, dy: 0.20))
        XCTAssertFalse(
            MMSwipeMachine.shouldCommitPageSwipe(
                dx: 0.22, dy: 0.20, cursorDist: 0, physicalOwns: false,
                slotsEnabled: true, thr: thr
            )
        )
    }

    func testPageSwipeIgnoresCursorMoveAndClick() {
        let thr = MMThresholds(sensitivity: 0)
        XCTAssertFalse(
            MMSwipeMachine.shouldCommitPageSwipe(
                dx: 0.28, dy: 0.02, cursorDist: 24, physicalOwns: false,
                slotsEnabled: true, thr: thr
            )
        )
        XCTAssertFalse(
            MMSwipeMachine.shouldCommitPageSwipe(
                dx: 0.28, dy: 0.02, cursorDist: 0, physicalOwns: true,
                slotsEnabled: true, thr: thr
            )
        )
    }

    func testPageSwipeCommitsClearHorizontalSlide() {
        let thr = MMThresholds(sensitivity: 0)
        XCTAssertTrue(
            MMSwipeMachine.shouldCommitPageSwipe(
                dx: 0.28, dy: 0.04, cursorDist: 3, physicalOwns: false,
                slotsEnabled: true, thr: thr
            )
        )
        XCTAssertFalse(
            MMSwipeMachine.shouldCommitPageSwipe(
                dx: 0.28, dy: 0.04, cursorDist: 3, physicalOwns: false,
                slotsEnabled: false, thr: thr
            )
        )
    }

    func testDecideLiftDoesNotTreatDriftAsPageSwipe() {
        let snap = pageSwipeSnapshot()
        let thr = MMThresholds(sensitivity: 0)
        let drift = MMTapMachine.decideLift(
            snapshot: snap,
            duration: 0.14,
            surfaceMoved: 0.09,
            peakVel: 0.4,
            peakSize: 0.2,
            cursorDist: 2,
            startX: 0.30,
            dx: 0.09,
            dy: 0.01,
            tapBlocked: false,
            physicalOwns: false,
            rightHeld: false,
            thr: thr
        )
        XCTAssertEqual(drift, .reject("surface"))

        let swipe = MMTapMachine.decideLift(
            snapshot: snap,
            duration: 0.16,
            surfaceMoved: 0.28,
            peakVel: 0.8,
            peakSize: 0.2,
            cursorDist: 2,
            startX: 0.30,
            dx: 0.28,
            dy: 0.03,
            tapBlocked: false,
            physicalOwns: false,
            rightHeld: false,
            thr: thr
        )
        XCTAssertEqual(swipe, .pageSwipe(dx: 0.28))
    }

    func testDecideLiftPageSwipeLosesToCursorAndClick() {
        let snap = pageSwipeSnapshot()
        let thr = MMThresholds(sensitivity: 0)
        XCTAssertEqual(
            MMTapMachine.decideLift(
                snapshot: snap,
                duration: 0.16,
                surfaceMoved: 0.28,
                peakVel: 0.8,
                peakSize: 0.2,
                cursorDist: 30,
                startX: 0.30,
                dx: 0.28,
                dy: 0.03,
                tapBlocked: false,
                physicalOwns: false,
                rightHeld: false,
                thr: thr
            ),
            .reject("surface")
        )
        XCTAssertEqual(
            MMTapMachine.decideLift(
                snapshot: snap,
                duration: 0.16,
                surfaceMoved: 0.28,
                peakVel: 0.8,
                peakSize: 0.2,
                cursorDist: 2,
                startX: 0.30,
                dx: 0.28,
                dy: 0.03,
                tapBlocked: false,
                physicalOwns: true,
                rightHeld: false,
                thr: thr
            ),
            .reject("physical click owns contact")
        )
    }

    private func pageSwipeSnapshot() -> RuntimeSnapshot {
        var config = SanneConfig()
        config.magicMouseTaps.oneFingerSwipePages = true
        return RuntimeSnapshot.build(config: config, frontmostBundleId: nil)
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

    func testTipTapSlotsMatchBTTTabDefaults() {
        let left = GestureSlots.slot(id: GestureSlots.ID.mmTipTapLeft)
        let right = GestureSlots.slot(id: GestureSlots.ID.mmTipTapRight)
        XCTAssertEqual(left?.defaultActionId, ActionCatalog.ID.browserPrevTab)
        XCTAssertEqual(right?.defaultActionId, ActionCatalog.ID.browserNextTab)
        XCTAssertEqual(left?.defaultEnabled, true)
        XCTAssertEqual(right?.defaultEnabled, true)
        XCTAssertEqual(left?.visibility, .simple)
        XCTAssertEqual(GestureSlots.magicMouseTipTapSlot(side: .left), GestureSlots.ID.mmTipTapLeft)
        XCTAssertEqual(GestureSlots.magicMouseTipTapSlot(side: .right), GestureSlots.ID.mmTipTapRight)
        XCTAssertEqual(GestureSlots.magicMouseTipTapSlot(side: .middle), GestureSlots.ID.mmTipTapMiddle)
        XCTAssertEqual(GestureSlots.slot(id: GestureSlots.ID.mmTipTapMiddle)?.defaultEnabled, false)

        let leftDiagram = GestureDiagram.from(slotId: GestureSlots.ID.mmTipTapLeft)
        XCTAssertEqual(leftDiagram.device, .magicMouse)
        XCTAssertEqual(leftDiagram.fingers, 2)
        XCTAssertEqual(leftDiagram.motion, .tipTap(.left))
        XCTAssertEqual(
            GestureDiagram.from(slotId: GestureSlots.ID.mmTipTapRight).motion,
            .tipTap(.right)
        )
    }

    func testSyntheticEchoIgnore() {
        var clickGuard = PhysicalClickGuard()
        let t0: TimeInterval = 1_000
        clickGuard.armSyntheticEcho(now: t0)
        XCTAssertTrue(clickGuard.shouldIgnoreEcho(now: t0 + 0.03))
        XCTAssertFalse(clickGuard.shouldIgnoreEcho(now: t0 + 0.07))
    }
}
