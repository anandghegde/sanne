import ApplicationServices
import Foundation

/// Shared AX parent walk used by zone classification and window capture.
enum AXQuery {
    static var ownPID: pid_t { ProcessInfo.processInfo.processIdentifier }

    static func stringAttr(_ el: AXUIElement, _ attr: String) -> String? {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, attr as CFString, &ref) == .success else { return nil }
        return ref as? String
    }

    /// Walk parents for a window role, skipping Sanne's own PID.
    static func windowByWalkingParents(from element: AXUIElement, maxHops: Int = 10) -> AXUIElement? {
        var cursor: AXUIElement? = element
        for _ in 0..<maxHops {
            guard let c = cursor else { break }
            if stringAttr(c, kAXRoleAttribute as String) == (kAXWindowRole as String) {
                return skipOwn(c)
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
        return nil
    }

    static func windowAttribute(of element: AXUIElement) -> AXUIElement? {
        var winRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXWindowAttribute as CFString, &winRef) == .success,
              let winRef
        else { return nil }
        return skipOwn(winRef as! AXUIElement)
    }

    /// Window under `element`: `AXWindow` attribute, then parent walk.
    static func window(from element: AXUIElement) -> AXUIElement? {
        if let win = windowAttribute(of: element) { return win }
        return windowByWalkingParents(from: element)
    }

    static func skipOwn(_ window: AXUIElement) -> AXUIElement? {
        var pid: pid_t = 0
        AXUIElementGetPid(window, &pid)
        if pid == ownPID { return nil }
        return window
    }

    static func isOwn(_ element: AXUIElement) -> Bool {
        var pid: pid_t = 0
        AXUIElementGetPid(element, &pid)
        return pid == ownPID
    }
}
