import AppKit
import Foundation

/// Hold Option at launch to skip the user config and load Sanne Standard in memory.
/// The on-disk file is not overwritten.
enum SafeMode {
    /// Evaluated once at first access. Tests may override via `force`.
    static var isActive: Bool {
        if let force { return force }
        return NSEvent.modifierFlags.contains(.option)
    }

    /// `nil` = use the real Option key. Set only from tests.
    static var force: Bool?
}
