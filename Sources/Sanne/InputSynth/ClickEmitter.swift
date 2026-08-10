import CoreGraphics
import Foundation

enum ClickButton: CustomStringConvertible {
    case left, right, middle

    var description: String {
        switch self {
        case .left: return "left"
        case .right: return "right"
        case .middle: return "middle"
        }
    }

    var cg: CGMouseButton {
        switch self {
        case .left: return .left
        case .right: return .right
        case .middle: return .center
        }
    }

    var down: CGEventType {
        switch self {
        case .left: return .leftMouseDown
        case .right: return .rightMouseDown
        case .middle: return .otherMouseDown
        }
    }

    var up: CGEventType {
        switch self {
        case .left: return .leftMouseUp
        case .right: return .rightMouseUp
        case .middle: return .otherMouseUp
        }
    }
}

enum ClickEmitter {
    /// `clickCount` is the macOS multi-click index (1 = single, 2 = double, 3 = triple).
    /// Finder/text selection only treat successive events as multi-click when this is set correctly.
    static func click(_ button: ClickButton, at point: CGPoint? = nil, clickCount: Int = 1) {
        let loc = point ?? currentMouseLocation()
        let count = Int64(max(1, min(3, clickCount)))
        Log.info(
            .click,
            "click \(button)×\(count) at (\(Int(loc.x)), \(Int(loc.y))) axTrusted=\(Permissions.isAccessibilityTrusted)"
        )

        let source = CGEventSource(stateID: .combinedSessionState)
        guard
            let down = CGEvent(mouseEventSource: source, mouseType: button.down, mouseCursorPosition: loc, mouseButton: button.cg),
            let up = CGEvent(mouseEventSource: source, mouseType: button.up, mouseCursorPosition: loc, mouseButton: button.cg)
        else {
            Log.error(.click, "failed to create CGEvent for \(button)")
            return
        }

        configure(down, button: button, clickState: count)
        configure(up, button: button, clickState: count)
        down.post(tap: .cghidEventTap)
        usleep(12_000)
        up.post(tap: .cghidEventTap)
        Log.info(.click, "posted \(button)×\(count) down+up via cghidEventTap")
    }

    static func mouseDown(_ button: ClickButton, at point: CGPoint? = nil) {
        let loc = point ?? currentMouseLocation()
        Log.info(.click, "mouseDown \(button) at (\(Int(loc.x)), \(Int(loc.y)))")
        let source = CGEventSource(stateID: .combinedSessionState)
        guard let down = CGEvent(mouseEventSource: source, mouseType: button.down, mouseCursorPosition: loc, mouseButton: button.cg) else {
            Log.error(.click, "mouseDown create failed")
            return
        }
        configure(down, button: button, clickState: 1)
        down.post(tap: .cghidEventTap)
    }

    static func mouseUp(_ button: ClickButton, at point: CGPoint? = nil) {
        let loc = point ?? currentMouseLocation()
        Log.info(.click, "mouseUp \(button) at (\(Int(loc.x)), \(Int(loc.y)))")
        let source = CGEventSource(stateID: .combinedSessionState)
        guard let up = CGEvent(mouseEventSource: source, mouseType: button.up, mouseCursorPosition: loc, mouseButton: button.cg) else {
            Log.error(.click, "mouseUp create failed")
            return
        }
        configure(up, button: button, clickState: 1)
        up.post(tap: .cghidEventTap)
    }

    /// Synthetic drag move while a button is held (needed because CGEvent mouseDown
    /// does not always couple to real HID movement for OS drag tracking).
    static func mouseDragged(_ button: ClickButton = .left, at point: CGPoint? = nil) {
        let loc = point ?? currentMouseLocation()
        let source = CGEventSource(stateID: .combinedSessionState)
        let type: CGEventType = button == .left ? .leftMouseDragged
            : button == .right ? .rightMouseDragged
            : .otherMouseDragged
        guard let drag = CGEvent(
            mouseEventSource: source,
            mouseType: type,
            mouseCursorPosition: loc,
            mouseButton: button.cg
        ) else {
            Log.error(.click, "mouseDragged create failed")
            return
        }
        configure(drag, button: button, clickState: 1)
        drag.post(tap: .cghidEventTap)
    }

    private static func configure(_ event: CGEvent, button: ClickButton, clickState: Int64) {
        event.setIntegerValueField(.mouseEventClickState, value: clickState)
        if button == .middle {
            event.setIntegerValueField(.mouseEventButtonNumber, value: 2)
        }
    }

    /// Mouse button 3 = Back, 4 = Forward (standard browser side buttons / “swipe between pages”).
    /// More reliable than ⌘[ / ⌘] in Chrome/Safari when Accessibility focus is ambiguous.
    static func browserNavigate(back: Bool) {
        let buttonNumber: Int64 = back ? 3 : 4
        let loc = currentMouseLocation()
        let source = CGEventSource(stateID: .combinedSessionState)
        // CGMouseButton only has left/right/center; other buttons use .center + buttonNumber field.
        guard
            let down = CGEvent(
                mouseEventSource: source,
                mouseType: .otherMouseDown,
                mouseCursorPosition: loc,
                mouseButton: .center
            ),
            let up = CGEvent(
                mouseEventSource: source,
                mouseType: .otherMouseUp,
                mouseCursorPosition: loc,
                mouseButton: .center
            )
        else {
            Log.error(.click, "failed to create browser navigate button=\(buttonNumber)")
            return
        }
        down.setIntegerValueField(.mouseEventButtonNumber, value: buttonNumber)
        up.setIntegerValueField(.mouseEventButtonNumber, value: buttonNumber)
        down.setIntegerValueField(.mouseEventClickState, value: 1)
        up.setIntegerValueField(.mouseEventClickState, value: 1)
        down.post(tap: .cghidEventTap)
        usleep(12_000)
        up.post(tap: .cghidEventTap)
        Log.info(.click, "posted mouse button \(buttonNumber) (\(back ? "back" : "forward"))")
    }

    private static func currentMouseLocation() -> CGPoint {
        if let e = CGEvent(source: nil) {
            return e.location
        }
        return .zero
    }
}
