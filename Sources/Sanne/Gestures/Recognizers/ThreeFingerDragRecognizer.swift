import AppKit
import CoreGraphics
import Foundation

/// Free-space trackpad three-finger drag (Apple Accessibility / BTT-style).
///
/// Place three fingers and move to hold a left-button drag — selects text, moves files,
/// resizes via window edges. A short stationary chord is reported as a tap (middle-click).
///
/// Finger travel is converted to cursor motion; we post `leftMouseDown` / `Dragged` / `Up`
/// because MultitouchSupport registration does not activate system three-finger drag.
final class ThreeFingerDragRecognizer: @unchecked Sendable {
    enum Outcome: Equatable {
        case none
        /// Left button down at `at`; `cursor` is the first drag position (may differ if the
        /// commit frame already moved past the threshold).
        case dragBegan(downAt: CGPoint, cursor: CGPoint)
        case dragMoved(to: CGPoint)
        case dragEnded(at: CGPoint)
        /// Stationary three-finger chord lifted — candidate for middle-click.
        case tap
    }

    private enum Phase: Equatable {
        case idle
        case tracking
        case dragging
    }

    private var phase: Phase = .idle
    private var startCentroid: CGPoint = .zero
    private var lastCentroid: CGPoint = .zero
    private var cursor: CGPoint = .zero
    private var sessionStart: Date?
    private var maxTravel: CGFloat = 0
    private var peakFingers = 0
    private let lock = NSLock()

    /// Normalized travel before committing to drag (vs tap).
    private static let commitTravel: CGFloat = 0.028
    /// Max duration for a tap (seconds).
    private static let tapMaxDuration: TimeInterval = 0.40
    /// Base screen points per full-pad unit of centroid travel (× sensitivity).
    private static let basePixelsPerUnit: CGFloat = 1_350

    /// True while a synthetic left-button drag is held.
    var isDragging: Bool {
        lock.lock()
        defer { lock.unlock() }
        return phase == .dragging
    }

    func process(frame: TouchFrame, sensitivity: Int) -> Outcome {
        lock.lock()
        defer { lock.unlock() }

        let live = frame.touches.filter { $0.phase != .ended && $0.phase != .cancelled }
        let scale = Self.pixelsPerUnit(sensitivity: sensitivity)

        if live.count >= 3 {
            let centroid = Self.centroid(live)
            peakFingers = max(peakFingers, live.count)

            switch phase {
            case .idle:
                phase = .tracking
                startCentroid = centroid
                lastCentroid = centroid
                sessionStart = frame.timestamp
                maxTravel = 0
                cursor = Self.currentMouseLocation()
                return .none

            case .tracking:
                lastCentroid = centroid
                let travel = hypot(centroid.x - startCentroid.x, centroid.y - startCentroid.y)
                maxTravel = max(maxTravel, travel)
                guard travel >= Self.commitTravel else { return .none }

                phase = .dragging
                let downAt = Self.currentMouseLocation()
                cursor = downAt
                // Include all travel from session start so selection starts immediately.
                applyDelta(from: startCentroid, to: centroid, scale: scale)
                lastCentroid = centroid
                Log.info(
                    .gesture,
                    "3F drag BEGIN travel=\(String(format: "%.3f", travel)) " +
                    "down=(\(Int(downAt.x)),\(Int(downAt.y))) " +
                    "cursor=(\(Int(cursor.x)),\(Int(cursor.y)))"
                )
                return .dragBegan(downAt: downAt, cursor: cursor)

            case .dragging:
                applyDelta(from: lastCentroid, to: centroid, scale: scale)
                lastCentroid = centroid
                return .dragMoved(to: cursor)
            }
        }

        return finishUnlocked(now: frame.timestamp)
    }

    func reset() {
        lock.lock()
        defer { lock.unlock() }
        if phase == .dragging {
            Log.warn(.gesture, "3F drag reset while active — caller should end mouse button")
        }
        clearUnlocked()
    }

    // MARK: - Private

    private func finishUnlocked(now: Date) -> Outcome {
        switch phase {
        case .idle:
            return .none

        case .dragging:
            let end = cursor
            clearUnlocked()
            Log.info(.gesture, "3F drag END at (\(Int(end.x)),\(Int(end.y)))")
            return .dragEnded(at: end)

        case .tracking:
            let duration = now.timeIntervalSince(sessionStart ?? now)
            let travel = maxTravel
            let wasTap = peakFingers >= 3
                && travel < Self.commitTravel
                && duration < Self.tapMaxDuration
            clearUnlocked()
            if wasTap {
                Log.info(
                    .gesture,
                    "3F tap travel=\(String(format: "%.3f", travel)) " +
                    "dur=\(String(format: "%.3f", duration))s"
                )
                return .tap
            }
            return .none
        }
    }

    private func clearUnlocked() {
        phase = .idle
        startCentroid = .zero
        lastCentroid = .zero
        sessionStart = nil
        maxTravel = 0
        peakFingers = 0
    }

    private func applyDelta(from previous: CGPoint, to current: CGPoint, scale: CGFloat) {
        let dx = (current.x - previous.x) * scale
        // Trackpad norm Y increases toward top of pad; Quartz Y increases downward.
        let dy = -(current.y - previous.y) * scale
        if abs(dx) < 0.01, abs(dy) < 0.01 { return }
        cursor = CGPoint(x: cursor.x + dx, y: cursor.y + dy)
        cursor = Self.clampToDisplays(cursor)
    }

    private static func pixelsPerUnit(sensitivity: Int) -> CGFloat {
        let s = max(-2, min(2, sensitivity))
        return basePixelsPerUnit * (1.0 + CGFloat(s) * 0.12)
    }

    private static func centroid(_ touches: [TouchPoint]) -> CGPoint {
        let n = CGFloat(touches.count)
        let x = touches.reduce(0) { $0 + $1.normalized.x } / n
        let y = touches.reduce(0) { $0 + $1.normalized.y } / n
        return CGPoint(x: x, y: y)
    }

    private static func currentMouseLocation() -> CGPoint {
        CGEvent(source: nil)?.location ?? .zero
    }

    /// Keep synthetic cursor on the global desktop (Quartz coords).
    private static func clampToDisplays(_ p: CGPoint) -> CGPoint {
        var union = CGRect.null
        let maxAppKitY = NSScreen.screens.map(\.frame.maxY).max() ?? 0
        for screen in NSScreen.screens {
            let f = screen.frame
            let quartz = CGRect(
                x: f.origin.x,
                y: maxAppKitY - f.origin.y - f.height,
                width: f.width,
                height: f.height
            )
            union = union.isNull ? quartz : union.union(quartz)
        }
        guard !union.isNull else { return p }
        return CGPoint(
            x: min(max(p.x, union.minX), union.maxX - 1),
            y: min(max(p.y, union.minY), union.maxY - 1)
        )
    }
}
