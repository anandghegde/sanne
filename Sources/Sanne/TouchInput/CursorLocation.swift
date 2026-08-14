import CoreGraphics
import Foundation

/// Reused `CGEvent` probe so the Multitouch callback does not allocate one per frame.
enum CursorLocation {
    private static let lock = NSLock()
    private static var probe: CGEvent? = CGEvent(source: nil)

    static func current() -> CGPoint {
        lock.lock()
        defer { lock.unlock() }
        if probe == nil {
            probe = CGEvent(source: nil)
        }
        // A NULL-source event samples the cursor at creation. Recreate when we need a
        // fresh sample; keep the last event as fallback so a failed create is not `.zero`.
        if let fresh = CGEvent(source: nil) {
            probe = fresh
            return fresh.location
        }
        return probe?.location ?? .zero
    }
}
