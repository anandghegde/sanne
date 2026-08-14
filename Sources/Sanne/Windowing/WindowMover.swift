import AppKit
import ApplicationServices

enum WindowMoverKind: Equatable {
    case move
    case resize
}

/// One begin / update / end session for continuous AX window move or resize.
/// Used by modifier-drag and Magic Mouse top-edge.
@MainActor
final class WindowMover {
    static let shared = WindowMover()

    private struct EdgeSet: OptionSet {
        let rawValue: Int
        static let left = EdgeSet(rawValue: 1 << 0)
        static let right = EdgeSet(rawValue: 1 << 1)
        static let top = EdgeSet(rawValue: 1 << 2)
        static let bottom = EdgeSet(rawValue: 1 << 3)
    }

    private var window: AXUIElement?
    private var startCursorAppKit: CGPoint = .zero
    private var startFrameAX: CGRect = .zero
    private var active = false
    private var kind: WindowMoverKind = .move
    private var resizeEdges: EdgeSet = []

    private init() {}

    var isActive: Bool { active }

    /// Capture `window` (or the window under the cursor) and begin tracking.
    /// Returns false if none / own UI.
    @discardableResult
    func begin(kind: WindowMoverKind = .move, window explicit: AXUIElement? = nil, haptics: Bool = false) -> Bool {
        end()
        guard Permissions.isAccessibilityTrusted else { return false }
        let point = NSEvent.mouseLocation
        guard let w = explicit ?? WindowManager.shared.windowAt(appKitPoint: point),
              let frame = WindowManager.shared.frame(of: w)
        else {
            Log.debug(.window, "WindowMover: no window")
            return false
        }
        var pid: pid_t = 0
        AXUIElementGetPid(w, &pid)
        if pid == ProcessInfo.processInfo.processIdentifier { return false }

        window = w
        startCursorAppKit = point
        startFrameAX = frame
        self.kind = kind
        resizeEdges = kind == .resize ? Self.nearestEdges(cursorAppKit: point, frameAX: frame) : []
        active = true
        Haptics.fire(enabled: haptics)
        Log.info(.window, "WindowMover begin \(kind == .resize ? "resize" : "move") at (\(Int(point.x)),\(Int(point.y)))")
        return true
    }

    func update() {
        guard active, let window else { return }
        let point = NSEvent.mouseLocation
        let dxApp = point.x - startCursorAppKit.x
        let dyApp = point.y - startCursorAppKit.y
        let dX = dxApp
        let dY = -dyApp
        var next = startFrameAX
        switch kind {
        case .move:
            next.origin.x = startFrameAX.origin.x + dX
            next.origin.y = startFrameAX.origin.y + dY
        case .resize:
            if resizeEdges.contains(.left) {
                let newX = startFrameAX.origin.x + dX
                let maxX = startFrameAX.maxX - 120
                next.origin.x = min(newX, maxX)
                next.size.width = startFrameAX.maxX - next.origin.x
            }
            if resizeEdges.contains(.right) {
                next.size.width = max(120, startFrameAX.width + dX)
            }
            if resizeEdges.contains(.top) {
                let newY = startFrameAX.origin.y + dY
                let maxY = startFrameAX.maxY - 80
                next.origin.y = min(newY, maxY)
                next.size.height = startFrameAX.maxY - next.origin.y
            }
            if resizeEdges.contains(.bottom) {
                next.size.height = max(80, startFrameAX.height + dY)
            }
        }
        _ = WindowManager.shared.setFrame(window, next, mode: .live)
    }

    func end() {
        if active {
            Log.debug(.window, "WindowMover end")
        }
        window = nil
        active = false
        kind = .move
        resizeEdges = []
        startCursorAppKit = .zero
        startFrameAX = .zero
    }

    private static func nearestEdges(cursorAppKit: CGPoint, frameAX: CGRect) -> EdgeSet {
        let frameAppKit = LayoutGeometry.axToAppKit(frameAX)
        let relX = frameAppKit.width > 0 ? (cursorAppKit.x - frameAppKit.minX) / frameAppKit.width : 0.5
        let relY = frameAppKit.height > 0 ? (cursorAppKit.y - frameAppKit.minY) / frameAppKit.height : 0.5

        var edges: EdgeSet = []
        if relX < 0.33 { edges.insert(.left) }
        else if relX > 0.67 { edges.insert(.right) }
        if relY < 0.33 { edges.insert(.bottom) }
        else if relY > 0.67 { edges.insert(.top) }
        if edges.isEmpty {
            edges = [.right, .bottom]
        }
        return edges
    }
}
