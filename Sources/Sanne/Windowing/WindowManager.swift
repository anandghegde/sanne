import AppKit
import ApplicationServices

@MainActor
final class WindowManager {
    static let shared = WindowManager()
    let restore = RestoreStore()
    /// Last applied snap layout per window — second same layout restores pre-snap frame.
    private var lastLayout: [WindowIdentity: WindowLayout] = [:]

    func snapWindowUnderCursor(layout: WindowLayout, gap: CGFloat, showPreviewOnly: Bool = false) -> Bool {
        guard Permissions.isAccessibilityTrusted else { return false }
        let appKitPoint = NSEvent.mouseLocation
        guard let window = windowAt(appKitPoint: appKitPoint) else {
            Log.error(.window, "No window under cursor")
            return false
        }
        return snap(window: window, layout: layout, gap: gap, showPreviewOnly: showPreviewOnly)
    }

    /// Snap a window captured at gesture start (preferred over cursor-at-commit).
    func snap(window: AXUIElement, layout: WindowLayout, gap: CGFloat) -> Bool {
        snap(window: window, layout: layout, gap: gap, showPreviewOnly: false, allowRestoreOnRepeat: true)
    }

    func snapFocused(layout: WindowLayout, gap: CGFloat) -> Bool {
        guard let window = focusedWindow() else { return false }
        return snap(window: window, layout: layout, gap: gap, showPreviewOnly: false)
    }

    /// Cycle left-side layouts on the focused window (half → third → two-thirds).
    func cycleLeftFocused(gap: CGFloat, enableThirds: Bool) -> Bool {
        guard let window = focusedWindow() else { return false }
        let layout: WindowLayout
        if enableThirds {
            layout = LayoutGeometry.nextLeftLayout(after: lastAppliedLayout(for: window))
        } else {
            layout = .leftHalf
        }
        // Bypass restore-on-same so cycle advances instead of undoing.
        return snap(window: window, layout: layout, gap: gap, showPreviewOnly: false, allowRestoreOnRepeat: !enableThirds)
    }

    /// Cycle right-side layouts on the focused window.
    func cycleRightFocused(gap: CGFloat, enableThirds: Bool) -> Bool {
        guard let window = focusedWindow() else { return false }
        let layout: WindowLayout
        if enableThirds {
            layout = LayoutGeometry.nextRightLayout(after: lastAppliedLayout(for: window))
        } else {
            layout = .rightHalf
        }
        return snap(window: window, layout: layout, gap: gap, showPreviewOnly: false, allowRestoreOnRepeat: !enableThirds)
    }

    /// Move focused window to the adjacent display (left = −1, right = +1), preserving relative size/position.
    @discardableResult
    func moveFocusedToAdjacentDisplay(direction: Int, gap: CGFloat) -> Bool {
        guard let window = focusedWindow() else { return false }
        return moveToAdjacentDisplay(window: window, direction: direction, gap: gap)
    }

    @discardableResult
    func moveToAdjacentDisplay(window: AXUIElement, direction: Int, gap: CGFloat) -> Bool {
        guard Permissions.isAccessibilityTrusted else { return false }
        guard let current = frame(of: window) else {
            Log.error(.window, "move display: no frame")
            return false
        }
        guard let fromScreen = LayoutGeometry.screenContainingAXFrame(current) else {
            Log.error(.window, "move display: no source screen")
            return false
        }
        guard let toScreen = LayoutGeometry.adjacentScreen(from: fromScreen, direction: direction) else {
            Log.info(.window, "move display: no neighbor dir=\(direction)")
            return false
        }

        let fromVis = fromScreen.visibleFrame
        let toVis = toScreen.visibleFrame
        // Relative position within source visible frame (AppKit space for visibleFrame).
        let primaryH = NSScreen.screens.first?.frame.height ?? 0
        let currentAppKit = CGRect(
            x: current.minX,
            y: primaryH - current.maxY,
            width: current.width,
            height: current.height
        )

        let relX = fromVis.width > 0 ? (currentAppKit.minX - fromVis.minX) / fromVis.width : 0
        let relY = fromVis.height > 0 ? (currentAppKit.minY - fromVis.minY) / fromVis.height : 0
        let relW = fromVis.width > 0 ? currentAppKit.width / fromVis.width : 1
        let relH = fromVis.height > 0 ? currentAppKit.height / fromVis.height : 1

        let newW = min(max(relW * toVis.width, 200), toVis.width - gap * 2)
        let newH = min(max(relH * toVis.height, 120), toVis.height - gap * 2)
        // Clamp into destination visible frame.
        let newX = min(max(toVis.minX + relX * toVis.width, toVis.minX + gap), toVis.maxX - newW - gap)
        let newY = min(max(toVis.minY + relY * toVis.height, toVis.minY + gap), toVis.maxY - newH - gap)

        let targetAppKit = CGRect(x: newX, y: newY, width: newW, height: newH)
        let targetAX = LayoutGeometry.appKitToAX(targetAppKit)

        var pid: pid_t = 0
        AXUIElementGetPid(window, &pid)
        let title = stringAttr(window, kAXTitleAttribute as String) ?? ""
        let id = WindowIdentity(pid: pid, title: title)
        restore.remember(id, frame: current)
        lastLayout[id] = nil

        let ok = setFrame(window, targetAX)
        Log.info(
            .window,
            "move display dir=\(direction) title=\(title.prefix(40)) " +
            "→ (\(Int(targetAX.minX)),\(Int(targetAX.minY)) \(Int(targetAX.width))×\(Int(targetAX.height))) ok=\(ok)"
        )
        return ok
    }

    func focusedWindow() -> AXUIElement? {
        guard Permissions.isAccessibilityTrusted else { return nil }
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let appEl = AXUIElementCreateApplication(app.processIdentifier)
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appEl, kAXFocusedWindowAttribute as CFString, &ref) == .success,
              let ref else { return nil }
        return (ref as! AXUIElement)
    }

    func lastAppliedLayout(for window: AXUIElement) -> WindowLayout? {
        var pid: pid_t = 0
        AXUIElementGetPid(window, &pid)
        let title = stringAttr(window, kAXTitleAttribute as String) ?? ""
        return lastLayout[WindowIdentity(pid: pid, title: title)]
    }

    func minimize(_ window: AXUIElement) -> Bool {
        let ok = pressButton(window, kAXMinimizeButtonAttribute as String)
        Log.info(.window, "minimize \(ok ? "ok" : "fail")")
        return ok
    }

    func close(_ window: AXUIElement) -> Bool {
        let ok = pressButton(window, kAXCloseButtonAttribute as String)
        Log.info(.window, "close \(ok ? "ok" : "fail")")
        return ok
    }

    func fullscreen(_ window: AXUIElement) -> Bool {
        var value: CFTypeRef?
        if AXUIElementCopyAttributeValue(window, "AXFullScreen" as CFString, &value) == .success {
            let current = (value as? Bool) ?? false
            let err = AXUIElementSetAttributeValue(window, "AXFullScreen" as CFString, (!current) as CFBoolean)
            let ok = err == .success
            Log.info(.window, "fullscreen toggle→\(!current) \(ok ? "ok" : "fail")")
            return ok
        }
        let ok = pressButton(window, kAXZoomButtonAttribute as String)
        Log.info(.window, "fullscreen via zoom \(ok ? "ok" : "fail")")
        return ok
    }

    func minimizeUnderCursor() -> Bool {
        guard let window = windowAt(appKitPoint: NSEvent.mouseLocation) else { return false }
        return minimize(window)
    }

    func closeUnderCursor() -> Bool {
        guard let window = windowAt(appKitPoint: NSEvent.mouseLocation) else { return false }
        return close(window)
    }

    func fullscreenUnderCursor() -> Bool {
        guard let window = windowAt(appKitPoint: NSEvent.mouseLocation) else { return false }
        return fullscreen(window)
    }

    func commitPreview(layout: WindowLayout, gap: CGFloat) {
        SnapPreviewController.shared.hide()
        _ = snapWindowUnderCursor(layout: layout, gap: gap, showPreviewOnly: false)
    }

    func hidePreview() {
        SnapPreviewController.shared.hide()
    }

    func showPreview(layout: WindowLayout, gap: CGFloat, for window: AXUIElement? = nil) {
        let point: CGPoint
        if let window, let f = frame(of: window) {
            // Preview on the screen that contains the window center (AX → AppKit).
            let primaryH = NSScreen.screens.first?.frame.height ?? 0
            let midAX = CGPoint(x: f.midX, y: f.midY)
            point = CGPoint(x: midAX.x, y: primaryH - midAX.y)
        } else {
            point = NSEvent.mouseLocation
        }
        guard let screen = LayoutGeometry.screenForAppKitPoint(point) else { return }
        let target = LayoutGeometry.targetFrame(layout: layout, visibleFrameAppKit: screen.visibleFrame, gap: gap)
        SnapPreviewController.shared.show(axFrame: target)
    }

    // MARK: - Internals

    private func snap(
        window: AXUIElement,
        layout: WindowLayout,
        gap: CGFloat,
        showPreviewOnly: Bool,
        allowRestoreOnRepeat: Bool = true
    ) -> Bool {
        guard let current = frame(of: window) else {
            Log.error(.window, "snap: no frame")
            return false
        }
        var pid: pid_t = 0
        AXUIElementGetPid(window, &pid)
        let title = stringAttr(window, kAXTitleAttribute as String) ?? ""
        let id = WindowIdentity(pid: pid, title: title)

        // Screen from window center, not live cursor (cursor may have left the titlebar).
        let primaryH = NSScreen.screens.first?.frame.height ?? 0
        let midAppKit = CGPoint(x: current.midX, y: primaryH - current.midY)
        guard let screen = LayoutGeometry.screenForAppKitPoint(midAppKit)
                ?? LayoutGeometry.screenForAppKitPoint(NSEvent.mouseLocation)
        else {
            Log.error(.window, "snap: no screen")
            return false
        }
        let target = LayoutGeometry.targetFrame(layout: layout, visibleFrameAppKit: screen.visibleFrame, gap: gap)

        if showPreviewOnly {
            SnapPreviewController.shared.show(axFrame: target)
            return true
        }

        // Second application of the same layout → restore original frame (Swish/Rectangle behavior).
        if allowRestoreOnRepeat, lastLayout[id] == layout, let prev = restore.restore(id) {
            lastLayout[id] = nil
            SnapPreviewController.shared.hide()
            let ok = setFrame(window, prev)
            Log.info(.window, "restore layout=\(layout.rawValue) title=\(title.prefix(40)) ok=\(ok)")
            return ok
        }

        // Remember original only when starting a new snap sequence (not mid-cycle).
        if lastLayout[id] == nil {
            restore.remember(id, frame: current)
        }
        lastLayout[id] = layout

        SnapPreviewController.shared.hide()
        let ok = setFrame(window, target)
        Log.info(
            .window,
            "snap \(layout.rawValue) title=\(title.prefix(40)) " +
            "→ (\(Int(target.minX)),\(Int(target.minY)) \(Int(target.width))×\(Int(target.height))) ok=\(ok)"
        )
        return ok
    }

    func windowAt(appKitPoint: CGPoint) -> AXUIElement? {
        let ax = LayoutGeometry.appKitPointToAX(appKitPoint)
        var element: AXUIElement?
        let err = AXUIElementCopyElementAtPosition(
            AXUIElementCreateSystemWide(),
            Float(ax.x),
            Float(ax.y),
            &element
        )
        guard err == .success, let element else { return nil }

        var cursor: AXUIElement? = element
        for _ in 0..<10 {
            guard let c = cursor else { break }
            if stringAttr(c, kAXRoleAttribute as String) == (kAXWindowRole as String) {
                return c
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
        var winRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXWindowAttribute as CFString, &winRef) == .success,
           let winRef
        {
            return (winRef as! AXUIElement)
        }
        return nil
    }

    func frame(of window: AXUIElement) -> CGRect? {
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

    @discardableResult
    func setFrame(_ window: AXUIElement, _ rect: CGRect) -> Bool {
        var position = rect.origin
        var size = rect.size
        guard let pos = AXValueCreate(.cgPoint, &position),
              let sz = AXValueCreate(.cgSize, &size) else { return false }
        // Some apps need size-then-position (or both twice) to stick.
        AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sz)
        AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, pos)
        AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sz)
        AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, pos)
        return true
    }

    private func pressButton(_ window: AXUIElement, _ attr: String) -> Bool {
        var btn: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, attr as CFString, &btn) == .success,
              let btn else { return false }
        let button = btn as! AXUIElement
        return AXUIElementPerformAction(button, kAXPressAction as CFString) == .success
    }

    private func stringAttr(_ el: AXUIElement, _ attr: String) -> String? {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, attr as CFString, &ref) == .success else { return nil }
        return ref as? String
    }
}
