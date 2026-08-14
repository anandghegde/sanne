import CoreGraphics
import Foundation

/// Top-edge 2F move / 3F resize. Calls `WindowMover`; does not duplicate geometry.
enum MMWindowMove {
    static let topEdgeMinY: Float = 0.58
    static let cursorMin: CGFloat = 6
    static let maxSurface: Float = 0.055

    static func kind(fingerCount: Int, snapshot: RuntimeSnapshot) -> WindowMoverKind? {
        if fingerCount == 2, snapshot.slotOn(GestureSlots.ID.mm2fTopEdgeMove) { return .move }
        if fingerCount == 3, snapshot.slotOn(GestureSlots.ID.mm3fTopEdgeResize) { return .resize }
        return nil
    }

    static func shouldAbandonForSwipe(travel: Float) -> Bool {
        travel > maxSurface * 1.6
    }

    static func shouldBegin(cursorDist: CGFloat, travel: Float, startY: Float) -> Bool {
        startY >= topEdgeMinY && cursorDist >= cursorMin && travel < maxSurface
    }
}
