import CoreGraphics
import XCTest
@testable import SanneKit

final class CornerTapRecognizerTests: XCTestCase {
    private var recognizer: CornerTapRecognizer!
    private var t0: Date!

    override func setUp() {
        super.setUp()
        recognizer = CornerTapRecognizer()
        t0 = Date(timeIntervalSince1970: 1_000)
    }

    func testCornerAndTopRegions() {
        XCTAssertEqual(CornerTapRecognizer.region(at: CGPoint(x: 0.08, y: 0.92)), .topLeft)
        XCTAssertEqual(CornerTapRecognizer.region(at: CGPoint(x: 0.92, y: 0.92)), .topRight)
        XCTAssertEqual(CornerTapRecognizer.region(at: CGPoint(x: 0.08, y: 0.08)), .bottomLeft)
        XCTAssertEqual(CornerTapRecognizer.region(at: CGPoint(x: 0.92, y: 0.08)), .bottomRight)
        XCTAssertEqual(CornerTapRecognizer.region(at: CGPoint(x: 0.50, y: 0.90)), .top)
        XCTAssertNil(CornerTapRecognizer.region(at: CGPoint(x: 0.50, y: 0.50)))
    }

    func testTopLeftTapFiresOnLift() {
        _ = process(at: 0.00, x: 0.10, y: 0.90, phase: .began)
        _ = process(at: 0.08, x: 0.10, y: 0.90, phase: .stationary)
        XCTAssertEqual(processEmpty(at: 0.12), .tap(.topLeft))
    }

    func testCenterTapIsIgnored() {
        _ = process(at: 0.00, x: 0.50, y: 0.50, phase: .began)
        _ = process(at: 0.08, x: 0.50, y: 0.50, phase: .stationary)
        XCTAssertEqual(processEmpty(at: 0.12), .none)
    }

    func testSecondFingerCancels() {
        _ = process(at: 0.00, x: 0.10, y: 0.90, phase: .began)
        let two = recognizer.process(
            frame: TouchFrameFixtures.frame(
                at: t0.addingTimeInterval(0.05),
                touches: [
                    (id: 1, x: 0.10, y: 0.90, phase: .stationary),
                    (id: 2, x: 0.30, y: 0.90, phase: .began),
                ]
            ),
            sensitivity: 0
        )
        XCTAssertEqual(two, .none)
        XCTAssertEqual(processEmpty(at: 0.12), .none)
    }

    func testSlotIdsMatchRegions() {
        XCTAssertEqual(
            CornerTapRecognizer.slotId(for: .topLeft),
            GestureSlots.ID.cornerTopLeft
        )
        XCTAssertEqual(CornerTapRecognizer.slotId(for: .top), GestureSlots.ID.tapTop)
    }

    @discardableResult
    private func process(
        at offset: TimeInterval,
        x: CGFloat,
        y: CGFloat,
        phase: TouchPhase
    ) -> CornerTapRecognizer.Outcome {
        recognizer.process(
            frame: TouchFrameFixtures.frame(
                at: t0.addingTimeInterval(offset),
                touches: [(id: 1, x: x, y: y, phase: phase)]
            ),
            sensitivity: 0
        )
    }

    private func processEmpty(at offset: TimeInterval) -> CornerTapRecognizer.Outcome {
        recognizer.process(
            frame: TouchFrameFixtures.empty(at: t0.addingTimeInterval(offset)),
            sensitivity: 0
        )
    }
}
