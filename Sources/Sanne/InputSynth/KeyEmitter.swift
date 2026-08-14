import CoreGraphics
import Foundation

/// Synthetic keystrokes via CGEvent (Accessibility-trusted process).
enum KeyEmitter {
    private static let queue = DispatchQueue(label: "app.sanne.key", qos: .userInteractive)

    static func post(keyCode: CGKeyCode, flags: CGEventFlags = [], tap: CGEventTapLocation = .cghidEventTap) {
        let source = CGEventSource(stateID: .combinedSessionState)
        guard
            let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
            let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        else {
            Log.error(.key, "KeyEmitter failed keyCode=\(keyCode)")
            return
        }
        down.flags = flags
        up.flags = flags
        queue.async {
            down.post(tap: tap)
            usleep(8_000)
            up.post(tap: tap)
            Log.info(.key, "key keyCode=\(keyCode) flags=\(flags.rawValue)")
        }
    }

    // Common virtual key codes (US layout; fine for system shortcuts).
    enum Code {
        static let n: CGKeyCode = 45
        static let h: CGKeyCode = 4
        static let q: CGKeyCode = 12
        static let grave: CGKeyCode = 50 // ` — next window
        static let m: CGKeyCode = 46
        static let tab: CGKeyCode = 48
    }

    static func commandN() {
        post(keyCode: Code.n, flags: .maskCommand)
    }

    static func commandQ() {
        post(keyCode: Code.q, flags: .maskCommand)
    }

    /// Cycle windows of frontmost app (⌘`).
    static func nextWindow() {
        post(keyCode: Code.grave, flags: .maskCommand)
    }

    /// Previous window (⌘⇧`).
    static func previousWindow() {
        post(keyCode: Code.grave, flags: [.maskCommand, .maskShift])
    }

    /// Hide others (⌥⌘H).
    static func hideOthers() {
        post(keyCode: Code.h, flags: [.maskCommand, .maskAlternate])
    }

    // Arrow keys
    enum Arrow {
        static let left: CGKeyCode = 123
        static let right: CGKeyCode = 124
        static let down: CGKeyCode = 125
        static let up: CGKeyCode = 126
    }

    /// Mission Control (⌃↑) — default system shortcut.
    static func missionControl() {
        post(keyCode: Arrow.up, flags: .maskControl)
        Log.info(.key, "→ Mission Control")
    }

    /// Application windows / App Exposé (⌃↓).
    static func appExpose() {
        post(keyCode: Arrow.down, flags: .maskControl)
        Log.info(.key, "→ App Exposé")
    }

    /// Move left a Space (⌃←).
    static func spaceLeft() {
        post(keyCode: Arrow.left, flags: .maskControl)
        Log.info(.key, "→ Space left")
    }

    /// Move right a Space (⌃→).
    static func spaceRight() {
        post(keyCode: Arrow.right, flags: .maskControl)
        Log.info(.key, "→ Space right")
    }

    /// Browser / history back via mouse button 3 (same as a mouse “Back” button).
    /// More reliable in Chrome/Safari than ⌘[ alone. Remap the gesture to ⌘[ if needed.
    static func browserBack() {
        ClickEmitter.browserNavigate(back: true)
        Log.info(.key, "→ browser back")
    }

    /// Browser / history forward via mouse button 4.
    static func browserForward() {
        ClickEmitter.browserNavigate(back: false)
        Log.info(.key, "→ browser forward")
    }
}
