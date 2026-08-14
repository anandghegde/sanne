import XCTest
@testable import SanneKit

final class ThreeFingerTapTests: XCTestCase {
    func testTravelAboveThresholdIsNotATap() {
        let rec = ThreeFingerDragRecognizer()
        let t0 = Date()
        let start = frame(at: t0, points: [
            CGPoint(x: 0.3, y: 0.5),
            CGPoint(x: 0.4, y: 0.5),
            CGPoint(x: 0.5, y: 0.5),
        ])
        XCTAssertEqual(rec.process(frame: start, sensitivity: 0), .none)

        let moved = frame(at: t0.addingTimeInterval(0.05), points: [
            CGPoint(x: 0.3, y: 0.7),
            CGPoint(x: 0.4, y: 0.7),
            CGPoint(x: 0.5, y: 0.7),
        ])
        let mid = rec.process(frame: moved, sensitivity: 0)
        XCTAssertNotEqual(mid, .tap)

        let lift = TouchFrame(
            timestamp: t0.addingTimeInterval(0.08).timeIntervalSinceReferenceDate,
            deviceID: 1,
            deviceKind: .builtInTrackpad,
            touches: []
        )
        let end = rec.process(frame: lift, sensitivity: 0)
        XCTAssertNotEqual(end, .tap, "travel above the tap threshold must not middle-click")
    }

    func testStationaryChordIsATap() {
        let rec = ThreeFingerDragRecognizer()
        let t0 = Date()
        let pts = [
            CGPoint(x: 0.3, y: 0.5),
            CGPoint(x: 0.4, y: 0.5),
            CGPoint(x: 0.5, y: 0.5),
        ]
        _ = rec.process(frame: frame(at: t0, points: pts), sensitivity: 0)
        _ = rec.process(frame: frame(at: t0.addingTimeInterval(0.05), points: pts), sensitivity: 0)
        let lift = TouchFrame(
            timestamp: t0.addingTimeInterval(0.08).timeIntervalSinceReferenceDate,
            deviceID: 1,
            deviceKind: .builtInTrackpad,
            touches: []
        )
        XCTAssertEqual(rec.process(frame: lift, sensitivity: 0), .tap)
    }

    func testTravelDoesNotFireTapWhenDragIsOff() {
        let rec = ThreeFingerDragRecognizer()
        let t0 = Date()
        let start = frame(at: t0, points: [
            CGPoint(x: 0.3, y: 0.4),
            CGPoint(x: 0.4, y: 0.4),
            CGPoint(x: 0.5, y: 0.4),
        ])
        XCTAssertEqual(rec.process(frame: start, sensitivity: 0), .none)

        let moved = frame(at: t0.addingTimeInterval(0.05), points: [
            CGPoint(x: 0.3, y: 0.7),
            CGPoint(x: 0.4, y: 0.7),
            CGPoint(x: 0.5, y: 0.7),
        ])
        let mid = rec.process(frame: moved, sensitivity: 0)
        XCTAssertNotEqual(mid, .tap)

        let lift = TouchFrame(
            timestamp: t0.addingTimeInterval(0.08).timeIntervalSinceReferenceDate,
            deviceID: 1,
            deviceKind: .builtInTrackpad,
            touches: []
        )
        XCTAssertNotEqual(
            rec.process(frame: lift, sensitivity: 0),
            .tap,
            "travel above the tap threshold must not middle-click even when drag is unused"
        )
    }

    private func frame(at time: Date, points: [CGPoint]) -> TouchFrame {
        TouchFrame(
            timestamp: time.timeIntervalSinceReferenceDate,
            deviceID: 1,
            deviceKind: .builtInTrackpad,
            touches: points.enumerated().map { i, p in
                TouchPoint(
                    id: i,
                    normalized: p,
                    majorAxis: 0.1,
                    minorAxis: 0.1,
                    state: 4,
                    phase: .moved
                )
            }
        )
    }
}
