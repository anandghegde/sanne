import CoreGraphics
import XCTest
@testable import SanneKit

final class TipTapRecognizerTests: XCTestCase {
    private var recognizer: TipTapRecognizer!
    private var t0: Date!

    override func setUp() {
        super.setUp()
        recognizer = TipTapRecognizer()
        t0 = Date(timeIntervalSince1970: 1_000)
    }

    override func tearDown() {
        recognizer = nil
        t0 = nil
        super.tearDown()
    }

    func testTipTapLeftAndRight() {
        // Anchor held past minAnchorHold (0.15s).
        _ = process(at: 0.00, touches: [(1, 0.50, 0.50, .began)])
        _ = process(at: 0.16, touches: [(1, 0.50, 0.50, .stationary)])

        // Tap to the left of the anchor.
        _ = process(at: 0.17, touches: [
            (1, 0.50, 0.50, .stationary),
            (2, 0.30, 0.50, .began)
        ])
        let left = process(at: 0.20, touches: [
            (1, 0.50, 0.50, .stationary)
        ])
        XCTAssertEqual(left, .tipTap(.left))

        // Second tap to the right against the same held anchor.
        _ = process(at: 0.30, touches: [
            (1, 0.50, 0.50, .stationary),
            (3, 0.70, 0.50, .began)
        ])
        let right = process(at: 0.33, touches: [
            (1, 0.50, 0.50, .stationary)
        ])
        XCTAssertEqual(right, .tipTap(.right))
    }

    func testAnchorDriftCancels() {
        _ = process(at: 0.00, touches: [(1, 0.50, 0.50, .began)])
        _ = process(at: 0.16, touches: [(1, 0.50, 0.50, .stationary)])

        // Anchor slides past maxAnchorDrift (0.03) — session latches invalid.
        _ = process(at: 0.18, touches: [(1, 0.60, 0.50, .moved)])

        // A clean second-finger tap must not fire while the anchor is travelling.
        _ = process(at: 0.19, touches: [
            (1, 0.60, 0.50, .moved),
            (2, 0.30, 0.50, .began)
        ])
        let outcome = process(at: 0.21, touches: [
            (1, 0.60, 0.50, .moved)
        ])
        XCTAssertEqual(outcome, .none)
    }

    func testTapTimeoutRejectsHold() {
        _ = process(at: 0.00, touches: [(1, 0.50, 0.50, .began)])
        _ = process(at: 0.16, touches: [(1, 0.50, 0.50, .stationary)])

        // Second finger held past maxTapDuration (0.25s) → candidate dropped, stay armed.
        _ = process(at: 0.17, touches: [
            (1, 0.50, 0.50, .stationary),
            (2, 0.30, 0.50, .began)
        ])
        let duringHold = process(at: 0.50, touches: [
            (1, 0.50, 0.50, .stationary),
            (2, 0.30, 0.50, .stationary)
        ])
        XCTAssertEqual(duringHold, .none)

        // Lift after the drop still produces nothing for that candidate.
        let afterLift = process(at: 0.51, touches: [
            (1, 0.50, 0.50, .stationary)
        ])
        XCTAssertEqual(afterLift, .none)

        // A subsequent clean tap against the still-held anchor can still fire.
        _ = process(at: 0.60, touches: [
            (1, 0.50, 0.50, .stationary),
            (3, 0.30, 0.50, .began)
        ])
        let clean = process(at: 0.62, touches: [
            (1, 0.50, 0.50, .stationary)
        ])
        XCTAssertEqual(clean, .tipTap(.left))
    }

    func testTwoFingersTogetherInvalidates() {
        // No resting anchor if both land together.
        let first = process(at: 0.00, touches: [
            (1, 0.50, 0.50, .began),
            (2, 0.30, 0.50, .began)
        ])
        XCTAssertEqual(first, .none)

        let later = process(at: 0.20, touches: [
            (1, 0.50, 0.50, .stationary)
        ])
        XCTAssertEqual(later, .none)
    }

    func testThreePlusContactsInvalidates() {
        _ = process(at: 0.00, touches: [(1, 0.50, 0.50, .began)])
        _ = process(at: 0.16, touches: [(1, 0.50, 0.50, .stationary)])
        _ = process(at: 0.17, touches: [
            (1, 0.50, 0.50, .stationary),
            (2, 0.40, 0.50, .began),
            (3, 0.60, 0.50, .began)
        ])
        // Empty pad clears the latch so later sessions work.
        _ = process(at: 0.50, touches: [])
        _ = process(at: 0.51, touches: [(1, 0.50, 0.50, .began)])
        _ = process(at: 0.70, touches: [(1, 0.50, 0.50, .stationary)])
        _ = process(at: 0.71, touches: [
            (1, 0.50, 0.50, .stationary),
            (4, 0.30, 0.50, .began)
        ])
        let ok = process(at: 0.73, touches: [
            (1, 0.50, 0.50, .stationary)
        ])
        XCTAssertEqual(ok, .tipTap(.left))
    }

    func testInsufficientSeparationIsMiddle() {
        _ = process(at: 0.00, touches: [(1, 0.50, 0.50, .began)])
        _ = process(at: 0.16, touches: [(1, 0.50, 0.50, .stationary)])
        // dx = 0.02 < minSeparation (0.04)
        _ = process(at: 0.17, touches: [
            (1, 0.50, 0.50, .stationary),
            (2, 0.48, 0.50, .began)
        ])
        let outcome = process(at: 0.20, touches: [
            (1, 0.50, 0.50, .stationary)
        ])
        XCTAssertEqual(outcome, .tipTap(.middle))
    }

    func testThreeFingerTipTapLeft() {
        let rec = TipTapRecognizer(anchorCount: 2)
        func step(
            _ offset: TimeInterval,
            _ touches: [(Int, CGFloat, CGFloat, TouchPhase)]
        ) -> TipTapRecognizer.Outcome {
            rec.process(
                frame: TouchFrameFixtures.frame(
                    at: t0.addingTimeInterval(offset),
                    touches: touches.map { (id: $0.0, x: $0.1, y: $0.2, phase: $0.3) }
                ),
                sensitivity: 0
            )
        }
        _ = step(0.00, [(1, 0.40, 0.50, .began), (2, 0.50, 0.50, .began)])
        _ = step(0.16, [(1, 0.40, 0.50, .stationary), (2, 0.50, 0.50, .stationary)])
        _ = step(0.17, [
            (1, 0.40, 0.50, .stationary),
            (2, 0.50, 0.50, .stationary),
            (3, 0.20, 0.50, .began),
        ])
        let left = step(0.20, [
            (1, 0.40, 0.50, .stationary),
            (2, 0.50, 0.50, .stationary),
        ])
        XCTAssertEqual(left, .tipTap(.left))
    }

    func testThreeFingerChordTogetherDoesNotTipTap() {
        let rec = TipTapRecognizer(anchorCount: 2)
        let first = rec.process(
            frame: TouchFrameFixtures.frame(
                at: t0,
                touches: [
                    (id: 1, x: 0.30, y: 0.50, phase: .began),
                    (id: 2, x: 0.45, y: 0.50, phase: .began),
                    (id: 3, x: 0.60, y: 0.50, phase: .began),
                ]
            ),
            sensitivity: 0
        )
        XCTAssertEqual(first, .none)
        let later = rec.process(
            frame: TouchFrameFixtures.frame(
                at: t0.addingTimeInterval(0.20),
                touches: [
                    (id: 1, x: 0.30, y: 0.50, phase: .stationary),
                    (id: 2, x: 0.45, y: 0.50, phase: .stationary),
                ]
            ),
            sensitivity: 0
        )
        XCTAssertEqual(later, .none)
    }

    // MARK: - Helpers

    @discardableResult
    private func process(
        at offset: TimeInterval,
        touches: [(Int, CGFloat, CGFloat, TouchPhase)]
    ) -> TipTapRecognizer.Outcome {
        let frame = TouchFrameFixtures.frame(
            at: t0.addingTimeInterval(offset),
            touches: touches.map { (id: $0.0, x: $0.1, y: $0.2, phase: $0.3) }
        )
        return recognizer.process(frame: frame, sensitivity: 0)
    }
}
