import CoreGraphics
import Foundation
@testable import SanneKit

/// Minimal synthetic touch frames for recognizer state-machine tests.
enum TouchFrameFixtures {
    static func frame(
        at time: Date,
        touches: [(id: Int, x: CGFloat, y: CGFloat, phase: TouchPhase)]
    ) -> TouchFrame {
        TouchFrame(
            timestamp: time.timeIntervalSinceReferenceDate,
            deviceID: 1,
            deviceKind: .builtInTrackpad,
            touches: touches.map { t in
                TouchPoint(
                    id: t.id,
                    normalized: CGPoint(x: t.x, y: t.y),
                    majorAxis: 0.05,
                    minorAxis: 0.05,
                    state: 0,
                    phase: t.phase
                )
            }
        )
    }

    static func empty(at time: Date) -> TouchFrame {
        frame(at: time, touches: [])
    }
}
