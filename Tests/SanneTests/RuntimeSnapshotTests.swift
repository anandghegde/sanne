import XCTest
@testable import SanneKit

final class RuntimeSnapshotTests: XCTestCase {
    func testSnapshotMatchesResolverForEverySlot() {
        var config = SanneConfig()
        config.version = 2
        config.presetId = SannePreset.standardId
        let snap = RuntimeSnapshot.build(config: config, frontmostBundleId: nil)
        for slot in GestureSlots.all {
            let resolved = BindingResolver.resolve(slotId: slot.id, config: config)
            XCTAssertEqual(snap.slotOn(slot.id), resolved?.enabled ?? false, slot.id)
            XCTAssertEqual(snap.actionId(for: slot.id), resolved?.actionId, slot.id)
        }
    }

    func testFrontmostAppRemapIsStampedOnSnapshot() {
        var config = SanneConfig()
        config.version = 2
        let safari = "com.apple.Safari"
        config.setGestureOverride(
            slotId: GestureSlots.ID.mmLeft,
            enabled: true,
            actionId: ActionCatalog.ID.clickRight,
            scope: .app(bundleId: safari)
        )
        let global = RuntimeSnapshot.build(config: config, frontmostBundleId: nil)
        let app = RuntimeSnapshot.build(config: config, frontmostBundleId: safari)
        XCTAssertEqual(global.actionId(for: GestureSlots.ID.mmLeft), ActionCatalog.ID.clickLeft)
        XCTAssertEqual(app.actionId(for: GestureSlots.ID.mmLeft), ActionCatalog.ID.clickRight)
    }

    func testMasterOffClearsEnabledSet() {
        var config = SanneConfig()
        config.version = 2
        config.magicMouseTaps.enabled = false
        let snap = RuntimeSnapshot.build(config: config, frontmostBundleId: nil)
        XCTAssertFalse(snap.slotOn(GestureSlots.ID.mmLeft))
        XCTAssertFalse(snap.masters.magicMouse)
    }
}

final class AXFrameWriteTests: XCTestCase {
    func testLiveSkipWhenRectUnchanged() {
        let rect = CGRect(x: 10, y: 20, width: 300, height: 200)
        XCTAssertTrue(AXFrameWrite.shouldSkipLive(previous: rect, next: rect))
        XCTAssertTrue(AXFrameWrite.shouldSkipLive(previous: rect, next: rect.offsetBy(dx: 0.2, dy: 0.2)))
        XCTAssertFalse(AXFrameWrite.shouldSkipLive(previous: rect, next: rect.offsetBy(dx: 2, dy: 0)))
        XCTAssertFalse(AXFrameWrite.shouldSkipLive(previous: nil, next: rect))
    }

    func testLiveKindMoveVsResize() {
        let rect = CGRect(x: 0, y: 0, width: 100, height: 80)
        XCTAssertEqual(AXFrameWrite.liveKind(previous: rect, next: rect.offsetBy(dx: 10, dy: 5)), .move)
        XCTAssertEqual(
            AXFrameWrite.liveKind(previous: rect, next: CGRect(x: 0, y: 0, width: 140, height: 80)),
            .resize
        )
    }
}

final class MMSwipeMachineTests: XCTestCase {
    func testFingerFreezeAfterHalfSwipeMin() {
        let swipeMin: Float = 0.10
        XCTAssertEqual(
            MMSwipeMachine.creditFingers(current: 2, reported: 3, maxTravel: 0.04, swipeMin: swipeMin),
            3
        )
        XCTAssertEqual(
            MMSwipeMachine.creditFingers(current: 2, reported: 3, maxTravel: 0.06, swipeMin: swipeMin),
            2,
            "2F must not promote to 3F after swipeMin * 0.5"
        )
    }
}
