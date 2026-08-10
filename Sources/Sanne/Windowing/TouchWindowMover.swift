import AppKit
import ApplicationServices

/// Continuous AX window move driven by cursor delta (Magic Mouse top-edge 2-finger drag).
@MainActor
final class TouchWindowMover {
    static let shared = TouchWindowMover()

    private var window: AXUIElement?
    private var startCursorAppKit: CGPoint = .zero
    private var startFrameAX: CGRect = .zero
    private var active = false

    private init() {}

    var isActive: Bool { active }

    /// Capture window under cursor and begin tracking. Returns false if none / own UI.
    @discardableResult
    func begin(haptics: Bool = false) -> Bool {
        end()
        guard Permissions.isAccessibilityTrusted else { return false }
        let point = NSEvent.mouseLocation
        guard let w = WindowManager.shared.windowAt(appKitPoint: point),
              let frame = WindowManager.shared.frame(of: w)
        else {
            Log.debug(.window, "TouchWindowMover: no window under cursor")
            return false
        }
        var pid: pid_t = 0
        AXUIElementGetPid(w, &pid)
        if pid == ProcessInfo.processInfo.processIdentifier { return false }

        window = w
        startCursorAppKit = point
        startFrameAX = frame
        active = true
        Haptics.fire(enabled: haptics)
        Log.info(.window, "TouchWindowMover begin at (\(Int(point.x)),\(Int(point.y)))")
        return true
    }

    func update() {
        guard active, let window else { return }
        let point = NSEvent.mouseLocation
        let dxApp = point.x - startCursorAppKit.x
        let dyApp = point.y - startCursorAppKit.y
        // AX: origin top-left, Y increases downward.
        var next = startFrameAX
        next.origin.x = startFrameAX.origin.x + dxApp
        next.origin.y = startFrameAX.origin.y - dyApp
        _ = WindowManager.shared.setFrame(window, next)
    }

    func end() {
        if active {
            Log.debug(.window, "TouchWindowMover end")
        }
        window = nil
        active = false
        startCursorAppKit = .zero
        startFrameAX = .zero
    }
}
