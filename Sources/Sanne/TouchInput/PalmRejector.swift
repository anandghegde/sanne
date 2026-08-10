import Foundation

/// Filters resting-palm contacts on Magic Mouse.
/// Kept lenient — false rejects kill tap-to-click entirely.
struct PalmRejector {
    /// Only reject single huge contacts that look like a whole palm.
    var majorAxisThreshold: Float = 8.0

    func accepts(_ touches: [TouchPoint]) -> Bool {
        if touches.isEmpty { return true }
        if touches.count >= 2 { return true }
        guard let t = touches.first else { return true }
        // majorAxis is often ~0.1–2.0 when decoded correctly; garbage high values
        // should not block if position looks like a fingertip (near surface coords).
        if t.majorAxis > majorAxisThreshold, t.majorAxis.isFinite {
            return false
        }
        return true
    }
}
