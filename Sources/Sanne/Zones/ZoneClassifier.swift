import AppKit
import ApplicationServices

enum CursorZone: String, Equatable {
    case titlebar
    case dock
    case menubar
    case free
}

@MainActor
enum ZoneClassifier {
    static func zone(at appKitPoint: CGPoint = NSEvent.mouseLocation) -> CursorZone {
        if isMenubar(appKitPoint) { return .menubar }
        if isDock(appKitPoint) { return .dock }
        if isTitlebar(appKitPoint) { return .titlebar }
        return .free
    }

    static func isTitlebar(_ appKitPoint: CGPoint) -> Bool {
        guard Permissions.isAccessibilityTrusted else { return false }
        let ax = LayoutGeometry.appKitPointToAX(appKitPoint)
        var element: AXUIElement?
        let err = AXUIElementCopyElementAtPosition(
            AXUIElementCreateSystemWide(),
            Float(ax.x),
            Float(ax.y),
            &element
        )
        guard err == .success, let element else { return false }

        // Role walk
        var cursor: AXUIElement? = element
        for _ in 0..<12 {
            guard let c = cursor else { break }
            let role = AXQuery.stringAttr(c, kAXRoleAttribute as String) ?? ""
            let sub = AXQuery.stringAttr(c, kAXSubroleAttribute as String) ?? ""
            if role == "AXTitleBar"
                || sub == "AXCloseButton"
                || sub == "AXMinimizeButton"
                || sub == "AXZoomButton"
            {
                return true
            }
            var parent: CFTypeRef?
            if AXUIElementCopyAttributeValue(c, kAXParentAttribute as CFString, &parent) == .success,
               let parent
            {
                cursor = (parent as! AXUIElement)
            } else {
                break
            }
        }

        // Geometric strip
        if let window = AXQuery.window(from: element), let frame = WindowManager.shared.frame(of: window) {
            let strip: CGFloat = 52
            let inX = ax.x >= frame.minX && ax.x <= frame.maxX
            let inY = ax.y >= frame.minY && ax.y <= frame.minY + strip
            return inX && inY
        }
        return false
    }

    private static func isMenubar(_ p: CGPoint) -> Bool {
        guard let screen = LayoutGeometry.screenForAppKitPoint(p) else { return false }
        let menuHeight = screen.frame.maxY - screen.visibleFrame.maxY
        return p.y >= screen.frame.maxY - menuHeight
    }

    private static func isDock(_ p: CGPoint) -> Bool {
        guard let screen = LayoutGeometry.screenForAppKitPoint(p) else { return false }
        let visible = screen.visibleFrame
        let frame = screen.frame
        // Bottom dock
        if visible.minY > frame.minY + 1 {
            return p.y < visible.minY
        }
        // Left dock
        if visible.minX > frame.minX + 1 {
            return p.x < visible.minX
        }
        // Right dock
        if visible.maxX < frame.maxX - 1 {
            return p.x > visible.maxX
        }
        return false
    }
}
