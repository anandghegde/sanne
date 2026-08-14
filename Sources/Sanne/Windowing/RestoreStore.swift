import ApplicationServices
import CoreGraphics
import Darwin
import Foundation

/// Window identity for restore / last-layout. `pid + CGWindowNumber` so a Chrome tab title
/// change does not orphan the stored frame ([TECHNICAL_DESIGN.md](../../TECHNICAL_DESIGN.md) §10.5).
struct WindowIdentity: Hashable {
    var pid: pid_t
    var windowNumber: CGWindowID
}

enum WindowIdentityResolver {
    /// Private AX helper: AXUIElement → CGWindowID.
    private static let getWindow: (@convention(c) (AXUIElement, UnsafeMutablePointer<CGWindowID>) -> AXError)? = {
        let handle = dlopen("/System/Library/Frameworks/ApplicationServices.framework/ApplicationServices", RTLD_LAZY)
        guard let handle,
              let sym = dlsym(handle, "_AXUIElementGetWindow")
        else { return nil }
        return unsafeBitCast(sym, to: (@convention(c) (AXUIElement, UnsafeMutablePointer<CGWindowID>) -> AXError).self)
    }()

    static func identity(of window: AXUIElement) -> WindowIdentity? {
        var pid: pid_t = 0
        AXUIElementGetPid(window, &pid)
        guard pid != 0 else { return nil }

        var number: CGWindowID = 0
        if let getWindow, getWindow(window, &number) == .success, number != 0 {
            return WindowIdentity(pid: pid, windowNumber: number)
        }

        // Fallback: match pid + AX frame against the CG window list.
        guard let frame = axFrame(of: window),
              let match = cgWindowNumber(pid: pid, axFrame: frame)
        else { return nil }
        return WindowIdentity(pid: pid, windowNumber: match)
    }

    private static func axFrame(of window: AXUIElement) -> CGRect? {
        var posRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &posRef) == .success,
              AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeRef) == .success,
              let posVal = posRef, let sizeVal = sizeRef
        else { return nil }
        var position = CGPoint.zero
        var size = CGSize.zero
        if CFGetTypeID(posVal) == AXValueGetTypeID() {
            AXValueGetValue(posVal as! AXValue, .cgPoint, &position)
        }
        if CFGetTypeID(sizeVal) == AXValueGetTypeID() {
            AXValueGetValue(sizeVal as! AXValue, .cgSize, &size)
        }
        return CGRect(origin: position, size: size)
    }

    private static func cgWindowNumber(pid: pid_t, axFrame: CGRect) -> CGWindowID? {
        guard let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]]
        else { return nil }
        var best: (CGWindowID, CGFloat)?
        for entry in info {
            guard let owner = entry[kCGWindowOwnerPID as String] as? pid_t, owner == pid,
                  let number = entry[kCGWindowNumber as String] as? CGWindowID,
                  let bounds = entry[kCGWindowBounds as String] as? [String: CGFloat]
            else { continue }
            let cg = CGRect(
                x: bounds["X"] ?? 0,
                y: bounds["Y"] ?? 0,
                width: bounds["Width"] ?? 0,
                height: bounds["Height"] ?? 0
            )
            let dx = abs(cg.midX - axFrame.midX)
            let dy = abs(cg.midY - axFrame.midY)
            let score = dx + dy
            if best == nil || score < best!.1 {
                best = (number, score)
            }
        }
        return best?.0
    }
}

final class RestoreStore: @unchecked Sendable {
    private var frames: [WindowIdentity: CGRect] = [:]
    private let lock = NSLock()

    func remember(_ id: WindowIdentity, frame: CGRect) {
        lock.lock()
        if frames[id] == nil {
            frames[id] = frame
        }
        lock.unlock()
    }

    func peek(_ id: WindowIdentity) -> CGRect? {
        lock.lock()
        defer { lock.unlock() }
        return frames[id]
    }

    func restore(_ id: WindowIdentity) -> CGRect? {
        lock.lock()
        defer { lock.unlock() }
        let f = frames[id]
        frames[id] = nil
        return f
    }

    func clear(_ id: WindowIdentity) {
        lock.lock()
        frames[id] = nil
        lock.unlock()
    }
}
