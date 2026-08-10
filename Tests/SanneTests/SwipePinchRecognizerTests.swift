import CoreGraphics
import XCTest
@testable import SanneKit

final class SwipePinchRecognizerTests: XCTestCase {
    private var recognizer: SwipePinchRecognizer!
    private var t0: Date!

    override func setUp() {
        super.setUp()
        recognizer = SwipePinchRecognizer()
        t0 = Date(timeIntervalSince1970: 2_000)
    }

    override func tearDown() {
        recognizer = nil
        t0 = nil
        super.tearDown()
    }

    func testFreeSpaceThreeFingerSwipeLeft() {
        // Three contacts start near centre, travel left past swipeMin (~0.08).
        _ = processFree(at: 0.00, points: [
            (1, 0.50, 0.40), (2, 0.50, 0.50), (3, 0.50, 0.60)
        ])
        // Mid-gesture preview.
        let mid = processFree(at: 0.05, points: [
            (1, 0.30, 0.40), (2, 0.30, 0.50), (3, 0.30, 0.60)
        ])
        XCTAssertEqual(mid?.isPreview, true)
        if case .swipe(let fingers, let dir)? = mid?.gesture {
            XCTAssertEqual(fingers, 3)
            XCTAssertEqual(dir, .left)
        } else {
            XCTFail("expected swipe preview, got \(String(describing: mid))")
        }

        // Lift → commit.
        let commit = processFree(at: 0.10, points: [])
        XCTAssertEqual(commit?.isCommit, true)
        if case .swipe(let fingers, let dir)? = commit?.gesture {
            XCTAssertEqual(fingers, 3)
            XCTAssertEqual(dir, .left)
        } else {
            XCTFail("expected swipe commit, got \(String(describing: commit))")
        }
    }

    func testFreeSpaceFourFingerSwipeAndDecayDoesNotDropToThree() {
        // Start with 4 fingers, lock count once travelling, then drop to 3 before lift.
        _ = processFree(at: 0.00, points: [
            (1, 0.40, 0.35), (2, 0.50, 0.35), (3, 0.40, 0.55), (4, 0.50, 0.55)
        ])
        // Travel enough to lock finger count (lock at swipeMin * 0.5 ≈ 0.04).
        _ = processFree(at: 0.03, points: [
            (1, 0.40, 0.55), (2, 0.50, 0.55), (3, 0.40, 0.75), (4, 0.50, 0.75)
        ])
        // One finger lifts mid-swipe — locked peak must remain 4.
        _ = processFree(at: 0.05, points: [
            (1, 0.40, 0.65), (2, 0.50, 0.65), (3, 0.40, 0.85)
        ])
        let commit = processFree(at: 0.10, points: [])
        XCTAssertEqual(commit?.isCommit, true)
        if case .swipe(let fingers, let dir)? = commit?.gesture {
            XCTAssertEqual(fingers, 4, "4→3 decay must not reclassify as 3-finger")
            XCTAssertEqual(dir, .up)
        } else {
            XCTFail("expected 4F swipe commit, got \(String(describing: commit))")
        }
    }

    func testFreeSpaceIgnoresTwoFingerSwipe() {
        _ = processFree(at: 0.00, points: [
            (1, 0.50, 0.40), (2, 0.50, 0.60)
        ])
        let mid = processFree(at: 0.05, points: [
            (1, 0.20, 0.40), (2, 0.20, 0.60)
        ])
        // Free space only emits swipes at 3+ fingers.
        XCTAssertNil(mid)
        let commit = processFree(at: 0.10, points: [])
        XCTAssertNil(commit)
    }

    func testFreeSpaceDoesNotEmitPinch() {
        // Scale change with 2 fingers in free space must not be claimed.
        _ = processFree(at: 0.00, points: [
            (1, 0.40, 0.50), (2, 0.60, 0.50)
        ])
        let mid = processFree(at: 0.05, points: [
            (1, 0.30, 0.50), (2, 0.70, 0.50)
        ])
        XCTAssertNil(mid)
        let commit = processFree(at: 0.10, points: [])
        XCTAssertNil(commit)
    }

    func testTitlebarStillEmitsTwoFingerSwipe() {
        _ = process(zone: .titlebar, at: 0.00, points: [
            (1, 0.50, 0.40), (2, 0.50, 0.60)
        ])
        let commit: SwipePinchRecognizer.Outcome? = {
            _ = process(zone: .titlebar, at: 0.05, points: [
                (1, 0.20, 0.40), (2, 0.20, 0.60)
            ])
            return process(zone: .titlebar, at: 0.10, points: [])
        }()
        XCTAssertEqual(commit?.isCommit, true)
        if case .swipe(let fingers, let dir)? = commit?.gesture {
            XCTAssertEqual(fingers, 2)
            XCTAssertEqual(dir, .left)
        } else {
            XCTFail("expected titlebar 2F swipe, got \(String(describing: commit))")
        }
    }

    func testFreeSwipeSlotMapping() {
        XCTAssertEqual(
            GestureSlots.freeSwipeSlot(fingers: 3, direction: .left),
            GestureSlots.ID.free3SwipeLeft
        )
        XCTAssertEqual(
            GestureSlots.freeSwipeSlot(fingers: 4, direction: .up),
            GestureSlots.ID.free4SwipeUp
        )
        // 5+ collapses to the 4-finger row.
        XCTAssertEqual(
            GestureSlots.freeSwipeSlot(fingers: 5, direction: .right),
            GestureSlots.ID.free4SwipeRight
        )
        // Free space has no diagonals.
        XCTAssertNil(GestureSlots.freeSwipeSlot(fingers: 3, direction: .upLeft))
    }

    // MARK: - Helpers

    @discardableResult
    private func processFree(
        at offset: TimeInterval,
        points: [(Int, CGFloat, CGFloat)]
    ) -> SwipePinchRecognizer.Outcome? {
        process(zone: .free, at: offset, points: points)
    }

    @discardableResult
    private func process(
        zone: CursorZone,
        at offset: TimeInterval,
        points: [(Int, CGFloat, CGFloat)]
    ) -> SwipePinchRecognizer.Outcome? {
        let frame = TouchFrameFixtures.frame(
            at: t0.addingTimeInterval(offset),
            touches: points.map { (id: $0.0, x: $0.1, y: $0.2, phase: .moved) }
        )
        return recognizer.process(frame: frame, zone: zone, sensitivity: 0)
    }
}
