import XCTest
@testable import SanneKit

final class DeviceClassifierTests: XCTestCase {
    func testBuiltInTrackpad() {
        let kind = TouchDeviceClassifier.classify(
            .init(isBuiltIn: true, isOpaque: false, supportsForce: true)
        )
        XCTAssertEqual(kind, .builtInTrackpad)
        XCTAssertTrue(TouchDeviceClassifier.isTrackpad(kind))
        XCTAssertFalse(TouchDeviceClassifier.isMagicMouse(kind))
    }

    func testExternalMagicTrackpadIsNotAMouse() {
        let kind = TouchDeviceClassifier.classify(
            .init(isBuiltIn: false, isOpaque: false, supportsForce: true)
        )
        XCTAssertEqual(kind, .magicTrackpad)
        XCTAssertTrue(TouchDeviceClassifier.isTrackpad(kind))
        XCTAssertFalse(TouchDeviceClassifier.isMagicMouse(kind))
    }

    func testOpaqueSurfaceIsMagicMouse() {
        let kind = TouchDeviceClassifier.classify(
            .init(isBuiltIn: false, isOpaque: true, supportsForce: false)
        )
        XCTAssertEqual(kind, .magicMouse)
        XCTAssertTrue(TouchDeviceClassifier.isMagicMouse(kind))
        XCTAssertFalse(TouchDeviceClassifier.isTrackpad(kind))
    }

    func testExternalNeitherForceNorOpaqueIsMagicMouse() {
        // Magic Mouse 2 often reports opaque=false, force=false.
        let kind = TouchDeviceClassifier.classify(
            .init(isBuiltIn: false, isOpaque: false, supportsForce: false)
        )
        XCTAssertEqual(kind, .magicMouse)
        XCTAssertTrue(TouchDeviceClassifier.isMagicMouse(kind))
    }

    func testProductNameMouseBeatsForceTouch() {
        let kind = TouchDeviceClassifier.classify(
            .init(isBuiltIn: false, isOpaque: false, supportsForce: true, productName: "Magic Mouse")
        )
        XCTAssertEqual(kind, .magicMouse)
    }

    func testProductNameTrackpadBeatsOpaque() {
        let kind = TouchDeviceClassifier.classify(
            .init(isBuiltIn: false, isOpaque: true, supportsForce: true, productName: "Magic Trackpad")
        )
        XCTAssertEqual(kind, .magicTrackpad)
    }

    func testNewTrackpadTriggerDiagrams() {
        let middle = GestureDiagram.from(slotId: GestureSlots.ID.tipTapMiddle)
        XCTAssertEqual(middle.device, .trackpad)
        XCTAssertEqual(middle.motion, .tipTap(.center))
        let three = GestureDiagram.from(slotId: GestureSlots.ID.tipTap3Left)
        XCTAssertEqual(three.fingers, 3)
        XCTAssertEqual(three.motion, .tipTap(.left))
        let click = GestureDiagram.from(slotId: GestureSlots.ID.free3Click)
        XCTAssertEqual(click.motion, .click)
        XCTAssertEqual(click.fingers, 3)
        let corner = GestureDiagram.from(slotId: GestureSlots.ID.cornerTopLeft)
        XCTAssertEqual(corner.zone, .topEdge)
        XCTAssertEqual(corner.side, .left)
        XCTAssertEqual(corner.motion, .tap)
    }

    func testEverySlotDiagramIsNotAKeyboardTile() {
        for slot in GestureSlots.all where slot.group != .keyboard {
            let diagram = GestureDiagram.from(slotId: slot.id)
            XCTAssertNotEqual(
                diagram.device,
                .keyboard,
                "slot \(slot.id) must draw a trackpad or mouse tile"
            )
        }
        for slot in GestureSlots.all where slot.group == .keyboard {
            XCTAssertEqual(GestureDiagram.from(slotId: slot.id).device, .keyboard, slot.id)
        }
    }

    func testWakeRebindHasThreeBackoffAttempts() {
        XCTAssertEqual(WakeRebind.attemptDelaysNanoseconds.count, 3)
        XCTAssertEqual(WakeRebind.attemptDelaysNanoseconds[0], 200_000_000)
        XCTAssertEqual(WakeRebind.attemptDelaysNanoseconds[1], 800_000_000)
        XCTAssertEqual(WakeRebind.attemptDelaysNanoseconds[2], 2_000_000_000)
    }
}
